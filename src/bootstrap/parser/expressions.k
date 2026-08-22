module bootstrap.parser.expressions;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn prefixBindingPower(kind: TokenKind): u32 {
    return when (kind) {
        TokenKind.Plus, TokenKind.Minus, TokenKind.Ampersand,
        TokenKind.Tilde, TokenKind.Bang -> 90;
        else -> 0;
    };
}

fn leftBindingPower(kind: TokenKind): u32 {
    if (isAssignmentKind(kind)) return 10;
    return when (kind) {
		TokenKind.KwIn -> 50;
        TokenKind.OrOr -> 20;
        TokenKind.AndAnd -> 30;
        TokenKind.EqualEqual, TokenKind.BangEqual -> 40;
        TokenKind.Less, TokenKind.Greater,
        TokenKind.LessEqual, TokenKind.GreaterEqual -> 50;
        TokenKind.Range, TokenKind.RangeExclusive,
        TokenKind.RangeExclusiveStart, TokenKind.RangeExclusiveBoth -> 60;
        TokenKind.Plus, TokenKind.Minus -> 70;
        TokenKind.Star, TokenKind.Slash, TokenKind.Percent -> 80;
        else -> 0;
    };
}

fn rightBindingPower(kind: TokenKind): u32 {
    val left = leftBindingPower(kind);
    if (left == 10) return 10;
    return left + 1;
}

fn isAssignmentKind(kind: TokenKind): bool => when (kind) {
    TokenKind.Equal, TokenKind.PlusEqual, TokenKind.MinusEqual,
    TokenKind.StarEqual, TokenKind.SlashEqual, TokenKind.PercentEqual -> true;
    else -> false;
};

fn isLiteralKind(kind: TokenKind): bool => when (kind) {
    TokenKind.IntegerLiteral, TokenKind.FloatLiteral, TokenKind.CharLiteral,
    TokenKind.StringLiteral, TokenKind.KwTrue, TokenKind.KwFalse,
    TokenKind.KwNull -> true;
    else -> false;
};

fn parseValueExpressionBranch(var parser: Parser): u32 {
    var statementCount: u32 = 0;
    if (parser.match(TokenKind.LeftBrace)) {
        var foundTail = false;
        while (!foundTail) {
            if (parser.check(TokenKind.RightBrace)) {
                parser.ok = false;
                return 0;
            }
            val next = parser.peek().kind;
            var statementStart = next == TokenKind.KwVal;
            if (next == TokenKind.KwVar) statementStart = true;
            if (next == TokenKind.KwWhen) statementStart = true;
            if (next == TokenKind.KwIf) statementStart = true;
            if (next == TokenKind.KwFor) statementStart = true;
            if (next == TokenKind.KwWhile) statementStart = true;
            if (next == TokenKind.KwReturn) statementStart = true;
            if (next == TokenKind.LeftBrace) statementStart = true;
            if (next == TokenKind.KwBreak) statementStart = true;
            if (next == TokenKind.KwContinue) statementStart = true;
            if (statementStart) {
                parseStatement(parser);
                statementCount++;
            } else {
                val valueStart = parser.nodes.length;
                val valueFirst = parser.peek();
                parseExpression(parser, 0);
                if (parser.match(TokenKind.Semicolon)) {
                    parser.add(
                        AstKind.ExpressionStatement, valueFirst.start,
                        parser.previous().end, valueStart, 0);
                    statementCount++;
                } else {
                    foundTail = true;
                }
            }
        }
        if (!parser.expect(TokenKind.RightBrace)) return 0;
    } else {
        parseExpression(parser, 0);
    }
    return statementCount;
}

