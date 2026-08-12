module bootstrap.token;

enum TokenKind {
    EndOfFile,
    Identifier,
    IntegerLiteral,
    FloatLiteral,
    CharLiteral,
    StringLiteral,
    KwVal,
    KwVar,
    KwConst,
    KwExtern,
    KwFn,
    KwStruct,
    KwTrait,
    KwOverride,
    KwWhen,
    KwIf,
    KwElse,
    KwFor,
    KwIn,
    KwWhile,
    KwReturn,
    KwDefer,
    KwFault,
    KwModule,
    KwImport,
    KwEnum,
    KwCatch,
    KwAs,
    KwSizeof,
    KwTrue,
    KwFalse,
    KwNull,
    KwBool,
    KwI8,
    KwI16,
    KwI32,
    KwI64,
    KwI128,
    KwU8,
    KwU16,
    KwU32,
    KwU64,
    KwU128,
    KwF8,
    KwF16,
    KwF32,
    KwF64,
    KwChar,
    KwString,
    KwUnit,
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Comma,
    Colon,
    Semicolon,
    Dot,
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Equal,
    Less,
    Greater,
    Ampersand,
    Pipe,
    Caret,
    Tilde,
    Question,
    Bang,
    PlusEqual,
    MinusEqual,
    StarEqual,
    SlashEqual,
    PercentEqual,
    EqualEqual,
    BangEqual,
    LessEqual,
    GreaterEqual,
    AndAnd,
    OrOr,
    Arrow,
    FatArrow,
    Range,
    RangeExclusive,
    KwBreak,
    KwContinue,
    PlusPlus,
    MinusMinus,
    RangeExclusiveStart,
    RangeExclusiveBoth
}

fn tokenKindValue(kind: TokenKind): u32 => when (kind) {
    TokenKind.EndOfFile -> 0;
    TokenKind.Identifier -> 1;
    TokenKind.IntegerLiteral -> 2;
    TokenKind.FloatLiteral -> 3;
    TokenKind.CharLiteral -> 4;
    TokenKind.StringLiteral -> 5;
    TokenKind.KwVal -> 6;
    TokenKind.KwVar -> 7;
    TokenKind.KwConst -> 8;
    TokenKind.KwExtern -> 9;
    TokenKind.KwFn -> 10;
    TokenKind.KwStruct -> 11;
    TokenKind.KwTrait -> 12;
    TokenKind.KwOverride -> 13;
    TokenKind.KwWhen -> 14;
    TokenKind.KwIf -> 15;
    TokenKind.KwElse -> 16;
    TokenKind.KwFor -> 17;
    TokenKind.KwIn -> 18;
    TokenKind.KwWhile -> 19;
    TokenKind.KwReturn -> 20;
    TokenKind.KwDefer -> 21;
    TokenKind.KwFault -> 22;
    TokenKind.KwModule -> 23;
    TokenKind.KwImport -> 24;
    TokenKind.KwEnum -> 25;
    TokenKind.KwCatch -> 26;
    TokenKind.KwAs -> 27;
    TokenKind.KwSizeof -> 28;
    TokenKind.KwTrue -> 29;
    TokenKind.KwFalse -> 30;
    TokenKind.KwNull -> 31;
    TokenKind.KwBool -> 32;
    TokenKind.KwI8 -> 33;
    TokenKind.KwI16 -> 34;
    TokenKind.KwI32 -> 35;
    TokenKind.KwI64 -> 36;
    TokenKind.KwI128 -> 37;
    TokenKind.KwU8 -> 38;
    TokenKind.KwU16 -> 39;
    TokenKind.KwU32 -> 40;
    TokenKind.KwU64 -> 41;
    TokenKind.KwU128 -> 42;
    TokenKind.KwF8 -> 43;
    TokenKind.KwF16 -> 44;
    TokenKind.KwF32 -> 45;
    TokenKind.KwF64 -> 46;
    TokenKind.KwChar -> 47;
    TokenKind.KwString -> 48;
    TokenKind.KwUnit -> 49;
    TokenKind.LeftParen -> 50;
    TokenKind.RightParen -> 51;
    TokenKind.LeftBrace -> 52;
    TokenKind.RightBrace -> 53;
    TokenKind.LeftBracket -> 54;
    TokenKind.RightBracket -> 55;
    TokenKind.Comma -> 56;
    TokenKind.Colon -> 57;
    TokenKind.Semicolon -> 58;
    TokenKind.Dot -> 59;
    TokenKind.Plus -> 60;
    TokenKind.Minus -> 61;
    TokenKind.Star -> 62;
    TokenKind.Slash -> 63;
    TokenKind.Percent -> 64;
    TokenKind.Equal -> 65;
    TokenKind.Less -> 66;
    TokenKind.Greater -> 67;
    TokenKind.Ampersand -> 68;
    TokenKind.Pipe -> 69;
    TokenKind.Caret -> 70;
    TokenKind.Tilde -> 71;
    TokenKind.Question -> 72;
    TokenKind.Bang -> 73;
    TokenKind.PlusEqual -> 74;
    TokenKind.MinusEqual -> 75;
    TokenKind.StarEqual -> 76;
    TokenKind.SlashEqual -> 77;
    TokenKind.PercentEqual -> 78;
    TokenKind.EqualEqual -> 79;
    TokenKind.BangEqual -> 80;
    TokenKind.LessEqual -> 81;
    TokenKind.GreaterEqual -> 82;
    TokenKind.AndAnd -> 83;
    TokenKind.OrOr -> 84;
    TokenKind.Arrow -> 85;
    TokenKind.FatArrow -> 86;
    TokenKind.Range -> 87;
    TokenKind.RangeExclusive -> 88;
    TokenKind.KwBreak -> 89;
    TokenKind.KwContinue -> 90;
    TokenKind.PlusPlus -> 91;
    TokenKind.MinusMinus -> 92;
    TokenKind.RangeExclusiveStart -> 93;
    TokenKind.RangeExclusiveBoth -> 94;
};

struct Token(kind: TokenKind, start: u64, end: u64)
