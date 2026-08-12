module bootstrap.parser;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.token.tokenKindValue;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;

struct ParseResult(nodes: List<AstNode>, ok: bool, errorStart: u64, expectedKind: u32)
struct Parser(
    tokens: List<Token>, nodes: List<AstNode>, current: u64,
    ok: bool, expectedKind: u32)

fn parserPeek(parser: Parser) => parser.tokens.data[parser.current];

fn parserPrevious(parser: Parser) => parser.tokens.data[parser.current - 1];

fn parserCheck(parser: Parser, kind: TokenKind) => parserPeek(parser).kind == kind;

fn parserMatch(var parser: Parser, kind: TokenKind): bool {
    if (parserCheck(parser, kind)) {
        parser.current++;
        return true;
    }
    return false;
}

fn parserExpect(var parser: Parser, kind: TokenKind): bool {
    if (parserMatch(parser, kind)) return true;
    parser.ok = false;
    parser.expectedKind = tokenKindValue(kind);
    return false;
}

fn parserAdd(
    var parser: Parser,
    kind: AstKind,
    start: u64,
    end: u64,
    subtreeStart: u64,
    aux: u32): u64 {
    val index = parser.nodes.add(
        AstNode(
            kind, start, end, subtreeStart, aux,
            0, 0, 0, 0, 0, 0, 0, 0
		)
    );
    return index;
}

fn isTypeStart(kind: TokenKind): bool => when (kind) {
    TokenKind.Identifier,
    TokenKind.KwBool,
    TokenKind.KwI8,
    TokenKind.KwI16,
    TokenKind.KwI32,
    TokenKind.KwI64,
    TokenKind.KwI128,
    TokenKind.KwU8,
    TokenKind.KwU16,
    TokenKind.KwU32,
    TokenKind.KwU64,
    TokenKind.KwU128,
    TokenKind.KwF8,
    TokenKind.KwF16,
    TokenKind.KwF32,
    TokenKind.KwF64,
    TokenKind.KwChar,
    TokenKind.KwString,
    TokenKind.KwUnit -> true;
    else -> false;
};

fn parseType(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parserPeek(parser);
    if (parserMatch(parser, TokenKind.LeftBracket)) {
        if (!parserExpect(parser, TokenKind.RightBracket)) return 0;
        val element = parseType(parser);
        return parserAdd(
            parser, AstKind.SliceType, first.start, parser.nodes.data[element].end,
            subtreeStart, 0);
    }
    if (!isTypeStart(first.kind)) {
        parser.ok = false;
        return 0;
    }
    val typeToken = first;
    parser.current++;
    var typeArgumentCount: u32 = 0;
    if (parserMatch(parser, TokenKind.Less)) {
        var typeArguments = true;
        while (typeArguments) {
            parseType(parser);
            typeArgumentCount++;
            if (!parserMatch(parser, TokenKind.Comma)) {
                typeArguments = false;
            }
        }
        if (!parserExpect(parser, TokenKind.Greater)) return 0;
    }
    var end = parserPrevious(parser).end;
    var root = parserAdd(
        parser, AstKind.NamedType, typeToken.start, typeToken.end, subtreeStart,
        tokenKindValue(typeToken.kind) + typeArgumentCount * 256);
    while (parserMatch(parser, TokenKind.Star)) {
        end = parserPrevious(parser).end;
        root = parserAdd(parser, AstKind.PointerType, typeToken.start, end, subtreeStart, 0);
    }
    while (parserMatch(parser, TokenKind.LeftBracket)) {
        var hasSize: u32 = 0;
        if (!parserCheck(parser, TokenKind.RightBracket)) {
            parseExpression(parser, 0);
            hasSize = 1;
        }
        if (!parserExpect(parser, TokenKind.RightBracket)) return 0;
        end = parserPrevious(parser).end;
        root = parserAdd(
            parser, AstKind.ArrayType, typeToken.start, end, subtreeStart, hasSize);
    }
    if (parserMatch(parser, TokenKind.Question)) {
        if (parser.nodes.data[root].kind == AstKind.NullableType) {
            parser.ok = false;
            return 0;
        }
        end = parserPrevious(parser).end;
        root = parserAdd(parser, AstKind.NullableType, typeToken.start, end, subtreeStart, 0);
    }
    return root;
}

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
                tokenKindValue(first.kind));
        } else {
            val prefixPower = prefixBindingPower(first.kind);
            if (prefixPower != 0) {
                parser.current++;
                val operand = parseExpression(parser, prefixPower);
                if (!parser.ok) return 0;
                root = parserAdd(
                    parser, AstKind.Unary, first.start, parser.nodes.data[operand].end,
                    subtreeStart, tokenKindValue(first.kind));
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
                        subtreeStart, tokenKindValue(token.kind));
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
                            subtreeStart, tokenKindValue(token.kind));
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
                                                tokenKindValue(TokenKind.Star)) {
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
                                        subtreeStart, tokenKindValue(token.kind));
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
            subtreeStart, tokenKindValue(first.kind));
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

