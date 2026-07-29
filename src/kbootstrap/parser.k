module kbootstrap.parser;

import kbootstrap.token.Token;
import kbootstrap.ast.AstNode;
import kbootstrap.containers.ByteBuffer;

struct ParseResult(nodes: AstList, ok: bool, errorStart: u64, expectedKind: u32)
struct Parser(
    tokens: TokenList, nodes: AstList, current: u64,
    ok: bool, expectedKind: u32)

fn parserPeek(parser: Parser) => parser.tokens.data[parser.current];

fn parserPrevious(parser: Parser) => parser.tokens.data[parser.current - 1];

fn parserCheck(parser: Parser, kind: u32) => parserPeek(parser).kind == kind;

fn parserMatch(var parser: Parser, kind: u32): bool {
    if (parserCheck(parser, kind)) {
        parser.current++;
        return true;
    }
    return false;
}

fn parserExpect(var parser: Parser, kind: u32): bool {
    if (parserMatch(parser, kind)) return true;
    parser.ok = false;
    parser.expectedKind = kind;
    return false;
}

fn parserAdd(
    var parser: Parser,
    kind: u32,
    start: u64,
    end: u64,
    subtreeStart: u64,
    aux: u32): u64 {
    var nodes = parser.nodes;
    val index = nodes.add(
        AstNode(
            kind, start, end, subtreeStart, aux,
            0, 0, 0, 0, 0, 0, 0));
    parser.nodes = nodes;
    return index;
}

fn isTypeStart(kind: u32): bool {
    if (kind == 1) return true;
    if (kind >= 32) {
        if (kind <= 49) return true;
    }
    return false;
}

fn parseType(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parserPeek(parser);
    if (parserMatch(parser, 54)) {
        if (!parserExpect(parser, 55)) return 0;
        val element = parseType(parser);
        return parserAdd(
            parser, 4, first.start, parser.nodes.data[element].end,
            subtreeStart, 0);
    }
    if (!isTypeStart(first.kind)) {
        parser.ok = false;
        return 0;
    }
    val typeToken = first;
    parser.current++;
    var typeArgumentCount: u32 = 0;
    if (parserMatch(parser, 66)) {
        var typeArguments = true;
        while (typeArguments) {
            parseType(parser);
            typeArgumentCount++;
            if (!parserMatch(parser, 56)) {
                typeArguments = false;
            }
        }
        if (!parserExpect(parser, 67)) return 0;
    }
    var end = parserPrevious(parser).end;
    var root = parserAdd(
        parser, 1, typeToken.start, typeToken.end, subtreeStart,
        typeToken.kind + typeArgumentCount * 256);
    while (parserMatch(parser, 62)) {
        end = parserPrevious(parser).end;
        root = parserAdd(parser, 2, typeToken.start, end, subtreeStart, 0);
    }
    while (parserMatch(parser, 54)) {
        var hasSize: u32 = 0;
        if (!parserCheck(parser, 55)) {
            parseExpression(parser, 0);
            hasSize = 1;
        }
        if (!parserExpect(parser, 55)) return 0;
        end = parserPrevious(parser).end;
        root = parserAdd(
            parser, 5, typeToken.start, end, subtreeStart, hasSize);
    }
    if (parserMatch(parser, 72)) {
        if (parser.nodes.data[root].kind == 3) {
            parser.ok = false;
            return 0;
        }
        end = parserPrevious(parser).end;
        root = parserAdd(parser, 3, typeToken.start, end, subtreeStart, 0);
    }
    return root;
}

fn prefixBindingPower(kind: u32): u32 {
    return when (kind) {
        60, 61, 68, 71, 73 -> 90;
        else -> 0;
    };
}

fn leftBindingPower(kind: u32): u32 {
    if (kind >= 65) {
        if (kind <= 78) return 10;
    }
    if (kind >= 66) {
        if (kind <= 67) return 50;
    }
    return when (kind) {
		18 -> 50;
        84 -> 20;
        83 -> 30;
        79, 80 -> 40;
        81, 82 -> 50;
        87, 88, 93, 94 -> 60;
        60, 61 -> 70;
        62, 63, 64 -> 80;
        else -> 0;
    };
}