fn parseExpression(var parser: Parser, minimumPower: u32): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parser.peek();
    var root: u64 = 0;
    if (first.kind == TokenKind.Identifier) {
        parser.current++;
        root = parser.add(
            AstKind.Identifier, first.start, first.end, subtreeStart, 0);
    } else {
        if (isLiteralKind(first.kind)) {
            parser.current++;
            root = parser.add(
                AstKind.Literal, first.start, first.end, subtreeStart,
                first.kind.value);
        } else {
            val prefixPower = prefixBindingPower(first.kind);
            if (prefixPower != 0) {
                parser.current++;
                val operand = parseExpression(parser, prefixPower);
                if (!parser.ok) return 0;
                root = parser.add(
                    AstKind.Unary, first.start, parser.nodes.data[operand].end,
                    subtreeStart, first.kind.value);
            } else {
                if (parser.match(TokenKind.KwIf)) {
                    if (!parser.expect(TokenKind.LeftParen)) return 0;
                    parseExpression(parser, 0);
                    if (!parser.expect(TokenKind.RightParen)) return 0;
                    val thenCount = parseValueExpressionBranch(parser);
                    if (!parser.expect(TokenKind.KwElse)) return 0;
                    val elseCount = parseValueExpressionBranch(parser);
                    root = parser.add(
                        AstKind.IfExpression, first.start, parser.previous().end,
                        subtreeStart, thenCount + elseCount * 65536);
                } else {
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
                    while (!parser.check(TokenKind.RightBrace)) {
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
                        var statementCount: u32 = 0;
                        if (parser.match(TokenKind.LeftBrace)) {
                            var foundTail = false;
                            while (!foundTail) {
                                if (parser.check(TokenKind.RightBrace)) {
                                    parser.ok = false;
                                    return 0;
                                }
                                val next = parser.peek().kind;
                                var statementStart = next == TokenKind.KwVal;
                                if (next == TokenKind.KwVar) statementStart = true;
                                if (next == TokenKind.KwIf) statementStart = true;
                                if (next == TokenKind.KwFor) statementStart = true;
                                if (next == TokenKind.KwWhile) statementStart = true;
                                if (next == TokenKind.KwReturn) statementStart = true;
                                if (next == TokenKind.LeftBrace) statementStart = true;
                                if (next == TokenKind.KwBreak) statementStart = true;
                                if (next == TokenKind.KwContinue) statementStart = true;
                                if (statementStart) {
                                    parseStatement(parser);
                                    statementCount++;
                                } else {
                                    val valueStart = parser.nodes.length;
                                    val valueFirst = parser.peek();
                                    parseExpression(parser, 0);
                                    if (parser.match(TokenKind.Semicolon)) {
                                        parser.add(
                                            AstKind.ExpressionStatement, valueFirst.start,
                                            parser.previous().end,
                                            valueStart, 0);
                                        statementCount++;
                                    } else {
                                        foundTail = true;
                                    }
                                }
                            }
                            if (!parser.expect(TokenKind.RightBrace)) return 0;
                        } else {
                            parseExpression(parser, 0);
                            if (!parser.expect(TokenKind.Semicolon)) return 0;
                        }
                        parser.add(
                            AstKind.WhenExpressionBranch, first.start, parser.previous().end,
                            branchStart,
                            isElse + statementCount * 2 + patternCount * 65536);
                        branchCount++;
                    }
                    if (!parser.expect(TokenKind.RightBrace)) return 0;
                    root = parser.add(
                        AstKind.WhenExpression, first.start, parser.previous().end,
                        subtreeStart, branchCount + hasSubject * 65536);
                } else {
                if (parser.match(TokenKind.LeftBracket)) {
                    var count: u32 = 0;
                    if (!parser.check(TokenKind.RightBracket)) {
                        var elements = true;
                        while (elements) {
                            parseExpression(parser, 0);
                            count++;
                            if (!parser.match(TokenKind.Comma)) {
                                elements = false;
                            }
                        }
                    }
                    if (!parser.expect(TokenKind.RightBracket)) return 0;
                    root = parser.add(
                        AstKind.ArrayLiteral, first.start, parser.previous().end,
                        subtreeStart, count);
                } else {
                if (parser.match(TokenKind.LeftParen)) {
                    if (parser.match(TokenKind.RightParen)) {
                        root = parser.add(
                            AstKind.UnitLiteral, first.start, parser.previous().end,
                            subtreeStart, 0);
                    } else {
                        root = parseExpression(parser, 0);
                        if (!parser.expect(TokenKind.RightParen)) return 0;
                    }
                } else {
                    if (parser.match(TokenKind.KwSizeof)) {
                        if (!parser.expect(TokenKind.LeftParen)) return 0;
                        parseType(parser);
                        if (!parser.expect(TokenKind.RightParen)) return 0;
                        root = parser.add(
                            AstKind.Sizeof, first.start, parser.previous().end,
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
        if (token.kind == TokenKind.Less) {
            if (parser.genericCallAhead()) {
                parser.current++;
                var typeArgumentCount: u32 = 0;
                var typeArguments = true;
                while (typeArguments) {
                    parseType(parser);
                    typeArgumentCount++;
                    if (!parser.match(TokenKind.Comma)) {
                        typeArguments = false;
                    }
                }
                if (!parser.expect(TokenKind.Greater)) return 0;
                var associated: u32 = 0;
                if (parser.match(TokenKind.Dot)) {
                    val name = parser.peek();
                    if (!parser.expect(TokenKind.Identifier)) return 0;
                    root = parser.add(
                        AstKind.Member, name.start, name.end, subtreeStart,
                        typeArgumentCount);
                    associated = 1;
                }
                if (!parser.expect(TokenKind.LeftParen)) return 0;
                var argumentCount: u32 = 0;
                if (!parser.check(TokenKind.RightParen)) {
                    var arguments = true;
                    while (arguments) {
                        parseExpression(parser, 0);
                        argumentCount++;
                        if (!parser.match(TokenKind.Comma)) {
                            arguments = false;
                        }
                    }
                }
                if (!parser.expect(TokenKind.RightParen)) return 0;
                root = parser.add(
                    AstKind.Call, first.start, parser.previous().end,
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
                        AstKind.Binary, first.start,
                        parser.nodes.data[right].end,
                        subtreeStart, token.kind.value);
                }
            }
        } else {
        if (token.kind == TokenKind.LeftParen) {
            parser.current++;
            var argumentCount: u32 = 0;
            if (!parser.check(TokenKind.RightParen)) {
                var arguments = true;
                while (arguments) {
                    parseExpression(parser, 0);
                    argumentCount++;
                    if (!parser.match(TokenKind.Comma)) arguments = false;
                }
            }
            if (!parser.expect(TokenKind.RightParen)) return 0;
            root = parser.add(
                AstKind.Call, first.start, parser.previous().end,
                subtreeStart, argumentCount);
        } else {
            if (token.kind == TokenKind.Dot) {
                parser.current++;
                val name = parser.peek();
                if (!parser.expect(TokenKind.Identifier)) return 0;
                root = parser.add(
                    AstKind.Member, name.start, name.end, subtreeStart, 0);
            } else {
                if (token.kind == TokenKind.LeftBracket) {
                    parser.current++;
                    parseExpression(parser, 0);
                    if (!parser.expect(TokenKind.RightBracket)) return 0;
                    root = parser.add(
                        AstKind.Index, first.start, parser.previous().end,
                        subtreeStart, 0);
                } else {
                    var postfix = token.kind == TokenKind.Bang;
                    if (token.kind == TokenKind.PlusPlus) postfix = true;
                    if (token.kind == TokenKind.MinusMinus) postfix = true;
                    if (postfix) {
                        parser.current++;
                        root = parser.add(
                            AstKind.Postfix, first.start, token.end,
                            subtreeStart, token.kind.value);
                    } else {
                        if (token.kind == TokenKind.KwAs) {
                            if (85 < minimumPower) {
                                parsing = false;
                            } else {
                                parser.current++;
                                parseType(parser);
                                root = parser.add(
                                    AstKind.Cast, first.start,
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
                                        var assignable = leftKind == AstKind.Identifier;
                                        if (leftKind == AstKind.Member) assignable = true;
                                        if (leftKind == AstKind.Index) assignable = true;
                                        if (leftKind == AstKind.Unary) {
                                            if (parser.nodes.data[root].aux ==
                                                TokenKind.Star.value) {
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
                                    var nodeKind = AstKind.Binary;
                                    if (isAssignmentKind(token.kind)) {
                                        nodeKind = AstKind.Assignment;
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
