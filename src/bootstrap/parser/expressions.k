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
    if (parserMatch(parser, TokenKind.LeftBrace)) {
        var foundTail = false;
        while (!foundTail) {
            if (parserCheck(parser, TokenKind.RightBrace)) {
                parser.ok = false;
                return 0;
            }
            val next = parserPeek(parser).kind;
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
                val valueFirst = parserPeek(parser);
                parseExpression(parser, 0);
                if (parserMatch(parser, TokenKind.Semicolon)) {
                    parserAdd(
                        parser, AstKind.ExpressionStatement, valueFirst.start,
                        parserPrevious(parser).end, valueStart, 0);
                    statementCount++;
                } else {
                    foundTail = true;
                }
            }
        }
        if (!parserExpect(parser, TokenKind.RightBrace)) return 0;
    } else {
        parseExpression(parser, 0);
    }
    return statementCount;
}

fn parseExpression(var parser: Parser, minimumPower: u32): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parserPeek(parser);
    var root: u64 = 0;
    if (first.kind == TokenKind.Identifier) {
        parser.current++;
        root = parserAdd(
            parser, AstKind.Identifier, first.start, first.end, subtreeStart, 0);
    } else {
        if (isLiteralKind(first.kind)) {
            parser.current++;
            root = parserAdd(
                parser, AstKind.Literal, first.start, first.end, subtreeStart,
                first.kind.value);
        } else {
            val prefixPower = prefixBindingPower(first.kind);
            if (prefixPower != 0) {
                parser.current++;
                val operand = parseExpression(parser, prefixPower);
                if (!parser.ok) return 0;
                root = parserAdd(
                    parser, AstKind.Unary, first.start, parser.nodes.data[operand].end,
                    subtreeStart, first.kind.value);
            } else {
                if (parserMatch(parser, TokenKind.KwIf)) {
                    if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
                    parseExpression(parser, 0);
                    if (!parserExpect(parser, TokenKind.RightParen)) return 0;
                    val thenCount = parseValueExpressionBranch(parser);
                    if (!parserExpect(parser, TokenKind.KwElse)) return 0;
                    val elseCount = parseValueExpressionBranch(parser);
                    root = parserAdd(
                        parser, AstKind.IfExpression, first.start, parserPrevious(parser).end,
                        subtreeStart, thenCount + elseCount * 65536);
                } else {
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
                    while (!parserCheck(parser, TokenKind.RightBrace)) {
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
                        var statementCount: u32 = 0;
                        if (parserMatch(parser, TokenKind.LeftBrace)) {
                            var foundTail = false;
                            while (!foundTail) {
                                if (parserCheck(parser, TokenKind.RightBrace)) {
                                    parser.ok = false;
                                    return 0;
                                }
                                val next = parserPeek(parser).kind;
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
                                    val valueFirst = parserPeek(parser);
                                    parseExpression(parser, 0);
                                    if (parserMatch(parser, TokenKind.Semicolon)) {
                                        parserAdd(
                                            parser, AstKind.ExpressionStatement, valueFirst.start,
                                            parserPrevious(parser).end,
                                            valueStart, 0);
                                        statementCount++;
                                    } else {
                                        foundTail = true;
                                    }
                                }
                            }
                            if (!parserExpect(parser, TokenKind.RightBrace)) return 0;
                        } else {
                            parseExpression(parser, 0);
                            if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
                        }
                        parserAdd(
                            parser, AstKind.WhenExpressionBranch, first.start, parserPrevious(parser).end,
                            branchStart,
                            isElse + statementCount * 2 + patternCount * 65536);
                        branchCount++;
                    }
                    if (!parserExpect(parser, TokenKind.RightBrace)) return 0;
                    root = parserAdd(
                        parser, AstKind.WhenExpression, first.start, parserPrevious(parser).end,
                        subtreeStart, branchCount + hasSubject * 65536);
                } else {
                if (parserMatch(parser, TokenKind.LeftBracket)) {
                    var count: u32 = 0;
                    if (!parserCheck(parser, TokenKind.RightBracket)) {
                        var elements = true;
                        while (elements) {
                            parseExpression(parser, 0);
                            count++;
                            if (!parserMatch(parser, TokenKind.Comma)) {
                                elements = false;
                            }
                        }
                    }
                    if (!parserExpect(parser, TokenKind.RightBracket)) return 0;
                    root = parserAdd(
                        parser, AstKind.ArrayLiteral, first.start, parserPrevious(parser).end,
                        subtreeStart, count);
                } else {
                if (parserMatch(parser, TokenKind.LeftParen)) {
                    if (parserMatch(parser, TokenKind.RightParen)) {
                        root = parserAdd(
                            parser, AstKind.UnitLiteral, first.start, parserPrevious(parser).end,
                            subtreeStart, 0);
                    } else {
                        root = parseExpression(parser, 0);
                        if (!parserExpect(parser, TokenKind.RightParen)) return 0;
                    }
                } else {
                    if (parserMatch(parser, TokenKind.KwSizeof)) {
                        if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
                        parseType(parser);
                        if (!parserExpect(parser, TokenKind.RightParen)) return 0;
                        root = parserAdd(
                            parser, AstKind.Sizeof, first.start, parserPrevious(parser).end,
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
        val token = parserPeek(parser);
        if (token.kind == TokenKind.Less) {
            if (parserGenericCallAhead(parser)) {
                parser.current++;
                var typeArgumentCount: u32 = 0;
                var typeArguments = true;
                while (typeArguments) {
                    parseType(parser);
                    typeArgumentCount++;
                    if (!parserMatch(parser, TokenKind.Comma)) {
                        typeArguments = false;
                    }
                }
                if (!parserExpect(parser, TokenKind.Greater)) return 0;
                var associated: u32 = 0;
                if (parserMatch(parser, TokenKind.Dot)) {
                    val name = parserPeek(parser);
                    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
                    root = parserAdd(
                        parser, AstKind.Member, name.start, name.end, subtreeStart,
                        typeArgumentCount);
                    associated = 1;
                }
                if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
                var argumentCount: u32 = 0;
                if (!parserCheck(parser, TokenKind.RightParen)) {
                    var arguments = true;
                    while (arguments) {
                        parseExpression(parser, 0);
                        argumentCount++;
                        if (!parserMatch(parser, TokenKind.Comma)) {
                            arguments = false;
                        }
                    }
                }
                if (!parserExpect(parser, TokenKind.RightParen)) return 0;
                root = parserAdd(
                    parser, AstKind.Call, first.start, parserPrevious(parser).end,
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
                    root = parserAdd(
                        parser, AstKind.Binary, first.start,
                        parser.nodes.data[right].end,
                        subtreeStart, token.kind.value);
                }
            }
        } else {
        if (token.kind == TokenKind.LeftParen) {
            parser.current++;
            var argumentCount: u32 = 0;
            if (!parserCheck(parser, TokenKind.RightParen)) {
                var arguments = true;
                while (arguments) {
                    parseExpression(parser, 0);
                    argumentCount++;
                    if (!parserMatch(parser, TokenKind.Comma)) arguments = false;
                }
            }
            if (!parserExpect(parser, TokenKind.RightParen)) return 0;
            root = parserAdd(
                parser, AstKind.Call, first.start, parserPrevious(parser).end,
                subtreeStart, argumentCount);
        } else {
            if (token.kind == TokenKind.Dot) {
                parser.current++;
                val name = parserPeek(parser);
                if (!parserExpect(parser, TokenKind.Identifier)) return 0;
                root = parserAdd(
                    parser, AstKind.Member, name.start, name.end, subtreeStart, 0);
            } else {
                if (token.kind == TokenKind.LeftBracket) {
                    parser.current++;
                    parseExpression(parser, 0);
                    if (!parserExpect(parser, TokenKind.RightBracket)) return 0;
                    root = parserAdd(
                        parser, AstKind.Index, first.start, parserPrevious(parser).end,
                        subtreeStart, 0);
                } else {
                    var postfix = token.kind == TokenKind.Bang;
                    if (token.kind == TokenKind.PlusPlus) postfix = true;
                    if (token.kind == TokenKind.MinusMinus) postfix = true;
                    if (postfix) {
                        parser.current++;
                        root = parserAdd(
                            parser, AstKind.Postfix, first.start, token.end,
                            subtreeStart, token.kind.value);
                    } else {
                        if (token.kind == TokenKind.KwAs) {
                            if (85 < minimumPower) {
                                parsing = false;
                            } else {
                                parser.current++;
                                parseType(parser);
                                root = parserAdd(
                                    parser, AstKind.Cast, first.start,
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
                                    root = parserAdd(
                                        parser, nodeKind, first.start,
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

fn parserGenericCallAhead(parser: Parser): bool {
    var depth: u32 = 1;
    for (cursor in parser.current + 1..<parser.tokens.length) {
        val kind = parser.tokens.data[cursor].kind;
        if (kind == TokenKind.Less) {
            depth++;
        } else {
            if (kind == TokenKind.Greater) {
                depth--;
                if (depth == 0) {
                    if (cursor + 1 >= parser.tokens.length) {
                        return false;
                    }
                    val next = parser.tokens.data[cursor + 1].kind;
                    if (next == TokenKind.LeftParen) return true;
                    if (next != TokenKind.Dot) return false;
                    if (cursor + 3 >= parser.tokens.length) return false;
                    if (parser.tokens.data[cursor + 2].kind != TokenKind.Identifier) return false;
                    return parser.tokens.data[cursor + 3].kind == TokenKind.LeftParen;
                }
            }
        }
    }
    return false;
}