fn rightBindingPower(kind: u32): u32 {
    val left = leftBindingPower(kind);
    if (left == 10) return 10;
    return left + 1;
}

fn isAssignmentKind(kind: u32): bool {
    if (kind == 65) return true;
    if (kind >= 74) {
        if (kind <= 78) return true;
    }
    return false;
}

fn isLiteralKind(kind: u32): bool {
    if (kind >= 2) {
        if (kind <= 5) return true;
    }
    if (kind >= 29) {
        if (kind <= 31) return true;
    }
    return false;
}

fn parseValueExpressionBranch(var parser: Parser): u32 {
    var statementCount: u32 = 0;
    if (parserMatch(parser, 52)) {
        var foundTail = false;
        while (!foundTail) {
            if (parserCheck(parser, 53)) {
                parser.ok = false;
                return 0;
            }
            val next = parserPeek(parser).kind;
            var statementStart = next == 6;
            if (next == 7) statementStart = true;
            if (next == 14) statementStart = true;
            if (next == 15) statementStart = true;
            if (next == 17) statementStart = true;
            if (next == 19) statementStart = true;
            if (next == 20) statementStart = true;
            if (next == 52) statementStart = true;
            if (next == 89) statementStart = true;
            if (next == 90) statementStart = true;
            if (statementStart) {
                parseStatement(parser);
                statementCount++;
            } else {
                val valueStart = parser.nodes.length;
                val valueFirst = parserPeek(parser);
                parseExpression(parser, 0);
                if (parserMatch(parser, 58)) {
                    parserAdd(
                        parser, 35, valueFirst.start,
                        parserPrevious(parser).end, valueStart, 0);
                    statementCount++;
                } else {
                    foundTail = true;
                }
            }
        }
        if (!parserExpect(parser, 53)) return 0;
    } else {
        parseExpression(parser, 0);
    }
    return statementCount;
}

