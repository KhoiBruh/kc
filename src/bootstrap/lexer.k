module bootstrap.lexer;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;

extern fn k_boot_arg_count(): i32;
extern fn k_boot_arg(index: i32, data: u8**, length: u64*): bool;
extern fn k_boot_read_file(path: u8*, pathLength: u64, data: u8**, length: u64*): bool;

struct LexResult(tokens: List<Token>, ok: bool, errorStart: u64, errorKind: u32)

fn isWhitespace(value: u8) => when (value) {
    9, 10, 13, 32 -> true;
    else -> false;
};

fn isDigit(value: u8) => value in 48..57;

fn isIdentifierStart(value: u8) => when {
	value == 95 -> true;
	value in 65..90 -> true;
	value in 97..122 -> true;
	else -> false;
};

fn isIdentifierContinue(value: u8) => if (isIdentifierStart(value)) true else isDigit(value);

fn matches2(source: Source, start: u64, a: u8, b: u8) => when {
    source.data[start] != a -> false;
    source.data[start + 1] != b -> false;
    else -> true;
};

fn keywordKind(source: Source, start: u64, end: u64): TokenKind {
    val length = end - start;
    if (length == 2) {
        if (matches2(source, start, 102, 110)) return TokenKind.KwFn;
        if (matches2(source, start, 105, 102)) return TokenKind.KwIf;
        if (matches2(source, start, 105, 110)) return TokenKind.KwIn;
        if (matches2(source, start, 117, 56)) return TokenKind.KwU8;
        if (matches2(source, start, 97, 115)) return TokenKind.KwAs;
    }
    if (length == 3) {
        if (source.data[start] == 118) {
            if (source.data[start + 1] == 97) {
                if (source.data[start + 2] == 108) return TokenKind.KwVal;
                if (source.data[start + 2] == 114) return TokenKind.KwVar;
            }
        }
        if (source.data[start] == 105) {
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return TokenKind.KwI32;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return TokenKind.KwI64;
            }
        }
        if (source.data[start] == 117) {
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return TokenKind.KwU32;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return TokenKind.KwU64;
            }
        }
        if (source.data[start] == 102) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 114) return TokenKind.KwFor;
            }
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return TokenKind.KwF32;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return TokenKind.KwF64;
            }
        }
    }
    if (length == 4) {
        if (source.data[start] == 119) {
            if (source.data[start + 1] == 104) {
                if (source.data[start + 2] == 101) {
                    if (source.data[start + 3] == 110) return TokenKind.KwWhen;
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 108) {
                if (source.data[start + 2] == 115) {
                    if (source.data[start + 3] == 101) return TokenKind.KwElse;
                }
            }
        }
        if (source.data[start] == 117) {
            if (source.data[start + 1] == 110) {
                if (source.data[start + 2] == 105) {
                    if (source.data[start + 3] == 116) return TokenKind.KwUnit;
                }
            }
        }
        if (source.data[start] == 98) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 111) {
                    if (source.data[start + 3] == 108) return TokenKind.KwBool;
                }
            }
        }
        if (source.data[start] == 116) {
            if (source.data[start + 1] == 114) {
                if (source.data[start + 2] == 117) {
                    if (source.data[start + 3] == 101) return TokenKind.KwTrue;
                }
            }
        }
        if (source.data[start] == 110) {
            if (source.data[start + 1] == 117) {
                if (source.data[start + 2] == 108) {
                    if (source.data[start + 3] == 108) return TokenKind.KwNull;
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 110) {
                if (source.data[start + 2] == 117) {
                    if (source.data[start + 3] == 109) return TokenKind.KwEnum;
                }
            }
        }
    }
    if (length == 5) {
        if (source.data[start] == 99) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 110) {
                    if (source.data[start + 3] == 115) {
                        if (source.data[start + 4] == 116) return TokenKind.KwConst;
                    }
                }
            }
        }
        if (source.data[start] == 98) {
            if (source.data[start + 1] == 114) {
                if (source.data[start + 2] == 101) {
                    if (source.data[start + 3] == 97) {
                        if (source.data[start + 4] == 107) return TokenKind.KwBreak;
                    }
                }
            }
        }
        if (source.data[start] == 119) {
            if (source.data[start + 1] == 104) {
                if (source.data[start + 2] == 105) {
                    if (source.data[start + 3] == 108) {
                        if (source.data[start + 4] == 101) return TokenKind.KwWhile;
                    }
                }
            }
        }
        if (source.data[start] == 100) {
            if (source.data[start + 1] == 101) {
                if (source.data[start + 2] == 102) {
                    if (source.data[start + 3] == 101) {
                        if (source.data[start + 4] == 114) return TokenKind.KwDefer;
                    }
                }
            }
        }
        if (source.data[start] == 102) {
            if (source.data[start + 1] == 97) {
                if (source.data[start + 2] == 108) {
                    if (source.data[start + 3] == 115) {
                        if (source.data[start + 4] == 101) return TokenKind.KwFalse;
                    }
                }
            }
        }
    }
    if (length == 6) {
        if (source.data[start] == 109) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 100) {
                    if (source.data[start + 3] == 117) {
                        if (source.data[start + 4] == 108) {
                            if (source.data[start + 5] == 101) return TokenKind.KwModule;
                        }
                    }
                }
            }
        }
        if (source.data[start] == 105) {
            if (source.data[start + 1] == 109) {
                if (source.data[start + 2] == 112) {
                    if (source.data[start + 3] == 111) {
                        if (source.data[start + 4] == 114) {
                            if (source.data[start + 5] == 116) return TokenKind.KwImport;
                        }
                    }
                }
            }
        }
        if (source.data[start] == 114) {
            if (source.data[start + 1] == 101) {
                if (source.data[start + 2] == 116) {
                    if (source.data[start + 3] == 117) {
                        if (source.data[start + 4] == 114) {
                            if (source.data[start + 5] == 110) return TokenKind.KwReturn;
                        }
                    }
                }
            }
        }
        if (source.data[start] == 115) {
            if (source.data[start + 1] == 116) {
                if (source.data[start + 2] == 114) {
                    if (source.data[start + 3] == 117) {
                        if (source.data[start + 4] == 99) {
                            if (source.data[start + 5] == 116) return TokenKind.KwStruct;
                        }
                    }
                    if (source.data[start + 3] == 105) {
                        if (source.data[start + 4] == 110) {
                            if (source.data[start + 5] == 103) return TokenKind.KwString;
                        }
                    }
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 120) {
                if (source.data[start + 2] == 116) {
                    if (source.data[start + 3] == 101) {
                        if (source.data[start + 4] == 114) {
                            if (source.data[start + 5] == 110) return TokenKind.KwExtern;
                        }
                    }
                }
            }
        }
        if (source.data[start] == 115) {
            if (source.data[start + 1] == 105) {
                if (source.data[start + 2] == 122) {
                    if (source.data[start + 3] == 101) {
                        if (source.data[start + 4] == 111) {
                            if (source.data[start + 5] == 102) return TokenKind.KwSizeof;
                        }
                    }
                }
            }
        }
    }
    if (length == 8) {
        if (source.data[start] == 99) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 110) {
                    if (source.data[start + 3] == 116) {
                        if (source.data[start + 4] == 105) {
                            if (source.data[start + 5] == 110) {
                                if (source.data[start + 6] == 117) {
                                    if (source.data[start + 7] == 101) return TokenKind.KwContinue;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return TokenKind.Identifier;
}

fn punctuationKind(value: u8): TokenKind => when (value) {
    40 -> TokenKind.LeftParen;
    41 -> TokenKind.RightParen;
    123 -> TokenKind.LeftBrace;
    125 -> TokenKind.RightBrace;
    91 -> TokenKind.LeftBracket;
    93 -> TokenKind.RightBracket;
    44 -> TokenKind.Comma;
    58 -> TokenKind.Colon;
    59 -> TokenKind.Semicolon;
    46 -> TokenKind.Dot;
    43 -> TokenKind.Plus;
    45 -> TokenKind.Minus;
    42 -> TokenKind.Star;
    47 -> TokenKind.Slash;
    37 -> TokenKind.Percent;
    61 -> TokenKind.Equal;
    60 -> TokenKind.Less;
    62 -> TokenKind.Greater;
    38 -> TokenKind.Ampersand;
    124 -> TokenKind.Pipe;
    94 -> TokenKind.Caret;
    126 -> TokenKind.Tilde;
    63 -> TokenKind.Question;
    33 -> TokenKind.Bang;
    else -> TokenKind.EndOfFile;
};

fn scanIdentifier(source: Source, start: u64): u64 {
    var offset = start;
    while ((offset < source.length) && isIdentifierContinue(source.data[offset])) offset++;

    return offset;
}

fn scanInteger(source: Source, start: u64): u64 {
    var offset = start;
    while ((offset < source.length) && isDigit(source.data[offset])) offset++;

    return offset;
}

struct NumberScan(end: u64, kind: TokenKind)

fn scanNumber(source: Source, start: u64): NumberScan {
    var offset = scanInteger(source, start);
    var kind = TokenKind.IntegerLiteral;

    if (offset < source.length) {
        if (source.data[offset] == 46) {
            if (offset + 1 < source.length) {
                if (isDigit(source.data[offset + 1])) {
                    kind = TokenKind.FloatLiteral;
                    offset = scanInteger(source, offset + 2);
                }
            }
        }
    }

    if (offset < source.length) {
        var exponentMarker = source.data[offset] == 101;
        if (source.data[offset] == 69) exponentMarker = true;
        if (exponentMarker) {
            kind = TokenKind.FloatLiteral;
            offset++;
            if (offset < source.length) {
                var exponentSign = source.data[offset] == 43;
                if (source.data[offset] == 45) exponentSign = true;
                if (exponentSign) offset++;
            }

            offset = scanInteger(source, offset);
        }
    }

    return NumberScan(offset, kind);
}

fn scanString(source: Source, start: u64): u64 {
    var escaped = false;
    for (i in start..<source.length) {
        val value = source.data[i];
        if (escaped) escaped = false;
        else {
            if (value == 92) escaped = true;
            else if (value == 34) return i + 1;
        }
    }

    return start;
}

fn doublePunctuationKind(first: u8, second: u8): TokenKind {
    if (first == 43 && second == 43) return TokenKind.PlusPlus;
    if (first == 45 && second == 45) return TokenKind.MinusMinus;
    if (second == 61) {
        if (first == 43) return TokenKind.PlusEqual;
        if (first == 45) return TokenKind.MinusEqual;
        if (first == 42) return TokenKind.StarEqual;
        if (first == 47) return TokenKind.SlashEqual;
        if (first == 37) return TokenKind.PercentEqual;
        if (first == 61) return TokenKind.EqualEqual;
        if (first == 33) return TokenKind.BangEqual;
        if (first == 60) return TokenKind.LessEqual;
        if (first == 62) return TokenKind.GreaterEqual;
    }
    if (first == 38 && second == 38) return TokenKind.AndAnd;
    if (first == 124 && second == 124) return TokenKind.OrOr;
    if (first == 45 && second == 62) return TokenKind.Arrow;
    if (first == 61 && second == 62) return TokenKind.FatArrow;
    if (first == 46 && second == 46) return TokenKind.Range;
    return TokenKind.EndOfFile;
}

fn lex(source: Source): LexResult {
    var tokens = List<Token>.new();
    var offset: u64 = 0;
    var failed = false;
    var errorStart: u64 = 0;
    var errorKind: u32 = 0;
    while (offset < source.length) {
        val value = source.data[offset];
        if (isWhitespace(value)) offset++;
        else {
            val start = offset;
            when {
                value == 47 -> {
					if (offset + 1 < source.length) {
	                    if (source.data[offset + 1] == 47) {
                        offset += 2;
                        while ((offset < source.length) && source.data[offset] != 10) offset++;
	                    if (offset < source.length) offset++;
	                    } else {
	                        val pairKind = doublePunctuationKind(value, source.data[offset + 1]);
                        if (pairKind == TokenKind.EndOfFile) {
	                            offset++;
                            tokens.add(Token(TokenKind.Slash, start, offset));
	                        } else {
	                            offset = offset + 2;
	                            tokens.add(Token(pairKind, start, offset));
	                        }
	                    }
                    } else {
                        offset++;
                        tokens.add(Token(TokenKind.Slash, start, offset));
                    }
                }
                value == 34 -> {
                    val end = scanString(source, offset + 1);
                    if (end == offset + 1) {
                        failed = true;
                        errorStart = start;
                        errorKind = 1;
                    } else {
                        offset = end;
                        tokens.add(Token(TokenKind.StringLiteral, start, offset));
                    }
                }
                isIdentifierStart(value) -> {
                    offset = scanIdentifier(source, offset + 1);
                    tokens.add(Token(keywordKind(source, start, offset), start, offset));
                }
                isDigit(value) -> {
                    val number = scanNumber(source, offset + 1);
                    offset = number.end;
                    tokens.add(Token(number.kind, start, offset));
                }
                else -> {
                	var kind = punctuationKind(value);
                    if (value == 62) {
                        if (offset + 2 < source.length) {
                            if (
                                source.data[offset + 1] == 46 &&
                                source.data[offset + 2] == 46
							) {
                                kind = TokenKind.RangeExclusiveStart;
                                offset = offset + 2;
                                if (offset + 1 < source.length) {
                                    if (source.data[offset + 1] == 60) {
                                        kind = TokenKind.RangeExclusiveBoth;
                                        offset++;
                                    }
                                }
                            }
                        }
                    }
                	if (value == 46) {
                		if (offset + 2 < source.length) {
                			if (source.data[offset + 1] == 46) {
                				if (source.data[offset + 2] == 60) {
                                    kind = TokenKind.RangeExclusive;
                					offset = offset + 2;
                                }
                			}
                		}
                	}
                    if (kind != TokenKind.RangeExclusive &&
                        kind != TokenKind.RangeExclusiveStart &&
                        kind != TokenKind.RangeExclusiveBoth) {
                		if (offset + 1 < source.length) {
                		    val pairKind = doublePunctuationKind(value, source.data[offset + 1]);
                            if (pairKind != TokenKind.EndOfFile) {
                		        kind = pairKind;
                		        offset++;
                		    }
                	    }
                	}
                    if (kind == TokenKind.EndOfFile) {
                        failed = true;
                        errorStart = start;
                        errorKind = 2;
                    } else {
                        offset++;
                        tokens.add(Token(kind, start, offset));
                    }
                }
            }
            if (failed) break;
        }
    }
    var ok = true;
    if (failed) {
        ok = false;
    } else {
        tokens.add(Token(TokenKind.EndOfFile, source.length, source.length));
    }
    return LexResult(tokens, ok, errorStart, errorKind);
}
