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
        if (matches2(source, start, 102, 110)) return TokenKind.FN;
        if (matches2(source, start, 105, 102)) return TokenKind.IF;
        if (matches2(source, start, 105, 110)) return TokenKind.IN;
        if (matches2(source, start, 117, 56)) return TokenKind.U8;
        if (matches2(source, start, 97, 115)) return TokenKind.AS;
    }
    if (length == 3) {
        if (source.data[start] == 118) {
            if (source.data[start + 1] == 97) {
                if (source.data[start + 2] == 108) return TokenKind.VAL;
                if (source.data[start + 2] == 114) return TokenKind.VAR;
            }
        }
        if (source.data[start] == 105) {
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return TokenKind.I32;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return TokenKind.I64;
            }
        }
        if (source.data[start] == 117) {
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return TokenKind.U32;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return TokenKind.U64;
            }
        }
        if (source.data[start] == 102) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 114) return TokenKind.FOR;
            }
            if (source.data[start + 1] == 51) {
                if (source.data[start + 2] == 50) return TokenKind.F32;
            }
            if (source.data[start + 1] == 54) {
                if (source.data[start + 2] == 52) return TokenKind.F64;
            }
        }
        if (source.data[start] == 115) {
            if (source.data[start + 1] == 116) {
                if (source.data[start + 2] == 114) return TokenKind.STR;
            }
        }
    }
    if (length == 4) {
        if (source.data[start] == 119) {
            if (source.data[start + 1] == 104) {
                if (source.data[start + 2] == 101) {
                    if (source.data[start + 3] == 110) return TokenKind.WHEN;
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 108) {
                if (source.data[start + 2] == 115) {
                    if (source.data[start + 3] == 101) return TokenKind.ELSE;
                }
            }
        }
        if (source.data[start] == 117) {
            if (source.data[start + 1] == 110) {
                if (source.data[start + 2] == 105) {
                    if (source.data[start + 3] == 116) return TokenKind.UNIT;
                }
            }
        }
        if (source.data[start] == 98) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 111) {
                    if (source.data[start + 3] == 108) return TokenKind.BOOL;
                }
            }
        }
        if (source.data[start] == 116) {
            if (source.data[start + 1] == 114) {
                if (source.data[start + 2] == 117) {
                    if (source.data[start + 3] == 101) return TokenKind.TRUE;
                }
            }
        }
        if (source.data[start] == 110) {
            if (source.data[start + 1] == 117) {
                if (source.data[start + 2] == 108) {
                    if (source.data[start + 3] == 108) return TokenKind.NULL;
                }
            }
        }
        if (source.data[start] == 101) {
            if (source.data[start + 1] == 110) {
                if (source.data[start + 2] == 117) {
                    if (source.data[start + 3] == 109) return TokenKind.ENUM;
                }
            }
        }
    }
    if (length == 5) {
        if (source.data[start] == 99) {
            if (source.data[start + 1] == 111) {
                if (source.data[start + 2] == 110) {
                    if (source.data[start + 3] == 115) {
                        if (source.data[start + 4] == 116) return TokenKind.CONST;
                    }
                }
            }
        }
        if (source.data[start] == 98) {
            if (source.data[start + 1] == 114) {
                if (source.data[start + 2] == 101) {
                    if (source.data[start + 3] == 97) {
                        if (source.data[start + 4] == 107) return TokenKind.BREAK;
                    }
                }
            }
        }
        if (source.data[start] == 119) {
            if (source.data[start + 1] == 104) {
                if (source.data[start + 2] == 105) {
                    if (source.data[start + 3] == 108) {
                        if (source.data[start + 4] == 101) return TokenKind.WHILE;
                    }
                }
            }
        }
        if (source.data[start] == 100) {
            if (source.data[start + 1] == 101) {
                if (source.data[start + 2] == 102) {
                    if (source.data[start + 3] == 101) {
                        if (source.data[start + 4] == 114) return TokenKind.DEFER;
                    }
                }
            }
        }
        if (source.data[start] == 102) {
            if (source.data[start + 1] == 97) {
                if (source.data[start + 2] == 108) {
                    if (source.data[start + 3] == 115) {
                        if (source.data[start + 4] == 101) return TokenKind.FALSE;
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
                            if (source.data[start + 5] == 101) return TokenKind.MODULE;
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
                            if (source.data[start + 5] == 116) return TokenKind.IMPORT;
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
                            if (source.data[start + 5] == 110) return TokenKind.RETURN;
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
                            if (source.data[start + 5] == 116) return TokenKind.STRUCT;
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
                            if (source.data[start + 5] == 110) return TokenKind.EXTERN;
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
                            if (source.data[start + 5] == 102) return TokenKind.SIZEOF;
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
                                    if (source.data[start + 7] == 101) return TokenKind.CONTINUE;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return TokenKind.IDENTIFIER;
}

fn punctuationKind(value: u8): TokenKind => when (value) {
    40 -> TokenKind.LEFT_PAREN;
    41 -> TokenKind.RIGHT_PAREN;
    123 -> TokenKind.LEFT_BRACE;
    125 -> TokenKind.RIGHT_BRACE;
    91 -> TokenKind.LEFT_BRACKET;
    93 -> TokenKind.RIGHT_BRACKET;
    44 -> TokenKind.COMMA;
    58 -> TokenKind.COLON;
    59 -> TokenKind.SEMICOLON;
    46 -> TokenKind.DOT;
    43 -> TokenKind.PLUS;
    45 -> TokenKind.MINUS;
    42 -> TokenKind.STAR;
    47 -> TokenKind.SLASH;
    37 -> TokenKind.PERCENT;
    61 -> TokenKind.EQUAL;
    60 -> TokenKind.LESS;
    62 -> TokenKind.GREATER;
    38 -> TokenKind.AMPERSAND;
    124 -> TokenKind.PIPE;
    94 -> TokenKind.CARET;
    126 -> TokenKind.TILDE;
    63 -> TokenKind.QUESTION;
    33 -> TokenKind.BANG;
    else -> TokenKind.EOF;
};

fn doublePunctuationKind(first: u8, second: u8): TokenKind {
    if (first == 43 && second == 43) return TokenKind.PLUS_PLUS;
    if (first == 45 && second == 45) return TokenKind.MINUS_MINUS;
    if (second == 61) {
        if (first == 43) return TokenKind.PLUS_EQUAL;
        if (first == 45) return TokenKind.MINUS_EQUAL;
        if (first == 42) return TokenKind.STAR_EQUAL;
        if (first == 47) return TokenKind.SLASH_EQUAL;
        if (first == 37) return TokenKind.PERCENT_EQUAL;
        if (first == 61) return TokenKind.EQUAL_EQUAL;
        if (first == 33) return TokenKind.BANG_EQUAL;
        if (first == 60) return TokenKind.LESS_EQUAL;
        if (first == 62) return TokenKind.GREATER_EQUAL;
    }
    if (first == 38 && second == 38) return TokenKind.AND_AND;
    if (first == 124 && second == 124) return TokenKind.OR_OR;
    if (first == 45 && second == 62) return TokenKind.ARROW;
    if (first == 61 && second == 62) return TokenKind.FAT_ARROW;
    if (first == 46 && second == 46) return TokenKind.RANGE;
    return TokenKind.EOF;
}

struct Lexer(
    source: Source,
    tokens: List<Token>,
    offset: u64,
    failed: bool,
    errorStart: u64,
    errorKind: u32
) {

    fn isAtEnd(val self): bool => self.offset >= self.source.length;

    fn peek(val self): u8 =>
        if (self.isAtEnd()) 0 as u8 else self.source.data[self.offset];

    fn peekAhead(val self, distance: u64): u8 =>
        if (self.offset + distance >= self.source.length) 0 as u8
        else self.source.data[self.offset + distance];

    fn scanInteger(var self) {
        while ((self.offset < self.source.length) && isDigit(self.source.data[self.offset])) {
            self.offset++;
        }
    }

    fn scanIdentifier(var self) {
        val start = self.offset;
        self.offset++;
        while ((self.offset < self.source.length) && isIdentifierContinue(self.source.data[self.offset])) {
            self.offset++;
        }
        self.tokens.add(Token(keywordKind(self.source, start, self.offset), start, self.offset));
    }

    fn scanNumber(var self) {
        val start = self.offset;
        self.offset++;
        self.scanInteger();
        var kind = TokenKind.INTEGER_LITERAL;

        if (self.offset < self.source.length) {
            if (self.source.data[self.offset] == 46) {
                if (self.offset + 1 < self.source.length) {
                    if (isDigit(self.source.data[self.offset + 1])) {
                        kind = TokenKind.FLOAT_LITERAL;
                        self.offset = self.offset + 2;
                        self.scanInteger();
                    }
                }
            }
        }

        if (self.offset < self.source.length) {
            var exponentMarker = self.source.data[self.offset] == 101;
            if (self.source.data[self.offset] == 69) exponentMarker = true;
            if (exponentMarker) {
                kind = TokenKind.FLOAT_LITERAL;
                self.offset++;
                if (self.offset < self.source.length) {
                    var exponentSign = self.source.data[self.offset] == 43;
                    if (self.source.data[self.offset] == 45) exponentSign = true;
                    if (exponentSign) self.offset++;
                }

                self.scanInteger();
            }
        }

        self.tokens.add(Token(kind, start, self.offset));
    }

    fn scanString(var self) {
        val start = self.offset;
        var escaped = false;
        var foundEnd = false;
        for (i in (start + 1)..<self.source.length) {
            val value = self.source.data[i];
            if (escaped) {
                escaped = false;
            } else {
                if (value == 92) {
                    escaped = true;
                } else if (value == 34) {
                    self.offset = i + 1;
                    self.tokens.add(Token(TokenKind.STRING_LITERAL, start, self.offset));
                    foundEnd = true;
                    break;
                }
            }
        }
        if (!foundEnd) {
            self.failed = true;
            self.errorStart = start;
            self.errorKind = 1;
        }
    }

    fn scanSlash(var self) {
        val start = self.offset;
        if (self.offset + 1 < self.source.length) {
            if (self.source.data[self.offset + 1] == 47) {
                self.offset = self.offset + 2;
                while ((self.offset < self.source.length) && self.source.data[self.offset] != 10) self.offset++;
                if (self.offset < self.source.length) self.offset++;
            } else {
                val pairKind = doublePunctuationKind(47, self.source.data[self.offset + 1]);
                if (pairKind == TokenKind.EOF) {
                    self.offset++;
                    self.tokens.add(Token(TokenKind.SLASH, start, self.offset));
                } else {
                    self.offset = self.offset + 2;
                    self.tokens.add(Token(pairKind, start, self.offset));
                }
            }
        } else {
            self.offset++;
            self.tokens.add(Token(TokenKind.SLASH, start, self.offset));
        }
    }

    fn scanPunctuation(var self, value: u8) {
        val start = self.offset;
        var kind = punctuationKind(value);
        if (value == 62) {
            if (self.offset + 2 < self.source.length) {
                if (
                    self.source.data[self.offset + 1] == 46 &&
                    self.source.data[self.offset + 2] == 46
                ) {
                    kind = TokenKind.RANGE_EXCLUSIVE_START;
                    self.offset = self.offset + 2;
                    if (self.offset + 1 < self.source.length) {
                        if (self.source.data[self.offset + 1] == 60) {
                            kind = TokenKind.RANGE_EXCLUSIVE_BOTH;
                            self.offset++;
                        }
                    }
                }
            }
        }
        if (value == 46) {
            if (self.offset + 2 < self.source.length) {
                if (self.source.data[self.offset + 1] == 46) {
                    if (self.source.data[self.offset + 2] == 60) {
                        kind = TokenKind.RANGE_EXCLUSIVE;
                        self.offset = self.offset + 2;
                    }
                }
            }
        }
        if (kind != TokenKind.RANGE_EXCLUSIVE &&
            kind != TokenKind.RANGE_EXCLUSIVE_START &&
            kind != TokenKind.RANGE_EXCLUSIVE_BOTH) {
            if (self.offset + 1 < self.source.length) {
                val pairKind = doublePunctuationKind(value, self.source.data[self.offset + 1]);
                if (pairKind != TokenKind.EOF) {
                    kind = pairKind;
                    self.offset++;
                }
            }
        }
        if (kind == TokenKind.EOF) {
            self.failed = true;
            self.errorStart = start;
            self.errorKind = 2;
        } else {
            self.offset++;
            self.tokens.add(Token(kind, start, self.offset));
        }
    }

    fn scanToken(var self) {
        val value = self.source.data[self.offset];
        if (isWhitespace(value)) {
            self.offset++;
            return;
        }
        when {
            value == 47 -> self.scanSlash();
            value == 34 -> self.scanString();
            isIdentifierStart(value) -> self.scanIdentifier();
            isDigit(value) -> self.scanNumber();
            else -> self.scanPunctuation(value);
        }
    }

    fn lex(var self): LexResult {
        while (self.offset < self.source.length) {
            self.scanToken();
            if (self.failed) break;
        }
        var ok = true;
        if (self.failed) {
            ok = false;
        } else {
            self.tokens.add(Token(TokenKind.EOF, self.source.length, self.source.length));
        }
        val errorStart = self.errorStart;
        val errorKind = self.errorKind;
        return LexResult(self.tokens, ok, errorStart, errorKind);
    }
}

fn lex(source: Source): LexResult {
    var lexer = Lexer(source, List<Token>.new(), 0, false, 0, 0);
    return lexer.lex();
}