fn parseExpression(var parser: Parser, minimumPower: u32): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parserPeek(parser);
    var root: u64 = 0;
    if (first.kind == 1) {
        parser.current++;
        root = parserAdd(
            parser, 10, first.start, first.end, subtreeStart, 0);
    } else {
        if (isLiteralKind(first.kind)) {
            parser.current++;
            root = parserAdd(
                parser, 11, first.start, first.end, subtreeStart, first.kind);
        } else {
            val prefixPower = prefixBindingPower(first.kind);
            if (prefixPower != 0) {
                parser.current++;
                val operand = parseExpression(parser, prefixPower);
                if (!parser.ok) return 0;
                root = parserAdd(
                    parser, 12, first.start, parser.nodes.data[operand].end,
                    subtreeStart, first.kind);
            } else {
                if (parserMatch(parser, 15)) {
                    if (!parserExpect(parser, 50)) return 0;
                    parseExpression(parser, 0);
                    if (!parserExpect(parser, 51)) return 0;
                    val thenCount = parseValueExpressionBranch(parser);
                    if (!parserExpect(parser, 16)) return 0;
                    val elseCount = parseValueExpressionBranch(parser);
                    root = parserAdd(
                        parser, 25, first.start, parserPrevious(parser).end,
                        subtreeStart, thenCount + elseCount * 65536);
                } else {
                if (parserMatch(parser, 14)) {
                    var hasSubject: u32 = 0;
                    if (parserMatch(parser, 50)) {
                        parseExpression(parser, 0);
                        if (!parserExpect(parser, 51)) return 0;
                        hasSubject = 1;
                    }
                    if (!parserExpect(parser, 52)) return 0;
                    var branchCount: u32 = 0;
                    var hasElse = false;
                    while (!parserCheck(parser, 53)) {
                        val branchStart = parser.nodes.length;
                        var isElse: u32 = 0;
                        var patternCount: u32 = 0;
                        if (parserMatch(parser, 16)) {
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
                                else if (!parserMatch(parser, 56)) patterns = false;
                            }
                        }
                        if (!parserExpect(parser, 85)) return 0;
                        var statementCount: u32 = 0;
                        if (parserMatch(parser, 52)) {
                            var foundTail = false;
                            while (!foundTail) {
                                if (parserCheck(parser, 53)) {
                                    parser.ok = false;
                                    return 0;
                                }
                                val next = parserPeek(parser).kind;
                                var statementStart = next == 6;
                                if (next == 7) statementStart = true;
                                if (next == 15) statementStart = true;
                                if (next == 17) statementStart = true;
                                if (next == 19) statementStart = true;
                                if (next == 20) statementStart = true;
                                if (next == 52) statementStart = true;
                                if (next == 89) statementStart = true;
                                if (next == 90) statementStart = true;
                                if (statementStart) {
                                    parseStatement(parser);
                                    statementCount++;
                                } else {
                                    val valueStart = parser.nodes.length;
                                    val valueFirst = parserPeek(parser);
                                    parseExpression(parser, 0);
                                    if (parserMatch(parser, 58)) {
                                        parserAdd(
                                            parser, 35, valueFirst.start,
                                            parserPrevious(parser).end,
                                            valueStart, 0);
                                        statementCount++;
                                    } else {
                                        foundTail = true;
                                    }
                                }
                            }
                            if (!parserExpect(parser, 53)) return 0;
                        } else {
                            parseExpression(parser, 0);
                            if (!parserExpect(parser, 58)) return 0;
                        }
                        parserAdd(
                            parser, 24, first.start, parserPrevious(parser).end,
                            branchStart,
                            isElse + statementCount * 2 + patternCount * 65536);
                        branchCount++;
                    }
                    if (!parserExpect(parser, 53)) return 0;
                    root = parserAdd(
                        parser, 23, first.start, parserPrevious(parser).end,
                        subtreeStart, branchCount + hasSubject * 65536);
                } else {
                if (parserMatch(parser, 54)) {
                    var count: u32 = 0;
                    if (!parserCheck(parser, 55)) {
                        var elements = true;
                        while (elements) {
                            parseExpression(parser, 0);
                            count++;
                            if (!parserMatch(parser, 56)) {
                                elements = false;
                            }
                        }
                    }
                    if (!parserExpect(parser, 55)) return 0;
                    root = parserAdd(
                        parser, 22, first.start, parserPrevious(parser).end,
                        subtreeStart, count);
                } else {
                if (parserMatch(parser, 50)) {
                    if (parserMatch(parser, 51)) {
                        root = parserAdd(
                            parser, 20, first.start, parserPrevious(parser).end,
                            subtreeStart, 0);
                    } else {
                        root = parseExpression(parser, 0);
                        if (!parserExpect(parser, 51)) return 0;
                    }
                } else {
                    if (parserMatch(parser, 28)) {
                        if (!parserExpect(parser, 50)) return 0;
                        parseType(parser);
                        if (!parserExpect(parser, 51)) return 0;
                        root = parserAdd(
                            parser, 21, first.start, parserPrevious(parser).end,
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
        if (token.kind == 66) {
            if (parserGenericCallAhead(parser)) {
                parser.current++;
                var typeArgumentCount: u32 = 0;
                var typeArguments = true;
                while (typeArguments) {
                    parseType(parser);
                    typeArgumentCount++;
                    if (!parserMatch(parser, 56)) {
                        typeArguments = false;
                    }
                }
                if (!parserExpect(parser, 67)) return 0;
                if (!parserExpect(parser, 50)) return 0;
                var argumentCount: u32 = 0;
                if (!parserCheck(parser, 51)) {
                    var arguments = true;
                    while (arguments) {
                        parseExpression(parser, 0);
                        argumentCount++;
                        if (!parserMatch(parser, 56)) {
                            arguments = false;
                        }
                    }
                }
                if (!parserExpect(parser, 51)) return 0;
                root = parserAdd(
                    parser, 16, first.start, parserPrevious(parser).end,
                    subtreeStart,
                    argumentCount + typeArgumentCount * 65536);
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
                        parser, 13, first.start,
                        parser.nodes.data[right].end,
                        subtreeStart, token.kind);
                }
            }
        } else {
        if (token.kind == 50) {
            parser.current++;
            var argumentCount: u32 = 0;
            if (!parserCheck(parser, 51)) {
                var arguments = true;
                while (arguments) {
                    parseExpression(parser, 0);
                    argumentCount++;
                    if (!parserMatch(parser, 56)) arguments = false;
                }
            }
            if (!parserExpect(parser, 51)) return 0;
            root = parserAdd(
                parser, 16, first.start, parserPrevious(parser).end,
                subtreeStart, argumentCount);
        } else {
            if (token.kind == 59) {
                parser.current++;
                val name = parserPeek(parser);
                if (!parserExpect(parser, 1)) return 0;
                root = parserAdd(
                    parser, 17, name.start, name.end, subtreeStart, 0);
            } else {
                if (token.kind == 54) {
                    parser.current++;
                    parseExpression(parser, 0);
                    if (!parserExpect(parser, 55)) return 0;
                    root = parserAdd(
                        parser, 18, first.start, parserPrevious(parser).end,
                        subtreeStart, 0);
                } else {
                    var postfix = token.kind == 73;
                    if (token.kind == 91) postfix = true;
                    if (token.kind == 92) postfix = true;
                    if (postfix) {
                        parser.current++;
                        root = parserAdd(
                            parser, 19, first.start, token.end,
                            subtreeStart, token.kind);
                    } else {
                        if (token.kind == 27) {
                            if (85 < minimumPower) {
                                parsing = false;
                            } else {
                                parser.current++;
                                parseType(parser);
                                root = parserAdd(
                                    parser, 15, first.start,
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
                                        var assignable = leftKind == 10;
                                        if (leftKind == 17) assignable = true;
                                        if (leftKind == 18) assignable = true;
                                        if (leftKind == 12) {
                                            if (parser.nodes.data[root].aux == 62) {
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
                                    var nodeKind: u32 = 13;
                                    if (isAssignmentKind(token.kind)) {
                                        nodeKind = 14;
                                    }
                                    root = parserAdd(
                                        parser, nodeKind, first.start,
                                        parser.nodes.data[right].end,
                                        subtreeStart, token.kind);
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
        if (kind == 66) {
            depth++;
        } else {
            if (kind == 67) {
                depth--;
                if (depth == 0) {
                    if (cursor + 1 >= parser.tokens.length) {
                        return false;
                    }
                    return parser.tokens.data[cursor + 1].kind == 50;
                }
            }
        }
    }
    return false;
}

fn parseBlock(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    if (!parserExpect(parser, 52)) return 0;
    var count: u32 = 0;
    while (parser.ok) {
        if (parserCheck(parser, 53)) {
            parser.current++;
            return parserAdd(parser, 30, 0, 0, subtreeStart, count);
        }
        if (parserCheck(parser, 0)) {
            parser.ok = false;
        } else {
            parseStatement(parser);
            count++;
        }
    }
    return 0;
}

fn parseControlBody(var parser: Parser): u64 {
    if (parserCheck(parser, 52)) return parseBlock(parser);
    val subtreeStart = parser.nodes.length;
    parseStatement(parser);
    return parserAdd(parser, 30, 0, 0, subtreeStart, 1);
}

fn parseStatement(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parserPeek(parser);
    if (parserMatch(parser, 14)) {
        var hasSubject: u32 = 0;
        if (parserMatch(parser, 50)) {
            parseExpression(parser, 0);
            if (!parserExpect(parser, 51)) return 0;
            hasSubject = 1;
        }
        if (!parserExpect(parser, 52)) return 0;
        var branchCount: u32 = 0;
        var hasElse = false;
        while (parser.ok) {
            if (parserCheck(parser, 53)) {
                parser.current++;
                return parserAdd(
                    parser, 39, first.start, parserPrevious(parser).end,
                    subtreeStart, branchCount + hasSubject * 65536);
            }
            val branchStart = parser.nodes.length;
            var isElse: u32 = 0;
            var patternCount: u32 = 0;
            if (parserMatch(parser, 16)) {
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
                    else if (!parserMatch(parser, 56)) patterns = false;
                }
            }
            if (!parserExpect(parser, 85)) return 0;
            parseControlBody(parser);
            parserAdd(
                parser, 40, first.start, parserPrevious(parser).end,
                branchStart, isElse + patternCount * 65536);
            branchCount++;
        }
        return 0;
    }
    if (parserMatch(parser, 15)) {
        if (!parserExpect(parser, 50)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, 51)) return 0;
        parseControlBody(parser);
        var end = parserPrevious(parser).end;
        var hasElse: u32 = 0;
        if (parserMatch(parser, 16)) {
            parseControlBody(parser);
            end = parserPrevious(parser).end;
            hasElse = 1;
        }
        return parserAdd(parser, 31, first.start, end, subtreeStart, hasElse);
    }
    if (parserMatch(parser, 19)) {
        if (!parserExpect(parser, 50)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, 51)) return 0;
        parseControlBody(parser);
        val end = parserPrevious(parser).end;
        return parserAdd(
            parser, 32, first.start, end,
            subtreeStart, 0);
    }
    if (parserMatch(parser, 89)) {
        if (!parserExpect(parser, 58)) return 0;
        return parserAdd(
            parser, 36, first.start, parserPrevious(parser).end,
            subtreeStart, 0);
    }
    if (parserMatch(parser, 17)) {
        if (!parserExpect(parser, 50)) return 0;
        if (!parserExpect(parser, 1)) return 0;
        val name = parserPrevious(parser);
        parserAdd(parser, 45, name.start, name.end, parser.nodes.length, 0);
        var hasIndex: u32 = 0;
        if (parserMatch(parser, 56)) {
            if (!parserExpect(parser, 1)) return 0;
            val indexName = parserPrevious(parser);
            parserAdd(
                parser, 45, indexName.start, indexName.end,
                parser.nodes.length, 0);
            hasIndex = 1;
        }
        if (!parserExpect(parser, 18)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, 51)) return 0;
        parseControlBody(parser);
        return parserAdd(
            parser, 38, first.start, parserPrevious(parser).end,
            subtreeStart, hasIndex);
    }
    if (parserMatch(parser, 90)) {
        if (!parserExpect(parser, 58)) return 0;
        return parserAdd(
            parser, 37, first.start, parserPrevious(parser).end,
            subtreeStart, 0);
    }
    var isVariable = first.kind == 6;
    if (first.kind == 7) isVariable = true;
    if (isVariable) {
        parser.current++;
        if (!parserExpect(parser, 1)) return 0;
        val variableName = parserPrevious(parser);
        parserAdd(
            parser, 45, variableName.start, variableName.end,
            parser.nodes.length, 0);
        if (parserMatch(parser, 57)) parseType(parser);
        if (!parserExpect(parser, 65)) return 0;
        parseExpression(parser, 0);
        if (!parserExpect(parser, 58)) return 0;
        return parserAdd(
            parser, 33, first.start, parserPrevious(parser).end,
            subtreeStart, first.kind);
    }
    if (parserMatch(parser, 20)) {
        var hasValue: u32 = 0;
        if (!parserCheck(parser, 58)) {
            parseExpression(parser, 0);
            hasValue = 1;
        }
        if (!parserExpect(parser, 58)) return 0;
        return parserAdd(
            parser, 34, first.start, parserPrevious(parser).end,
            subtreeStart, hasValue);
    }
    if (parserCheck(parser, 52)) return parseBlock(parser);
    parseExpression(parser, 0);
    if (!parserExpect(parser, 58)) return 0;
    return parserAdd(
        parser, 35, first.start, parserPrevious(parser).end,
        subtreeStart, 0);
}

fn arrowIfHasElseAhead(parser: Parser): bool {
    for (cursor in parser.current..<parser.tokens.length) {
        val kind = parser.tokens.data[cursor].kind;
        if (kind == 16) return true;
        var declaration = kind == 0;
        if (kind == 8) declaration = true;
        if (kind == 9) declaration = true;
        if (kind == 10) declaration = true;
        if (kind == 11) declaration = true;
        if (kind == 24) declaration = true;
        if (declaration) return false;
    }
    return false;
}

fn parseFunction(
    var parser: Parser, isExtern: bool, start: u64,
    ownerStart: u64, ownerEnd: u64
): u64 {
    val subtreeStart = parser.nodes.length;
    if (!parserExpect(parser, 10)) return 0;
    if (!parserExpect(parser, 1)) return 0;
    val functionName = parserPrevious(parser);
    parserAdd(
        parser, 45, functionName.start, functionName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parserMatch(parser, 66)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            if (!parserExpect(parser, 1)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, 45, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parserMatch(parser, 57)) {
                if (!parserExpect(parser, 1)) return 0;
                val constraint = parserPrevious(parser);
                parserAdd(
                    parser, 45, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parserAdd(
                parser, 46, parameterStart, parserPrevious(parser).end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parserMatch(parser, 56)) {
                typeParameters = false;
            }
        }
        if (!parserExpect(parser, 67)) return 0;
    }
    if (!parserExpect(parser, 50)) return 0;
    var parameterCount: u32 = 0;
    if (!parserCheck(parser, 51)) {
        var parameters = true;
        while (parameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            var mode: u32 = 0;
            if (parserMatch(parser, 6)) mode = 1;
            else {
                if (parserMatch(parser, 7)) mode = 2;
            }
            if (!parserExpect(parser, 1)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, 45, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var typeNode: u64 = 0;
            if (ownerEnd != ownerStart && parameterCount == 0) {
                if (!parserCheck(parser, 57)) {
                    typeNode = parserAdd(
                        parser, 1, ownerStart, ownerEnd,
                        parser.nodes.length, 1);
                } else {
                    parser.current++;
                    typeNode = parseType(parser);
                }
            } else {
                if (!parserExpect(parser, 57)) return 0;
                typeNode = parseType(parser);
            }
            parserAdd(
                parser, 40, parameterStart, parser.nodes.data[typeNode].end,
                parameterSubtree, mode);
            parameterCount++;
            if (!parserMatch(parser, 56)) parameters = false;
        }
    }
    if (!parserExpect(parser, 51)) return 0;
    var infersReturn: u32 = 0;
    if (parserMatch(parser, 57)) {
        parseType(parser);
    } else {
        parserAdd(
            parser, 1, parserPrevious(parser).end,
            parserPrevious(parser).end, parser.nodes.length, 49);
        if (parserCheck(parser, 86)) infersReturn = 1;
    }
    var end: u64 = 0;
    var expressionBody: u32 = 0;
    if (isExtern) {
        if (!parserExpect(parser, 58)) return 0;
        end = parserPrevious(parser).end;
    } else {
        if (parserMatch(parser, 86)) {
            expressionBody = 1;
            val bodyStart = parser.nodes.length;
            if (parserCheck(parser, 15) && !arrowIfHasElseAhead(parser)) {
                parseStatement(parser);
            } else {
                val expressionRoot = parseExpression(parser, 0);
                if (!parserExpect(parser, 58)) return 0;
                parserAdd(
                    parser, 34,
                    parser.nodes.data[expressionRoot].start,
                    parser.nodes.data[expressionRoot].end,
                    bodyStart, 1);
            }
            parserAdd(parser, 30, 0, 0, bodyStart, 1);
            end = parserPrevious(parser).end;
        } else {
        parseBlock(parser);
        end = parserPrevious(parser).end;
        }
    }
    var aux = parameterCount;
    if (isExtern) aux += 65536;
    aux += typeParameterCount * 131072;
    val root = parserAdd(parser, 41, start, end, subtreeStart, aux);
    var function = parser.nodes.data[root];
    function.storage = (expressionBody + infersReturn * 2) as u64;
    if (ownerEnd > ownerStart) {
        function.conversionKind = 1;
    }
    parser.nodes.data[root] = function;
    return root;
}

fn parseStruct(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, 1)) return 0;
    val structName = parserPrevious(parser);
    parserAdd(
        parser, 45, structName.start, structName.end,
        parser.nodes.length, 0);
    var typeParameterCount: u32 = 0;
    if (parserMatch(parser, 66)) {
        var typeParameters = true;
        while (typeParameters) {
            val parameterSubtree = parser.nodes.length;
            val parameterStart = parserPeek(parser).start;
            if (!parserExpect(parser, 1)) return 0;
            val parameterName = parserPrevious(parser);
            parserAdd(
                parser, 45, parameterName.start, parameterName.end,
                parser.nodes.length, 0);
            var hasConstraint: u32 = 0;
            if (parserMatch(parser, 57)) {
                if (!parserExpect(parser, 1)) return 0;
                val constraint = parserPrevious(parser);
                parserAdd(
                    parser, 45, constraint.start, constraint.end,
                    parser.nodes.length, 0);
                hasConstraint = 1;
            }
            parserAdd(
                parser, 46, parameterStart, parserPrevious(parser).end,
                parameterSubtree, hasConstraint);
            typeParameterCount++;
            if (!parserMatch(parser, 56)) {
                typeParameters = false;
            }
        }
        if (!parserExpect(parser, 67)) return 0;
    }
    if (!parserExpect(parser, 50)) return 0;
    var fieldCount: u32 = 0;
    if (!parserCheck(parser, 51)) {
        var fields = true;
        while (fields) {
            val fieldSubtree = parser.nodes.length;
            val fieldStart = parserPeek(parser).start;
            if (!parserExpect(parser, 1)) return 0;
            val fieldName = parserPrevious(parser);
            parserAdd(
                parser, 45, fieldName.start, fieldName.end,
                parser.nodes.length, 0);
            if (!parserExpect(parser, 57)) return 0;
            val typeNode = parseType(parser);
            parserAdd(
                parser, 42, fieldStart, parser.nodes.data[typeNode].end,
                fieldSubtree, 0);
            fieldCount++;
            if (!parserMatch(parser, 56)) fields = false;
        }
    }
    if (!parserExpect(parser, 51)) return 0;
    var methodCount: u32 = 0;
    if (parserMatch(parser, 52)) {
        while (!parserCheck(parser, 53)) {
            if (!parserCheck(parser, 10)) return 0;
            parseFunction(parser, false, parserPeek(parser).start,
                structName.start, structName.end);
            methodCount++;
        }
        if (!parserExpect(parser, 53)) return 0;
    }
    val root = parserAdd(
        parser, 43, start, parserPrevious(parser).end,
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
    if (parserExpect(parser, 1) == false) return 0;
    val name = parserPrevious(parser);
    parserAdd(parser, 45, name.start, name.end, parser.nodes.length, 0);
    if (parserExpect(parser, 52) == false) return 0;
    if (parserCheck(parser, 53)) {
        parser.ok = false;
        return 0;
    }
    var count: u32 = 0;
    var parsing = true;
    while (parsing) {
        if (parserExpect(parser, 1) == false) return 0;
        val variant = parserPrevious(parser);
        parserAdd(
            parser, 45, variant.start, variant.end,
            parser.nodes.length, 0);
        count++;
        if (parserMatch(parser, 56)) {
            if (parserCheck(parser, 53)) {
                parser.ok = false;
                return 0;
            }
        } else {
            parsing = false;
        }
    }
    if (parserExpect(parser, 53) == false) return 0;
    return parserAdd(
        parser, 49, start, parserPrevious(parser).end,
        subtreeStart, count);
}

fn parseModule(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, 1)) return 0;
    val firstName = parserPrevious(parser);
    parserAdd(
        parser, 45, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    while (parserMatch(parser, 59)) {
        if (!parserExpect(parser, 1)) return 0;
        val name = parserPrevious(parser);
        parserAdd(
            parser, 45, name.start, name.end,
            parser.nodes.length, 0);
        partCount++;
    }
    if (!parserExpect(parser, 58)) return 0;
    return parserAdd(
        parser, 47, start, parserPrevious(parser).end,
        subtreeStart, partCount);
}

fn parseImport(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, 1)) return 0;
    val firstName = parserPrevious(parser);
    parserAdd(
        parser, 45, firstName.start, firstName.end,
        parser.nodes.length, 0);
    var partCount: u32 = 1;
    var isWildcard: u32 = 0;
    var importing = true;
    while (importing) {
        if (!parserMatch(parser, 59)) {
            importing = false;
        } else {
            if (parserMatch(parser, 62)) {
                isWildcard = 1;
                partCount++;
                importing = false;
            } else {
                if (!parserExpect(parser, 1)) return 0;
                val name = parserPrevious(parser);
                parserAdd(
                    parser, 45, name.start, name.end,
                    parser.nodes.length, 0);
                partCount++;
            }
        }
    }
    if (!parserExpect(parser, 58)) return 0;
    return parserAdd(
        parser, 48, start, parserPrevious(parser).end,
        subtreeStart, partCount + isWildcard * 65536);
}

fn parseConstant(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val start = parserPeek(parser).start;
    parser.current++;
    if (!parserExpect(parser, 1)) return 0;
    val name = parserPrevious(parser);
    parserAdd(parser, 45, name.start, name.end, parser.nodes.length, 0);
    var hasType: u32 = 0;
    if (parserMatch(parser, 57)) { parseType(parser); hasType = 1; }
    if (!parserExpect(parser, 65)) return 0;
    parseExpression(parser, 0);
    if (!parserExpect(parser, 58)) return 0;
    return parserAdd(parser, 50, start, parserPrevious(parser).end, subtreeStart, hasType);
}

fn parse(tokens: TokenList): ParseResult {
    var parser = Parser(tokens, astListNew(), 0, true, 0);
    val start = parserPeek(parser).start;
    var declarationCount: u32 = 0;
    if (parserCheck(parser, 25)) {
        parseModule(parser);
        declarationCount++;
    }
    while (parserCheck(parser, 26)) {
        parseImport(parser);
        declarationCount++;
    }
    while (parser.ok) {
        if (parserCheck(parser, 0)) {
            val end = parserPeek(parser).end;
            parserAdd(parser, 44, start, end, 0, declarationCount);
            return ParseResult(parser.nodes, true, 0, 0);
        }
        if (parserCheck(parser, 25)) {
            parseModule(parser);
        } else {
            if (parserCheck(parser, 26)) {
                parseImport(parser);
            } else {
                if (parserCheck(parser, 24)) {
                    parseEnum(parser);
                } else {
                if (parserCheck(parser, 8)) {
                    parseConstant(parser);
                } else {
                if (parserCheck(parser, 11)) {
                    parseStruct(parser);
                } else {
                    var isExtern = false;
                    val declarationStart = parserPeek(parser).start;
                    if (parserMatch(parser, 9)) isExtern = true;
                    parseFunction(parser, isExtern, declarationStart, 0, 0);
                }
                }
                }
            }
        }
        declarationCount++;
    }
    return ParseResult(
        parser.nodes, false, parserPeek(parser).start, parser.expectedKind);
}
