module bootstrap.parser.expressions;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn prefixBindingPower(kind: TokenKind): u32 {
    return when (kind) {
        TokenKind.PLUS, TokenKind.MINUS, TokenKind.AMPERSAND,
        TokenKind.TILDE, TokenKind.BANG -> 90;
        else -> 0;
    };
}

fn leftBindingPower(kind: TokenKind): u32 {
    if (isAssignmentKind(kind)) return 10;
    return when (kind) {
		TokenKind.IN -> 50;
        TokenKind.OR_OR -> 20;
        TokenKind.AND_AND -> 30;
        TokenKind.EQUAL_EQUAL, TokenKind.BANG_EQUAL -> 40;
        TokenKind.LESS, TokenKind.GREATER,
        TokenKind.LESS_EQUAL, TokenKind.GREATER_EQUAL -> 50;
        TokenKind.RANGE, TokenKind.RANGE_EXCLUSIVE,
        TokenKind.RANGE_EXCLUSIVE_START, TokenKind.RANGE_EXCLUSIVE_BOTH -> 60;
        TokenKind.PLUS, TokenKind.MINUS -> 70;
        TokenKind.STAR, TokenKind.SLASH, TokenKind.PERCENT -> 80;
        else -> 0;
    };
}

fn rightBindingPower(kind: TokenKind): u32 {
    val left = leftBindingPower(kind);
    if (left == 10) return 10;
    return left + 1;
}

fn isAssignmentKind(kind: TokenKind): bool => when (kind) {
    TokenKind.EQUAL, TokenKind.PLUS_EQUAL, TokenKind.MINUS_EQUAL,
    TokenKind.STAR_EQUAL, TokenKind.SLASH_EQUAL, TokenKind.PERCENT_EQUAL -> true;
    else -> false;
};

fn isLiteralKind(kind: TokenKind): bool => when (kind) {
    TokenKind.INTEGER_LITERAL, TokenKind.FLOAT_LITERAL, TokenKind.CHAR_LITERAL,
    TokenKind.STRING_LITERAL, TokenKind.TRUE, TokenKind.FALSE,
    TokenKind.NULL -> true;
    else -> false;
};

fn parseValueExpressionBranch(var parser: Parser): u32 {
    var statementCount: u32 = 0;
    if (parser.match(TokenKind.LEFT_BRACE)) {
        var foundTail = false;
        while (!foundTail) {
            if (parser.check(TokenKind.RIGHT_BRACE)) {
                parser.ok = false;
                return 0;
            }
            val next = parser.peek().kind;
            var statementStart = next == TokenKind.VAL;
            if (next == TokenKind.VAR) statementStart = true;
            if (next == TokenKind.WHEN) statementStart = true;
            if (next == TokenKind.IF) statementStart = true;
            if (next == TokenKind.FOR) statementStart = true;
            if (next == TokenKind.WHILE) statementStart = true;
            if (next == TokenKind.RETURN) statementStart = true;
            if (next == TokenKind.LEFT_BRACE) statementStart = true;
            if (next == TokenKind.BREAK) statementStart = true;
            if (next == TokenKind.CONTINUE) statementStart = true;
            if (statementStart) {
                parseStatement(parser);
                statementCount++;
            } else {
                val valueStart = parser.nodes.length;
                val valueFirst = parser.peek();
                parseExpression(parser, 0);
                if (parser.match(TokenKind.SEMICOLON)) {
                    parser.add(
                        AstKind.EXPRESSION_STATEMENT, valueFirst.start,
                        parser.previous().end, valueStart, 0);
                    statementCount++;
                } else {
                    foundTail = true;
                }
            }
        }
        if (!parser.expect(TokenKind.RIGHT_BRACE)) return 0;
    } else {
        parseExpression(parser, 0);
    }
    return statementCount;
}