fn arrowIfHasElseAhead(parser: Parser): bool {
    for (cursor in parser.current..<parser.tokens.length) {
        val kind = parser.tokens.data[cursor].kind;
        if (kind == TokenKind.KwElse) return true;
        var declaration = kind == TokenKind.EndOfFile;
        if (kind == TokenKind.KwConst) declaration = true;
        if (kind == TokenKind.KwExtern) declaration = true;
        if (kind == TokenKind.KwFn) declaration = true;
        if (kind == TokenKind.KwStruct) declaration = true;
        if (kind == TokenKind.KwEnum) declaration = true;
        if (declaration) return false;
    }
    return false;
}

fn parseFunction(
    var parser: Parser, isExtern: bool, start: u64,
    ownerStart: u64, ownerEnd: u64
): u64 {
    val subtreeStart = parser.nodes.length;
    if (!parserExpect(parser, TokenKind.KwFn)) return 0;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val functionName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, functionName.start, functionName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parserMatch(parser, TokenKind.Less)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parserMatch(parser, TokenKind.Colon)) {
                if (!parserExpect(parser, TokenKind.Identifier)) return 0;
                val constraint = parserPrevious(parser);
                parserAdd(
                    parser, AstKind.Name, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parserAdd(
                parser, AstKind.TypeParameter, parameterStart, parserPrevious(parser).end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parserMatch(parser, TokenKind.Comma)) {
                typeParameters = false;
            }
        }
        if (!parserExpect(parser, TokenKind.Greater)) return 0;
    }
    if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
    var parameterCount: u32 = 0;
    var associated: u32 = 0;
    if (ownerEnd != ownerStart) associated = 1;
    if (!parserCheck(parser, TokenKind.RightParen)) {
        var parameters = true;
        while (parameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            var mode: u32 = 0;
            if (parserMatch(parser, TokenKind.KwVal)) mode = 1;
            else {
                if (parserMatch(parser, TokenKind.KwVar)) mode = 2;
            }
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var typeNode: u64 = 0;
            if (ownerEnd != ownerStart && parameterCount == 0) {
                if (!parserCheck(parser, TokenKind.Colon)) {
                    associated = 0;
                    typeNode = parserAdd(
                        parser, AstKind.NamedType, ownerStart, ownerEnd,
                        parser.nodes.length, 1);
                } else {
                    parser.current++;
                    typeNode = parseType(parser);
                }
            } else {
                if (!parserExpect(parser, TokenKind.Colon)) return 0;
                typeNode = parseType(parser);
            }
            parserAdd(
                parser, AstKind.ParameterOrWhenBranch, parameterStart, parser.nodes.data[typeNode].end,
                parameterSubtree, mode);
            parameterCount++;
            if (!parserMatch(parser, TokenKind.Comma)) parameters = false;
        }
    }
    if (!parserExpect(parser, TokenKind.RightParen)) return 0;
    var infersReturn: u32 = 0;
    if (parserMatch(parser, TokenKind.Colon)) {
        parseType(parser);
    } else {
        parserAdd(
            parser, AstKind.NamedType, parserPrevious(parser).end,
            parserPrevious(parser).end, parser.nodes.length, 49);
        if (parserCheck(parser, TokenKind.FatArrow)) infersReturn = 1;
    }
    var end: u64 = 0;
    var expressionBody: u32 = 0;
    if (isExtern) {
        if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
        end = parserPrevious(parser).end;
    } else {
        if (parserMatch(parser, TokenKind.FatArrow)) {
            expressionBody = 1;
            val bodyStart = parser.nodes.length;
            if (parserCheck(parser, TokenKind.KwIf) && !arrowIfHasElseAhead(parser)) {
                parseStatement(parser);
            } else {
                val expressionRoot = parseExpression(parser, 0);
                if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
                parserAdd(
                    parser, AstKind.ReturnStatement,
                    parser.nodes.data[expressionRoot].start,
                    parser.nodes.data[expressionRoot].end,
                    bodyStart, 1);
            }
            parserAdd(parser, AstKind.Block, 0, 0, bodyStart, 1);
            end = parserPrevious(parser).end;
        } else {
        parseBlock(parser);
        end = parserPrevious(parser).end;
        }
    }
    var aux = parameterCount;
    if (isExtern) aux += 65536;
    aux += typeParameterCount * 131072;
    val root = parserAdd(parser, AstKind.FunctionOrDefer, start, end, subtreeStart, aux);
    var function = parser.nodes.data[root];
    function.storage = (expressionBody + infersReturn * 2) as u64;
    if (ownerEnd > ownerStart) {
        function.conversionKind = 1 + associated;
    }
    parser.nodes.data[root] = function;
    return root;
}

