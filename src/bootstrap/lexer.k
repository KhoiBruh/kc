module bootstrap.lexer;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;
import bootstrap.containers.StringBuilder;

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

fn isIdentifierContinue(value: u8) => isIdentifierStart(value) || isDigit(value);

fn keywordKind(source: Source, start: u64, end: u64): TokenKind {
    val length = end - start;
    if (length < 2 || length > 8) return TokenKind.IDENTIFIER;
    return when (source.hash(start, end)) {
        5863225 -> TokenKind.AS;
        5863385 -> TokenKind.FN;
        5863476 -> TokenKind.IF;
        5863484 -> TokenKind.IN;
        5863826 -> TokenKind.U8;
        193489808 -> TokenKind.F32;
        193489909 -> TokenKind.F64;
        193491852 -> TokenKind.FOR;
        193493075 -> TokenKind.I32;
        193493176 -> TokenKind.I64;
        193506143 -> TokenKind.U32;
        193506174 -> TokenKind.STR;
        193506244 -> TokenKind.U64;
        193508808 -> TokenKind.VAL;
        193508814 -> TokenKind.VAR;
        6385087377 -> TokenKind.BOOL;
        6385192046 -> TokenKind.ELSE;
        6385194298 -> TokenKind.ENUM;
        6385525056 -> TokenKind.NULL;
        6385737701 -> TokenKind.TRUE;
        6385768901 -> TokenKind.UNIT;
        6385834103 -> TokenKind.WHEN;
        210707980106 -> TokenKind.BREAK;
        210709068620 -> TokenKind.CONST;
        210709885995 -> TokenKind.DEFER;
        210712121072 -> TokenKind.FALSE;
        210732529790 -> TokenKind.WHILE;
        6953488408955 -> TokenKind.EXTERN;
        6953631772544 -> TokenKind.IMPORT;
        6953790261035 -> TokenKind.MODULE;
        6953974653989 -> TokenKind.RETURN;
        6954018731157 -> TokenKind.SIZEOF;
        6954031505834 -> TokenKind.STRUCT;
        7572251799911306 -> TokenKind.CONTINUE;
        else -> TokenKind.IDENTIFIER;
    };
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
    if (second == 61) return when (first) {
        43 -> TokenKind.PLUS_EQUAL;
        45 -> TokenKind.MINUS_EQUAL;
        42 -> TokenKind.STAR_EQUAL;
        47 -> TokenKind.SLASH_EQUAL;
        37 -> TokenKind.PERCENT_EQUAL;
        61 -> TokenKind.EQUAL_EQUAL;
        33 -> TokenKind.BANG_EQUAL;
        60 -> TokenKind.LESS_EQUAL;
        62 -> TokenKind.GREATER_EQUAL;
        else -> TokenKind.EOF;
    };
    if (second == 62) return when (first) {
        45 -> TokenKind.ARROW;
        61 -> TokenKind.FAT_ARROW;
        else -> TokenKind.EOF;
    };
    if (first == second) return when (first) {
        43 -> TokenKind.PLUS_PLUS;
        45 -> TokenKind.MINUS_MINUS;
        38 -> TokenKind.AND_AND;
        124 -> TokenKind.OR_OR;
        46 -> TokenKind.RANGE;
        else -> TokenKind.EOF;
    };
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

    fn isAtEnd(val self) => self.offset >= self.source.length;

    fn peek(val self) =>
        if (self.isAtEnd()) 0 as u8 else self.source.data[self.offset];

    fn peekAhead(val self, distance: u64) =>
        if (self.offset + distance >= self.source.length) 0 as u8
        else self.source.data[self.offset + distance];

    fn scanInteger(var self) {
        while (isDigit(self.peek())) self.offset++;
    }

    fn scanIdentifier(var self) {
        val start = self.offset;
        self.offset++;

        while (isIdentifierContinue(self.peek())) self.offset++;

        val token = Token(
            keywordKind(self.source, start, self.offset),
            start,
            self.offset
        );
        self.tokens.add(token);
    }

    fn scanNumber(var self) {
        val start = self.offset;
        self.offset++;
        self.scanInteger();
        var kind = TokenKind.INTEGER_LITERAL;

        if (self.peek() == 46 && isDigit(self.peekAhead(1))) {
            kind = TokenKind.FLOAT_LITERAL;
            self.offset = self.offset + 2;
            self.scanInteger();
        }

        if (self.peek() == 101 || self.peek() == 69) {
            kind = TokenKind.FLOAT_LITERAL;
            self.offset++;
            if (self.peek() == 43 || self.peek() == 45) self.offset++;
            self.scanInteger();
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
        val next = self.peekAhead(1);

        if (next == 47) {
            self.offset = self.offset + 2;
            while (!self.isAtEnd() && self.peek() != 10) self.offset++;
            if (!self.isAtEnd()) self.offset++;
            return;
        }

        val pairKind = doublePunctuationKind(47, next);
        if (pairKind != TokenKind.EOF) {
            self.offset = self.offset + 2;
            self.tokens.add(Token(pairKind, start, self.offset));
            return;
        }

        self.offset++;
        self.tokens.add(Token(TokenKind.SLASH, start, self.offset));
    }

    fn scanPunctuation(var self, value: u8) {
        val start = self.offset;
        var kind = punctuationKind(value);

        if (value == 62 && self.peekAhead(1) == 46 && self.peekAhead(2) == 46) {
            kind = TokenKind.RANGE_EXCLUSIVE_START;
            self.offset = self.offset + 2;
            if (self.peekAhead(1) == 60) {
                kind = TokenKind.RANGE_EXCLUSIVE_BOTH;
                self.offset++;
            }
        } else if (value == 46 && self.peekAhead(1) == 46 && self.peekAhead(2) == 60) {
            kind = TokenKind.RANGE_EXCLUSIVE;
            self.offset = self.offset + 2;
        } else if (self.peekAhead(1) != 0) {
            val pairKind = doublePunctuationKind(value, self.peekAhead(1));
            if (pairKind != TokenKind.EOF) {
                kind = pairKind;
                self.offset++;
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
        val tokens = self.tokens;
        return LexResult(tokens, ok, errorStart, errorKind);
    }

}

fn lex(source: Source): LexResult {
    var lexer = Lexer(source, List<Token>.new(), 0, false, 0, 0);
    return lexer.lex();
}
