module bootstrap.parser.statements;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn parseBlock(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    if (!parserExpect(parser, TokenKind.LeftBrace)) return 0;
    var count: u32 = 0;
    while (parser.ok) {
        if (parserCheck(parser, TokenKind.RightBrace)) {
            parser.current++;
            return parserAdd(parser, AstKind.Block, 0, 0, subtreeStart, count);
        }
        if (parserCheck(parser, TokenKind.EndOfFile)) {
            parser.ok = false;
        } else {
            parseStatement(parser);
            count++;
        }
    }
    return 0;
}

fn parseControlBody(var parser: Parser): u64 {
    if (parserCheck(parser, TokenKind.LeftBrace)) return parseBlock(parser);
    val subtreeStart = parser.nodes.length;
    parseStatement(parser);
    return parserAdd(parser, AstKind.Block, 0, 0, subtreeStart, 1);
}

fn parseStatement(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parserPeek(parser);
    if (parserMatch(parser, TokenKind.KwWhen)) {
        var hasSubject: u32 = 0;
        if (parserMatch(parser, TokenKind.LeftParen)) {
            parseExpression(parser, 0);
            if (!parserExpect(parser, TokenKind.RightParen)) return 0;
            hasSubject = 1;
        }
        if (!parserExpect(parser, TokenKind.LeftBrace)) return 0;
        var branchCount: u32 = 0;
        var hasElse = false;
        while (parser.ok) {
            if (parserCheck(parser, TokenKind.RightBrace)) {
                parser.current++;
                return parserAdd(
                    parser, AstKind.WhenStatement, first.start, parserPrevious(parser).end,
                    subtreeStart, branchCount + hasSubject * 65536);
            }
            val branchStart = parser.nodes.length;
            var isElse: u32 = 0;
            var patternCount: u32 = 0;
            if (parserMatch(parser, TokenKind.KwElse)) {
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
                    else if (!parserMatch(parser, TokenKind.Comma)) patterns = false;
                }
            }
            if (!parserExpect(parser, TokenKind.Arrow)) return 0;
            parseControlBody(parser);
            parserAdd(
                parser, AstKind.ParameterOrWhenBranch, first.start, parserPrevious(parser).end,
                branchStart, isElse + patternCount * 65536);
            branchCount++;
        }
        return 0;
    }
    if (parserMatch(parser, TokenKind.KwIf)) {
        if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, TokenKind.RightParen)) return 0;
        parseControlBody(parser);
        var end = parserPrevious(parser).end;
        var hasElse: u32 = 0;
        if (parserMatch(parser, TokenKind.KwElse)) {
            parseControlBody(parser);
            end = parserPrevious(parser).end;
            hasElse = 1;
        }
        return parserAdd(parser, AstKind.IfStatement, first.start, end, subtreeStart, hasElse);
    }
    if (parserMatch(parser, TokenKind.KwWhile)) {
        if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, TokenKind.RightParen)) return 0;
        parseControlBody(parser);
        val end = parserPrevious(parser).end;
        return parserAdd(
            parser, AstKind.WhileStatement, first.start, end,
            subtreeStart, 0);
    }
    if (parserMatch(parser, TokenKind.KwBreak)) {
        if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
        return parserAdd(
            parser, AstKind.BreakStatement, first.start, parserPrevious(parser).end,
            subtreeStart, 0);
    }
    if (parserMatch(parser, TokenKind.KwFor)) {
        if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
        if (!parserExpect(parser, TokenKind.Identifier)) return 0;
        val name = parserPrevious(parser);
        parserAdd(parser, AstKind.Name, name.start, name.end, parser.nodes.length, 0);
        var hasIndex: u32 = 0;
        if (parserMatch(parser, TokenKind.Comma)) {
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val indexName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, indexName.start, indexName.end,
                parser.nodes.length, 0);
            hasIndex = 1;
        }
        if (!parserExpect(parser, TokenKind.KwIn)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, TokenKind.RightParen)) return 0;
        parseControlBody(parser);
        return parserAdd(
            parser, AstKind.ForStatement, first.start, parserPrevious(parser).end,
            subtreeStart, hasIndex);
    }
    if (parserMatch(parser, TokenKind.KwContinue)) {
        if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
        return parserAdd(
            parser, AstKind.ContinueStatement, first.start, parserPrevious(parser).end,
            subtreeStart, 0);
    }
    var isVariable = first.kind == TokenKind.KwVal;
    if (first.kind == TokenKind.KwVar) isVariable = true;
    if (isVariable) {
        parser.current++;
        if (!parserExpect(parser, TokenKind.Identifier)) return 0;
        val variableName = parserPrevious(parser);
        parserAdd(
            parser, AstKind.Name, variableName.start, variableName.end,
            parser.nodes.length, 0);
        if (parserMatch(parser, TokenKind.Colon)) parseType(parser);
        if (!parserExpect(parser, TokenKind.Equal)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
        return parserAdd(
            parser, AstKind.VariableDeclaration, first.start, parserPrevious(parser).end,
            subtreeStart, first.kind.value);
    }
    if (parserMatch(parser, TokenKind.KwDefer)) {
        parseStatement(parser);
        return parserAdd(
            parser, AstKind.FunctionOrDefer, first.start, parserPrevious(parser).end,
            subtreeStart, 0);
    }
    if (parserMatch(parser, TokenKind.KwReturn)) {
        var hasValue: u32 = 0;
        if (!parserCheck(parser, TokenKind.Semicolon)) {
            parseExpression(parser, 0);
            hasValue = 1;
        }
        if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
        return parserAdd(
            parser, AstKind.ReturnStatement, first.start, parserPrevious(parser).end,
            subtreeStart, hasValue);
    }
    if (parserCheck(parser, TokenKind.LeftBrace)) return parseBlock(parser);
    parseExpression(parser, 0);
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ExpressionStatement, first.start, parserPrevious(parser).end,
        subtreeStart, 0);
}