fn parseStruct(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val structName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, structName.start, structName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parserMatch(parser, TokenKind.Less)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parserMatch(parser, TokenKind.Colon)) {
                if (!parserExpect(parser, TokenKind.Identifier)) return 0;
                val constraint = parserPrevious(parser);
                parserAdd(
                    parser, AstKind.Name, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parserAdd(
                parser, AstKind.TypeParameter, parameterStart, parserPrevious(parser).end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parserMatch(parser, TokenKind.Comma)) {
                typeParameters = false;
            }
        }
        if (!parserExpect(parser, TokenKind.Greater)) return 0;
    }
    if (!parserExpect(parser, TokenKind.LeftParen)) return 0;
    var fieldCount: u32 = 0;
    if (!parserCheck(parser, TokenKind.RightParen)) {
        var fields = true;
        while (fields) {
            val fieldSubtree = parser.nodes.length;
            val fieldStart = parserPeek(parser).start;
            if (!parserExpect(parser, TokenKind.Identifier)) return 0;
            val fieldName = parserPrevious(parser);
            parserAdd(
                parser, AstKind.Name, fieldName.start, fieldName.end,
                parser.nodes.length, 0);
            if (!parserExpect(parser, TokenKind.Colon)) return 0;
            val typeNode = parseType(parser);
            parserAdd(
                parser, AstKind.StructField, fieldStart, parser.nodes.data[typeNode].end,
                fieldSubtree, 0);
            fieldCount++;
            if (!parserMatch(parser, TokenKind.Comma)) fields = false;
        }
    }
    if (!parserExpect(parser, TokenKind.RightParen)) return 0;
    var methodCount: u32 = 0;
    if (parserMatch(parser, TokenKind.LeftBrace)) {
        while (!parserCheck(parser, TokenKind.RightBrace)) {
            if (!parserCheck(parser, TokenKind.KwFn)) return 0;
            parseFunction(parser, false, parserPeek(parser).start,
                structName.start, structName.end);
            methodCount++;
        }
        if (!parserExpect(parser, TokenKind.RightBrace)) return 0;
    }
    val root = parserAdd(
        parser, AstKind.StructDeclaration, start, parserPrevious(parser).end,
        subtreeStart, fieldCount + typeParameterCount * 65536);
    var structure = parser.nodes.data[root];
    structure.storage = methodCount as u64;
    parser.nodes.data[root] = structure;
    return root;
}

fn parseEnum(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (parserExpect(parser, TokenKind.Identifier) == false) return 0;
    val name = parserPrevious(parser);
    parserAdd(parser, AstKind.Name, name.start, name.end, parser.nodes.length, 0);
    var hasBacking: u64 = 0;
    if (parserMatch(parser, TokenKind.Colon)) {
        parseType(parser);
        hasBacking = parser.nodes.length - subtreeStart - 1;
    }
    if (parserExpect(parser, TokenKind.LeftBrace) == false) return 0;
    if (parserCheck(parser, TokenKind.RightBrace)) {
        parser.ok = false;
        return 0;
    }
    var count: u32 = 0;
    var parsing = true;
    while (parsing) {
        if (parserExpect(parser, TokenKind.Identifier) == false) return 0;
        val variant = parserPrevious(parser);
        val variantRoot = parserAdd(
            parser, AstKind.Name, variant.start, variant.end,
            parser.nodes.length, 0);
        if (parserMatch(parser, TokenKind.Equal)) {
            var negative: u32 = 0;
            if (parserMatch(parser, TokenKind.Plus)) {
            } else if (parserMatch(parser, TokenKind.Minus)) {
                negative = 1;
            }
            if (!parserExpect(parser, TokenKind.IntegerLiteral)) return 0;
            val value = parserPrevious(parser);
            var variantNode = parser.nodes.data[variantRoot];
            variantNode.conversionKind = 1;
            variantNode.storage = value.start;
            variantNode.typeName = value.end;
            variantNode.ownership = negative;
            parser.nodes.data[variantRoot] = variantNode;
        }
        count++;
        if (parserMatch(parser, TokenKind.Comma)) {
            if (parserCheck(parser, TokenKind.RightBrace)) {
                parser.ok = false;
                return 0;
            }
        } else {
            parsing = false;
        }
    }
    if (parserExpect(parser, TokenKind.RightBrace) == false) return 0;
    val root = parserAdd(
        parser, AstKind.EnumDeclaration, start, parserPrevious(parser).end,
        subtreeStart, count);
    var enumeration = parser.nodes.data[root];
    enumeration.storage = hasBacking;
    parser.nodes.data[root] = enumeration;
    return root;
}

