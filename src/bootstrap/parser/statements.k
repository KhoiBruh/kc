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
    if (!parser.expect(TokenKind.LEFT_BRACE)) return 0;
    var count: u32 = 0;
    while (parser.ok) {
        if (parser.check(TokenKind.RIGHT_BRACE)) {
            parser.current++;
            return parser.add(AstKind.BLOCK, 0, 0, subtreeStart, count);
        }
        if (parser.check(TokenKind.EOF)) {
            parser.ok = false;
        } else {
            parseStatement(parser);
            count++;
        }
    }
    return 0;
}

fn parseControlBody(var parser: Parser): u64 {
    if (parser.check(TokenKind.LEFT_BRACE)) return parseBlock(parser);
    val subtreeStart = parser.nodes.length;
    parseStatement(parser);
    return parser.add(AstKind.BLOCK, 0, 0, subtreeStart, 1);
}

fn parseStatement(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parser.peek();
    if (parser.match(TokenKind.WHEN)) {
        var hasSubject: u32 = 0;
        if (parser.match(TokenKind.LEFT_PAREN)) {
            parseExpression(parser, 0);
            if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
            hasSubject = 1;
        }
        if (!parser.expect(TokenKind.LEFT_BRACE)) return 0;
        var branchCount: u32 = 0;
        var hasElse = false;
        while (parser.ok) {
            if (parser.check(TokenKind.RIGHT_BRACE)) {
                parser.current++;
                return parser.add(
                    AstKind.WHEN_STATEMENT, first.start, parser.previous().end,
                    subtreeStart, branchCount + hasSubject * 65536);
            }
            val branchStart = parser.nodes.length;
            var isElse: u32 = 0;
            var patternCount: u32 = 0;
            if (parser.match(TokenKind.ELSE)) {
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
                    else if (!parser.match(TokenKind.COMMA)) patterns = false;
                }
            }
            if (!parser.expect(TokenKind.ARROW)) return 0;
            parseControlBody(parser);
            parser.add(
                AstKind.PARAMETER_OR_WHEN_BRANCH, first.start, parser.previous().end,
                branchStart, isElse + patternCount * 65536);
            branchCount++;
        }
        return 0;
    }
    if (parser.match(TokenKind.IF)) {
        if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
        parseControlBody(parser);
        var end = parser.previous().end;
        var hasElse: u32 = 0;
        if (parser.match(TokenKind.ELSE)) {
            parseControlBody(parser);
            end = parser.previous().end;
            hasElse = 1;
        }
        return parser.add(AstKind.IF_STATEMENT, first.start, end, subtreeStart, hasElse);
    }
    if (parser.match(TokenKind.WHILE)) {
        if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
        parseControlBody(parser);
        val end = parser.previous().end;
        return parser.add(
            AstKind.WHILE_STATEMENT, first.start, end,
            subtreeStart, 0);
    }
    if (parser.match(TokenKind.BREAK)) {
        if (!parser.expect(TokenKind.SEMICOLON)) return 0;
        return parser.add(
            AstKind.BREAK_STATEMENT, first.start, parser.previous().end,
            subtreeStart, 0);
    }
    if (parser.match(TokenKind.FOR)) {
        if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
        if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
        val name = parser.previous();
        parser.add(AstKind.NAME, name.start, name.end, parser.nodes.length, 0);
        var hasIndex: u32 = 0;
        if (parser.match(TokenKind.COMMA)) {
            if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
            val indexName = parser.previous();
            parser.add(
                AstKind.NAME, indexName.start, indexName.end,
                parser.nodes.length, 0);
            hasIndex = 1;
        }
        if (!parser.expect(TokenKind.IN)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
        parseControlBody(parser);
        return parser.add(
            AstKind.FOR_STATEMENT, first.start, parser.previous().end,
            subtreeStart, hasIndex);
    }
    if (parser.match(TokenKind.CONTINUE)) {
        if (!parser.expect(TokenKind.SEMICOLON)) return 0;
        return parser.add(
            AstKind.CONTINUE_STATEMENT, first.start, parser.previous().end,
            subtreeStart, 0);
    }
    var isVariable = first.kind == TokenKind.VAL;
    if (first.kind == TokenKind.VAR) isVariable = true;
    if (isVariable) {
        parser.current++;
        if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
        val variableName = parser.previous();
        parser.add(
            AstKind.NAME, variableName.start, variableName.end,
            parser.nodes.length, 0);
        if (parser.match(TokenKind.COLON)) parseType(parser);
        if (!parser.expect(TokenKind.EQUAL)) return 0;
        parseExpression(parser, 0);
        if (!parser.expect(TokenKind.SEMICOLON)) return 0;
        return parser.add(
            AstKind.VARIABLE_DECLARATION, first.start, parser.previous().end,
            subtreeStart, first.kind.value);
    }
    if (parser.match(TokenKind.DEFER)) {
        parseStatement(parser);
        return parser.add(
            AstKind.FUNCTION_OR_DEFER, first.start, parser.previous().end,
            subtreeStart, 0);
    }
    if (parser.match(TokenKind.RETURN)) {
        var hasValue: u32 = 0;
        if (!parser.check(TokenKind.SEMICOLON)) {
            parseExpression(parser, 0);
            hasValue = 1;
        }
        if (!parser.expect(TokenKind.SEMICOLON)) return 0;
        return parser.add(
            AstKind.RETURN_STATEMENT, first.start, parser.previous().end,
            subtreeStart, hasValue);
    }
    if (parser.check(TokenKind.LEFT_BRACE)) return parseBlock(parser);
    parseExpression(parser, 0);
    if (!parser.expect(TokenKind.SEMICOLON)) return 0;
    return parser.add(
        AstKind.EXPRESSION_STATEMENT, first.start, parser.previous().end,
        subtreeStart, 0);
}
