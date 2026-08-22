module bootstrap.parser.statements;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn parseBlock(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parser.peek().start;
    if (!parser.expect(TokenKind.LeftBrace)) return 0;
    var count: u32 = 0;
    while (parser.ok) {
        if (parser.check(TokenKind.RightBrace)) {
            parser.current++;
            return parser.add(AstKind.Block, 0, 0, subtreeStart, count);
        }
        if (parser.check(TokenKind.EndOfFile)) {
            parser.ok = false;
        } else {
            parseStatement(parser);
            count++;
        }
    }
    return 0;
}

fn parseControlBody(var parser: Parser): u64 {
    if (parser.check(TokenKind.LeftBrace)) return parseBlock(parser);
    val subtreeStart = parser.nodes.length;
    parseStatement(parser);
    return parser.add(AstKind.Block, 0, 0, subtreeStart, 1);
}

fn parseStatement(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parser.peek();
    if (parser.match(TokenKind.KwWhen)) {
        var hasSubject: u32 = 0;
        if (parser.match(TokenKind.LeftParen)) {
            parseExpression(parser, 0);
            if (!parser.expect(TokenKind.RightParen)) return 0;
            hasSubject = 1;
        }
        if (!parser.expect(TokenKind.LeftBrace)) return 0;
        var branchCount: u32 = 0;
        var hasElse = false;
        while (parser.ok) {
            if (parser.check(TokenKind.RightBrace)) {
                parser.current++;
                return parser.add(
                    AstKind.WhenStatement, first.start, parser.previous().end,
                    subtreeStart, branchCount + hasSubject * 65536);
            }
            val branchStart = parser.nodes.length;
            var isElse: u32 = 0;
            var patternCount: u32 = 0;
            if (parser.match(TokenKind.KwElse)) {
                if (hasElse) {
                    parser.ok = false;
                    return 0;
                }
                hasElse = true;
                isElse = 1;
            } else {
                if (hasElse) {
                    parser.ok = false;
                    return 0;
                }
                var patterns = true;
                while (patterns) {
                    parseExpression(parser, 0);
                    patternCount++;
                    if (hasSubject == 0) patterns = false;
                    else if (!parser.match(TokenKind.Comma)) patterns = false;
                }
            }
            if (!parser.expect(TokenKind.Arrow)) return 0;
            parseControlBody(parser);
            parser.add(
                AstKind.ParameterOrWhenBranch, first.start, parser.previous().end,
                branchStart, isElse + patternCount * 65536);
            branchCount++;
        }
        return 0;
    }
    if (parser.match(TokenKind.KwIf)) {
        if (!parser.expect(TokenKind.LeftParen)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.RightParen)) return 0;
        parseControlBody(parser);
        var end = parser.previous().end;
        var hasElse: u32 = 0;
        if (parser.match(TokenKind.KwElse)) {
            parseControlBody(parser);
            end = parser.previous().end;
            hasElse = 1;
        }
        return parser.add(AstKind.IfStatement, first.start, end, subtreeStart, hasElse);
    }
    if (parser.match(TokenKind.KwWhile)) {
        if (!parser.expect(TokenKind.LeftParen)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.RightParen)) return 0;
        parseControlBody(parser);
        val end = parser.previous().end;
        return parser.add(
            AstKind.WhileStatement, first.start, end,
            subtreeStart, 0);
    }
    if (parser.match(TokenKind.KwBreak)) {
        if (!parser.expect(TokenKind.Semicolon)) return 0;
        return parser.add(
            AstKind.BreakStatement, first.start, parser.previous().end,
            subtreeStart, 0);
    }
    if (parser.match(TokenKind.KwFor)) {
        if (!parser.expect(TokenKind.LeftParen)) return 0;
        if (!parser.expect(TokenKind.Identifier)) return 0;
        val name = parser.previous();
        parser.add(AstKind.Name, name.start, name.end, parser.nodes.length, 0);
        var hasIndex: u32 = 0;
        if (parser.match(TokenKind.Comma)) {
            if (!parser.expect(TokenKind.Identifier)) return 0;
            val indexName = parser.previous();
            parser.add(
                AstKind.Name, indexName.start, indexName.end,
                parser.nodes.length, 0);
            hasIndex = 1;
        }
        if (!parser.expect(TokenKind.KwIn)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.RightParen)) return 0;
        parseControlBody(parser);
        return parser.add(
            AstKind.ForStatement, first.start, parser.previous().end,
            subtreeStart, hasIndex);
    }
    if (parser.match(TokenKind.KwContinue)) {
        if (!parser.expect(TokenKind.Semicolon)) return 0;
        return parser.add(
            AstKind.ContinueStatement, first.start, parser.previous().end,
            subtreeStart, 0);
    }
    var isVariable = first.kind == TokenKind.KwVal;
    if (first.kind == TokenKind.KwVar) isVariable = true;
    if (isVariable) {
        parser.current++;
        if (!parser.expect(TokenKind.Identifier)) return 0;
        val variableName = parser.previous();
        parser.add(
            AstKind.Name, variableName.start, variableName.end,
            parser.nodes.length, 0);
        if (parser.match(TokenKind.Colon)) parseType(parser);
        if (!parser.expect(TokenKind.Equal)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.Semicolon)) return 0;
        return parser.add(
            AstKind.VariableDeclaration, first.start, parser.previous().end,
            subtreeStart, first.kind.value);
    }
    if (parser.match(TokenKind.KwDefer)) {
        parseStatement(parser);
        return parser.add(
            AstKind.FunctionOrDefer, first.start, parser.previous().end,
            subtreeStart, 0);
    }
    if (parser.match(TokenKind.KwReturn)) {
        var hasValue: u32 = 0;
        if (!parser.check(TokenKind.Semicolon)) {
            parseExpression(parser, 0);
            hasValue = 1;
        }
        if (!parser.expect(TokenKind.Semicolon)) return 0;
        return parser.add(
            AstKind.ReturnStatement, first.start, parser.previous().end,
            subtreeStart, hasValue);
    }
    if (parser.check(TokenKind.LeftBrace)) return parseBlock(parser);
    parseExpression(parser, 0);
    if (!parser.expect(TokenKind.Semicolon)) return 0;
    return parser.add(
        AstKind.ExpressionStatement, first.start, parser.previous().end,
        subtreeStart, 0);
}