fn parseModule(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val firstName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    while (parserMatch(parser, TokenKind.Dot)) {
        if (!parserExpect(parser, TokenKind.Identifier)) return 0;
        val name = parserPrevious(parser);
        parserAdd(
            parser, AstKind.Name, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ModuleDeclaration, start, parserPrevious(parser).end,
        subtreeStart, partCount);
}

fn parseImport(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val firstName = parserPrevious(parser);
    parserAdd(
        parser, AstKind.Name, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    var isWildcard: u32 = 0;
    while (parserMatch(parser, TokenKind.Dot)) {
        if (parserMatch(parser, TokenKind.Star)) {
            isWildcard = 1;
            partCount++;
            break;
        }
        if (!parserExpect(parser, TokenKind.Identifier)) return 0;
        val name = parserPrevious(parser);
        parserAdd(
            parser, AstKind.Name, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ImportDeclaration, start, parserPrevious(parser).end,
        subtreeStart, partCount + isWildcard * 65536);
}

fn parseConstant(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, TokenKind.Identifier)) return 0;
    val name = parserPrevious(parser);
    parserAdd(parser, AstKind.Name, name.start, name.end, parser.nodes.length, 0);
    var hasType: u32 = 0;
    if (parserMatch(parser, TokenKind.Colon)) { parseType(parser); hasType = 1; }
    if (!parserExpect(parser, TokenKind.Equal)) return 0;
    parseExpression(parser, 0);
    if (!parserExpect(parser, TokenKind.Semicolon)) return 0;
    return parserAdd(
        parser, AstKind.ConstantDeclaration, start,
        parserPrevious(parser).end, subtreeStart, hasType);
}

fn parse(val tokens: List<Token>): ParseResult {
    var parser = Parser(tokens, List<AstNode>.new(), 0, true, 0);
    val start = parserPeek(parser).start;
    var declarationCount: u32 = 0;
    if (parserCheck(parser, TokenKind.KwModule)) {
        parseModule(parser);
        declarationCount++;
    }
    while (parserCheck(parser, TokenKind.KwImport)) {
        parseImport(parser);
        declarationCount++;
    }
    while (parser.ok) {
        if (parserCheck(parser, TokenKind.EndOfFile)) break;
        if (parserCheck(parser, TokenKind.KwModule)) {
            parseModule(parser);
        } else if (parserCheck(parser, TokenKind.KwImport)) {
            parseImport(parser);
        } else if (parserCheck(parser, TokenKind.KwEnum)) {
            parseEnum(parser);
        } else if (parserCheck(parser, TokenKind.KwConst)) {
            parseConstant(parser);
        } else if (parserCheck(parser, TokenKind.KwStruct)) {
            parseStruct(parser);
        } else {
            var isExtern = false;
            val declarationStart = parserPeek(parser).start;
            if (parserMatch(parser, TokenKind.KwExtern)) isExtern = true;
            parseFunction(parser, isExtern, declarationStart, 0, 0);
        }
        declarationCount++;
    }
    var ok = false;
    var errorStart: u64 = 0;
    var expectedKind: u32 = 0;
    if (parserCheck(parser, TokenKind.EndOfFile)) {
        val end = parserPeek(parser).end;
        parserAdd(parser, AstKind.Program, start, end, 0, declarationCount);
        ok = true;
    } else {
        errorStart = parserPeek(parser).start;
        expectedKind = parser.expectedKind;
    }
    return ParseResult(parser.nodes, ok, errorStart, expectedKind);
}
