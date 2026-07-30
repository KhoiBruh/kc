module bootstrap.lexer;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;

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

fn keywordKind(source: Source, start: u64, end: u64): u32 {
    val length = end - start;
    if (length == 2) {
        if (matches2(source, start, 102, 110)) return 10;
        if (matches2(source, start, 105, 102)) return 15;
        if (matches2(source, start, 105, 110)) return 18;
        if (matches2(source, start, 117, 56)) return 38;
        if (matches2(source, start, 97, 115)) return 27;
    }
    if (length == 3) {
        if (source.data[start] == 118) {
            if (source.data[start + 1] == 97) {
                if (source.data[start + 2] == 108) return 6;
                if (source.data[start + 2] == 114) return 7;
            }
        }
        if (source.data[start] == 105) {
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return 35;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return 36;
            }
        }
        if (source.data[start] == 117) {
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return 40;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return 41;
            }
        }
        if (source.data[start] == 102) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 114) return 17;
            }
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return 45;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return 46;
            }
        }
    }
    if (length == 4) {
        if (source.data[start] == 119) {
            if (source.data[start + 1] == 104) {
                if (source.data[start + 2] == 101) {
                    if (source.data[start + 3] == 110) return 14;
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 108) {
                if (source.data[start + 2] == 115) {
                    if (source.data[start + 3] == 101) return 16;
                }
            }
        }
        if (source.data[start] == 117) {
            if (source.data[start + 1] == 110) {
                if (source.data[start + 2] == 105) {
                    if (source.data[start + 3] == 116) return 49;
                }
            }
        }
        if (source.data[start] == 98) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 111) {
                    if (source.data[start + 3] == 108) return 32;
                }
            }
        }
        if (source.data[start] == 116) {
            if (source.data[start + 1] == 114) {
                if (source.data[start + 2] == 117) {
                    if (source.data[start + 3] == 101) return 29;
                }
            }
        }
        if (source.data[start] == 110) {
            if (source.data[start + 1] == 117) {
                if (source.data[start + 2] == 108) {
                    if (source.data[start + 3] == 108) return 31;
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 110) {
                if (source.data[start + 2] == 117) {
                    if (source.data[start + 3] == 109) return 24;
                }
            }
        }
    }
    if (length == 5) {
        if (source.data[start] == 99) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 110) {
                    if (source.data[start + 3] == 115) {
                        if (source.data[start + 4] == 116) return 8;
                    }
                }
            }
        }
        if (source.data[start] == 98) {
            if (source.data[start + 1] == 114) {
                if (source.data[start + 2] == 101) {
                    if (source.data[start + 3] == 97) {
                        if (source.data[start + 4] == 107) return 89;
                    }
                }
            }
        }
        if (source.data[start] == 119) {
            if (source.data[start + 1] == 104) {
                if (source.data[start + 2] == 105) {
                    if (source.data[start + 3] == 108) {
                        if (source.data[start + 4] == 101) return 19;
                    }
                }
            }
        }
        if (source.data[start] == 100) {
            if (source.data[start + 1] == 101) {
                if (source.data[start + 2] == 102) {
                    if (source.data[start + 3] == 101) {
                        if (source.data[start + 4] == 114) return 21;
                    }
                }
            }
        }
        if (source.data[start] == 102) {
            if (source.data[start + 1] == 97) {
                if (source.data[start + 2] == 108) {
                    if (source.data[start + 3] == 115) {
                        if (source.data[start + 4] == 101) return 30;
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
                            if (source.data[start + 5] == 101) return 25;
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
                            if (source.data[start + 5] == 116) return 26;
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
                            if (source.data[start + 5] == 110) return 20;
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
                            if (source.data[start + 5] == 116) return 11;
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
                            if (source.data[start + 5] == 110) return 9;
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
                            if (source.data[start + 5] == 102) return 28;
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
                                    if (source.data[start + 7] == 101) return 90;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return 1;
}

fn punctuationKind(value: u8): u32 => when (value) {
    40 -> 50;
    41 -> 51;
    123 -> 52;
    125 -> 53;
    91 -> 54;
    93 -> 55;
    44 -> 56;
    58 -> 57;
    59 -> 58;
    46 -> 59;
    43 -> 60;
    45 -> 61;
    42 -> 62;
    47 -> 63;
    37 -> 64;
    61 -> 65;
    60 -> 66;
    62 -> 67;
    38 -> 68;
    124 -> 69;
    94 -> 70;
    126 -> 71;
    63 -> 72;
    33 -> 73;
    else -> 0;
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

struct NumberScan(end: u64, kind: u32)

fn scanNumber(source: Source, start: u64): NumberScan {
    var offset = scanInteger(source, start);
    var kind: u32 = 2;

    if (offset < source.length) {
        if (source.data[offset] == 46) {
            if (offset + 1 < source.length) {
                if (isDigit(source.data[offset + 1])) {
                    kind = 3;
                    offset = scanInteger(source, offset + 2);
                }
            }
        }
    }

    if (offset < source.length) {
        var exponentMarker = source.data[offset] == 101;
        if (source.data[offset] == 69) exponentMarker = true;
        if (exponentMarker) {
            kind = 3;
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

fn doublePunctuationKind(first: u8, second: u8): u32 {
    if (first == 43 && second == 43) return 91;
    if (first == 45 && second == 45) return 92;
    if (second == 61) {
        if (first == 43) return 74;
        if (first == 45) return 75;
        if (first == 42) return 76;
        if (first == 47) return 77;
        if (first == 37) return 78;
        if (first == 61) return 79;
        if (first == 33) return 80;
        if (first == 60) return 81;
        if (first == 62) return 82;
    }
    if (first == 38 && second == 38) return 83;
    if (first == 124 && second == 124) return 84;
    if (first == 45 && second == 62) return 85;
    if (first == 61 && second == 62) return 86;
    if (first == 46 && second == 46) return 87;
    return 0;
}

fn lex(source: Source): LexResult {
    var tokens = List<Token>.new();
    var offset: u64 = 0;
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
	                        if (pairKind == 0) {
	                            offset++;
	                            tokens.add(Token(63, start, offset));
	                        } else {
	                            offset = offset + 2;
	                            tokens.add(Token(pairKind, start, offset));
	                        }
	                    }
                    } else {
                        offset++;
                        tokens.add(Token(63, start, offset));
                    }
                }
                value == 34 -> {
                    val end = scanString(source, offset + 1);
                    if (end == offset + 1) return LexResult(tokens, false, start, 1);
                    offset = end;
                    tokens.add(Token(5, start, offset));
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
                                kind = 93;
                                offset = offset + 2;
                                if (offset + 1 < source.length) {
                                    if (source.data[offset + 1] == 60) {
                                        kind = 94;
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
                					kind = 88;
                					offset = offset + 2;
                                }
                			}
                		}
                	}
                    if (kind != 88 && kind != 93 && kind != 94) {
                		if (offset + 1 < source.length) {
                		    val pairKind = doublePunctuationKind(value, source.data[offset + 1]);
                		    if (pairKind != 0) {
                		        kind = pairKind;
                		        offset++;
                		    }
                	    }
                	}
                    if (kind == 0) return LexResult(tokens, false, start, 2);
                    offset++;
                    tokens.add(Token(kind, start, offset));
                }
            }
        }
    }

    tokens.add(Token(0, source.length, source.length));
    return LexResult(tokens, true, 0, 0);
}