fn parseExpression(var parser: Parser, minimumPower: u32): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parser.peek();
    var root: u64 = 0;
    if (first.kind == TokenKind.IDENTIFIER) {
        parser.current++;
        root = parser.add(
            AstKind.IDENTIFIER, first.start, first.end, subtreeStart, 0);
    } else {
        if (isLiteralKind(first.kind)) {
            parser.current++;
            root = parser.add(
                AstKind.LITERAL, first.start, first.end, subtreeStart,
                first.kind.value);
        } else {
            val prefixPower = prefixBindingPower(first.kind);
            if (prefixPower != 0) {
                parser.current++;
                val operand = parseExpression(parser, prefixPower);
                if (!parser.ok) return 0;
                root = parser.add(
                    AstKind.UNARY, first.start, parser.nodes.data[operand].end,
                    subtreeStart, first.kind.value);
            } else {
                if (parser.match(TokenKind.IF)) {
                    if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
                    parseExpression(parser, 0);
                    if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
                    val thenCount = parseValueExpressionBranch(parser);
                    if (!parser.expect(TokenKind.ELSE)) return 0;
                    val elseCount = parseValueExpressionBranch(parser);
                    root = parser.add(
                        AstKind.IF_EXPRESSION, first.start, parser.previous().end,
                        subtreeStart, thenCount + elseCount * 65536);
                } else {
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
                    while (!parser.check(TokenKind.RIGHT_BRACE)) {
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
                        var statementCount: u32 = 0;
                        if (parser.match(TokenKind.LEFT_BRACE)) {
                            var foundTail = false;
                            while (!foundTail) {
                                if (parser.check(TokenKind.RIGHT_BRACE)) {
                                    parser.ok = false;
                                    return 0;
                                }
                                val next = parser.peek().kind;
                                var statementStart = next == TokenKind.VAL;
                                if (next == TokenKind.VAR) statementStart = true;
                                if (next == TokenKind.IF) statementStart = true;
                                if (next == TokenKind.FOR) statementStart = true;
                                if (next == TokenKind.WHILE) statementStart = true;
                                if (next == TokenKind.RETURN) statementStart = true;
                                if (next == TokenKind.LEFT_BRACE) statementStart = true;
                                if (next == TokenKind.BREAK) statementStart = true;
                                if (next == TokenKind.CONTINUE) statementStart = true;
                                if (statementStart) {
                                    parseStatement(parser);
                                    statementCount++;
                                } else {
                                    val valueStart = parser.nodes.length;
                                    val valueFirst = parser.peek();
                                    parseExpression(parser, 0);
                                    if (parser.match(TokenKind.SEMICOLON)) {
                                        parser.add(
                                            AstKind.EXPRESSION_STATEMENT, valueFirst.start,
                                            parser.previous().end,
                                            valueStart, 0);
                                        statementCount++;
                                    } else {
                                        foundTail = true;
                                    }
                                }
                            }
                            if (!parser.expect(TokenKind.RIGHT_BRACE)) return 0;
                        } else {
                            parseExpression(parser, 0);
                            if (!parser.expect(TokenKind.SEMICOLON)) return 0;
                        }
                        parser.add(
                            AstKind.WHEN_EXPRESSION_BRANCH, first.start, parser.previous().end,
                            branchStart,
                            isElse + statementCount * 2 + patternCount * 65536);
                        branchCount++;
                    }
                    if (!parser.expect(TokenKind.RIGHT_BRACE)) return 0;
                    root = parser.add(
                        AstKind.WHEN_EXPRESSION, first.start, parser.previous().end,
                        subtreeStart, branchCount + hasSubject * 65536);
                } else {
                if (parser.match(TokenKind.LEFT_BRACKET)) {
                    var count: u32 = 0;
                    if (!parser.check(TokenKind.RIGHT_BRACKET)) {
                        var elements = true;
                        while (elements) {
                            parseExpression(parser, 0);
                            count++;
                            if (!parser.match(TokenKind.COMMA)) {
                                elements = false;
                            }
                        }
                    }
                    if (!parser.expect(TokenKind.RIGHT_BRACKET)) return 0;
                    root = parser.add(
                        AstKind.ARRAY_LITERAL, first.start, parser.previous().end,
                        subtreeStart, count);
                } else {
                if (parser.match(TokenKind.LEFT_PAREN)) {
                    if (parser.match(TokenKind.RIGHT_PAREN)) {
                        root = parser.add(
                            AstKind.UNIT_LITERAL, first.start, parser.previous().end,
                            subtreeStart, 0);
                    } else {
                        root = parseExpression(parser, 0);
                        if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
                    }
                } else {
                    if (parser.match(TokenKind.SIZEOF)) {
                        if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
                        parseType(parser);
                        if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
                        root = parser.add(
                            AstKind.SIZEOF, first.start, parser.previous().end,
                            subtreeStart, 0);
                    } else {
                        parser.ok = false;
                        return 0;
                    }
                }}
                }
                }
            }
        }
    }

    var parsing = true;
    while (parsing) {
        val token = parser.peek();
        if (token.kind == TokenKind.LESS) {
            if (parser.genericCallAhead()) {
                parser.current++;
                var typeArgumentCount: u32 = 0;
                var typeArguments = true;
                while (typeArguments) {
                    parseType(parser);
                    typeArgumentCount++;
                    if (!parser.match(TokenKind.COMMA)) {
                        typeArguments = false;
                    }
                }
                if (!parser.expect(TokenKind.GREATER)) return 0;
                var associated: u32 = 0;
                if (parser.match(TokenKind.DOT)) {
                    val name = parser.peek();
                    if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
                    root = parser.add(
                        AstKind.MEMBER, name.start, name.end, subtreeStart,
                        typeArgumentCount);
                    associated = 1;
                }
                if (!parser.expect(TokenKind.LEFT_PAREN)) return 0;
                var argumentCount: u32 = 0;
                if (!parser.check(TokenKind.RIGHT_PAREN)) {
                    var arguments = true;
                    while (arguments) {
                        parseExpression(parser, 0);
                        argumentCount++;
                        if (!parser.match(TokenKind.COMMA)) {
                            arguments = false;
                        }
                    }
                }
                if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
                root = parser.add(
                    AstKind.CALL, first.start, parser.previous().end,
                    subtreeStart,
                    argumentCount +
                        (typeArgumentCount * 65536) * (1 - associated));
            } else {
                val leftPower = leftBindingPower(token.kind);
                if (leftPower < minimumPower) {
                    parsing = false;
                } else {
                    parser.current++;
                    val right = parseExpression(
                        parser, rightBindingPower(token.kind));
                    if (!parser.ok) return 0;
                    root = parser.add(
                        AstKind.BINARY, first.start,
                        parser.nodes.data[right].end,
                        subtreeStart, token.kind.value);
                }
            }
        } else {
        if (token.kind == TokenKind.LEFT_PAREN) {
            parser.current++;
            var argumentCount: u32 = 0;
            if (!parser.check(TokenKind.RIGHT_PAREN)) {
                var arguments = true;
                while (arguments) {
                    parseExpression(parser, 0);
                    argumentCount++;
                    if (!parser.match(TokenKind.COMMA)) arguments = false;
                }
            }
            if (!parser.expect(TokenKind.RIGHT_PAREN)) return 0;
            root = parser.add(
                AstKind.CALL, first.start, parser.previous().end,
                subtreeStart, argumentCount);
        } else {
            if (token.kind == TokenKind.DOT) {
                parser.current++;
                val name = parser.peek();
                if (!parser.expect(TokenKind.IDENTIFIER)) return 0;
                root = parser.add(
                    AstKind.MEMBER, name.start, name.end, subtreeStart, 0);
            } else {
                if (token.kind == TokenKind.LEFT_BRACKET) {
                    parser.current++;
                    parseExpression(parser, 0);
                    if (!parser.expect(TokenKind.RIGHT_BRACKET)) return 0;
                    root = parser.add(
                        AstKind.INDEX, first.start, parser.previous().end,
                        subtreeStart, 0);
                } else {
                    var postfix = token.kind == TokenKind.BANG;
                    if (token.kind == TokenKind.PLUS_PLUS) postfix = true;
                    if (token.kind == TokenKind.MINUS_MINUS) postfix = true;
                    if (postfix) {
                        parser.current++;
                        root = parser.add(
                            AstKind.POSTFIX, first.start, token.end,
                            subtreeStart, token.kind.value);
                    } else {
                        if (token.kind == TokenKind.AS) {
                            if (85 < minimumPower) {
                                parsing = false;
                            } else {
                                parser.current++;
                                parseType(parser);
                                root = parser.add(
                                    AstKind.CAST, first.start,
                                    parser.nodes.data[parser.nodes.length - 1].end,
                                    subtreeStart, 0);
                            }
                        } else {
                            val leftPower = leftBindingPower(token.kind);
                            if (leftPower == 0) {
                                parsing = false;
                            } else {
                                if (leftPower < minimumPower) {
                                    parsing = false;
                                } else {
                                    parser.current++;
                                    val leftKind =
                                        parser.nodes.data[root].kind;
                                    if (isAssignmentKind(token.kind)) {
                                        var assignable = leftKind == AstKind.IDENTIFIER;
                                        if (leftKind == AstKind.MEMBER) assignable = true;
                                        if (leftKind == AstKind.INDEX) assignable = true;
                                        if (leftKind == AstKind.UNARY) {
                                            if (parser.nodes.data[root].aux ==
                                                TokenKind.STAR.value) {
                                                assignable = true;
                                            }
                                        }
                                        if (!assignable) {
                                            parser.ok = false;
                                            return 0;
                                        }
                                    }
                                    val right = parseExpression(
                                        parser, rightBindingPower(token.kind));
                                    if (!parser.ok) return 0;
                                    var nodeKind = AstKind.BINARY;
                                    if (isAssignmentKind(token.kind)) {
                                        nodeKind = AstKind.ASSIGNMENT;
                                    }
                                    root = parser.add(
                                        nodeKind, first.start,
                                        parser.nodes.data[right].end,
                                        subtreeStart, token.kind.value);
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
    return root;
}
