#pragma once

#include "lang/Source.h"

#include <string>
#include <string_view>

namespace k {

enum class TokenKind {
    EndOfFile,
    Identifier,
    IntegerLiteral,
    FloatLiteral,
    CharLiteral,
    StringLiteral,

    KwVal, KwVar, KwConst, KwExtern, KwFn, KwStruct, KwTrait, KwOverride,
    KwWhen, KwIf, KwElse, KwFor, KwIn, KwWhile, KwReturn, KwDefer,
    KwFault, KwModule, KwImport, KwEnum, KwCatch, KwAs, KwSizeof,
    KwTrue, KwFalse, KwNull,
    KwBool, KwI8, KwI16, KwI32, KwI64, KwI128,
    KwU8, KwU16, KwU32, KwU64, KwU128,
    KwF8, KwF16, KwF32, KwF64, KwChar, KwString, KwUnit,

    LeftParen, RightParen,
    LeftBrace, RightBrace,
    LeftBracket, RightBracket,
    Comma, Colon, Semicolon, Dot,
    Plus, Minus, Star, Slash, Percent,
    Equal, Less, Greater, Ampersand, Pipe, Caret, Tilde,
    Question, Bang,
    PlusEqual, MinusEqual, StarEqual, SlashEqual, PercentEqual,
    EqualEqual, BangEqual, LessEqual, GreaterEqual,
    AndAnd, OrOr,
    Arrow, FatArrow, Range, RangeExclusive
};

struct Token {
    TokenKind kind;
    SourceSpan span;

    [[nodiscard]] std::string_view lexeme(const Source& source) const;
};

[[nodiscard]] std::string_view tokenKindName(TokenKind kind) noexcept;
[[nodiscard]] std::string escapeLexeme(std::string_view text);

}
