#include "lang/Lexer.h"

#include <array>
#include <cctype>
#include <cstdint>
#include <string_view>
#include <utility>

namespace k {

namespace {

using Spelling = std::pair<std::string_view, TokenKind>;

constexpr std::array keywords{
    Spelling{"val", TokenKind::KwVal}, Spelling{"var", TokenKind::KwVar},
    Spelling{"const", TokenKind::KwConst},
    Spelling{"extern", TokenKind::KwExtern}, Spelling{"fn", TokenKind::KwFn},
    Spelling{"struct", TokenKind::KwStruct}, Spelling{"trait", TokenKind::KwTrait},
    Spelling{"override", TokenKind::KwOverride}, Spelling{"when", TokenKind::KwWhen},
    Spelling{"if", TokenKind::KwIf}, Spelling{"else", TokenKind::KwElse},
    Spelling{"for", TokenKind::KwFor},
    Spelling{"in", TokenKind::KwIn}, Spelling{"while", TokenKind::KwWhile},
    Spelling{"return", TokenKind::KwReturn}, Spelling{"defer", TokenKind::KwDefer},
    Spelling{"fault", TokenKind::KwFault}, Spelling{"module", TokenKind::KwModule},
    Spelling{"import", TokenKind::KwImport}, Spelling{"enum", TokenKind::KwEnum},
    Spelling{"catch", TokenKind::KwCatch}, Spelling{"as", TokenKind::KwAs},
    Spelling{"sizeof", TokenKind::KwSizeof},
    Spelling{"true", TokenKind::KwTrue},
    Spelling{"false", TokenKind::KwFalse}, Spelling{"null", TokenKind::KwNull},
    Spelling{"bool", TokenKind::KwBool}, Spelling{"i8", TokenKind::KwI8},
    Spelling{"i16", TokenKind::KwI16}, Spelling{"i32", TokenKind::KwI32},
    Spelling{"i64", TokenKind::KwI64}, Spelling{"i128", TokenKind::KwI128},
    Spelling{"u8", TokenKind::KwU8}, Spelling{"u16", TokenKind::KwU16},
    Spelling{"u32", TokenKind::KwU32}, Spelling{"u64", TokenKind::KwU64},
    Spelling{"u128", TokenKind::KwU128}, Spelling{"f8", TokenKind::KwF8},
    Spelling{"f16", TokenKind::KwF16}, Spelling{"f32", TokenKind::KwF32},
    Spelling{"f64", TokenKind::KwF64}, Spelling{"char", TokenKind::KwChar},
    Spelling{"string", TokenKind::KwString}, Spelling{"unit", TokenKind::KwUnit},
    Spelling{"break", TokenKind::KwBreak},
    Spelling{"continue", TokenKind::KwContinue},
};

constexpr std::array operators{
    Spelling{"..<", TokenKind::RangeExclusive},
    Spelling{"++", TokenKind::PlusPlus}, Spelling{"--", TokenKind::MinusMinus},
    Spelling{"->", TokenKind::Arrow}, Spelling{"=>", TokenKind::FatArrow},
    Spelling{"..", TokenKind::Range}, Spelling{"+=", TokenKind::PlusEqual},
    Spelling{"-=", TokenKind::MinusEqual}, Spelling{"*=", TokenKind::StarEqual},
    Spelling{"/=", TokenKind::SlashEqual}, Spelling{"%=", TokenKind::PercentEqual},
    Spelling{"==", TokenKind::EqualEqual}, Spelling{"!=", TokenKind::BangEqual},
    Spelling{"<=", TokenKind::LessEqual}, Spelling{">=", TokenKind::GreaterEqual},
    Spelling{"&&", TokenKind::AndAnd}, Spelling{"||", TokenKind::OrOr},
    Spelling{"(", TokenKind::LeftParen}, Spelling{")", TokenKind::RightParen},
    Spelling{"{", TokenKind::LeftBrace}, Spelling{"}", TokenKind::RightBrace},
    Spelling{"[", TokenKind::LeftBracket}, Spelling{"]", TokenKind::RightBracket},
    Spelling{",", TokenKind::Comma}, Spelling{":", TokenKind::Colon},
    Spelling{";", TokenKind::Semicolon}, Spelling{".", TokenKind::Dot},
    Spelling{"+", TokenKind::Plus}, Spelling{"-", TokenKind::Minus},
    Spelling{"*", TokenKind::Star}, Spelling{"/", TokenKind::Slash},
    Spelling{"%", TokenKind::Percent}, Spelling{"=", TokenKind::Equal},
    Spelling{"<", TokenKind::Less}, Spelling{">", TokenKind::Greater},
    Spelling{"&", TokenKind::Ampersand}, Spelling{"|", TokenKind::Pipe},
    Spelling{"^", TokenKind::Caret}, Spelling{"~", TokenKind::Tilde},
    Spelling{"?", TokenKind::Question}, Spelling{"!", TokenKind::Bang},
};

bool isAsciiIdentifierStart(unsigned char byte) noexcept {
    return byte == '_' || (byte >= 'a' && byte <= 'z') || (byte >= 'A' && byte <= 'Z');
}

bool isAsciiDigit(unsigned char byte) noexcept {
    return byte >= '0' && byte <= '9';
}

bool isDigitForBase(unsigned char byte, int base) noexcept {
    if (byte >= '0' && byte <= '9') {
        return byte - '0' < base;
    }
    if (base == 16 && byte >= 'a' && byte <= 'f') {
        return true;
    }
    return base == 16 && byte >= 'A' && byte <= 'F';
}

int hexValue(char value) noexcept {
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    if (value >= 'A' && value <= 'F') return value - 'A' + 10;
    return -1;
}

}

Lexer::Lexer(const Source& source) : source_(source) {}

bool Lexer::atEnd() const noexcept {
    return offset_ >= source_.text().size();
}

char Lexer::current() const noexcept {
    return atEnd() ? '\0' : source_.text()[offset_];
}

bool Lexer::startsWith(std::string_view spelling) const noexcept {
    return source_.text().substr(offset_, spelling.size()) == spelling;
}

void Lexer::skipTrivia(LexResult& result) {
    while (!atEnd()) {
        const auto byte = static_cast<unsigned char>(current());
        if (byte == ' ' || byte == '\t' || byte == '\r' || byte == '\n') {
            ++offset_;
            continue;
        }
        if (startsWith("//")) {
            offset_ += 2;
            while (!atEnd() && current() != '\n') {
                ++offset_;
            }
            continue;
        }
        if (startsWith("/*")) {
            const auto start = offset_;
            offset_ += 2;
            std::size_t depth = 1;
            while (!atEnd() && depth != 0) {
                if (startsWith("/*")) {
                    ++depth;
                    offset_ += 2;
                } else if (startsWith("*/")) {
                    --depth;
                    offset_ += 2;
                } else {
                    ++offset_;
                }
            }
            if (depth != 0) {
                result.error = Diagnostic{"unterminated block comment", {start, start + 2}};
                return;
            }
            continue;
        }
        return;
    }
}

void Lexer::lexIdentifier(LexResult& result) {
    const auto start = offset_;
    while (!atEnd()) {
        const auto byte = static_cast<unsigned char>(current());
        if (isAsciiIdentifierStart(byte) || isAsciiDigit(byte)) {
            ++offset_;
        } else if (byte >= 0x80u) {
            offset_ += utf8ScalarLength(source_.text(), offset_);
        } else {
            break;
        }
    }

    const auto spelling = source_.text().substr(start, offset_ - start);
    auto kind = TokenKind::Identifier;
    for (const auto& [keyword, keywordKind] : keywords) {
        if (spelling == keyword) {
            kind = keywordKind;
            break;
        }
    }
    result.tokens.push_back({kind, {start, offset_}});
}

void Lexer::lexNumber(LexResult& result) {
    const auto start = offset_;
    const auto text = source_.text();
    auto fail = [&] {
        result.error = Diagnostic{"malformed numeric literal", {start, offset_}};
    };

    if (current() == '0' && offset_ + 1 < text.size()) {
        const auto prefix = text[offset_ + 1];
        int base = 0;
        if (prefix == 'b' || prefix == 'B') base = 2;
        if (prefix == 'o' || prefix == 'O') base = 8;
        if (prefix == 'x' || prefix == 'X') base = 16;
        if (base != 0) {
            offset_ += 2;
            bool hasDigit = false;
            bool previousUnderscore = false;
            bool invalid = false;
            while (!atEnd()) {
                const auto byte = static_cast<unsigned char>(current());
                if (byte == '_') {
                    invalid = invalid || !hasDigit || previousUnderscore;
                    previousUnderscore = true;
                    ++offset_;
                } else if (std::isalnum(byte) != 0) {
                    invalid = invalid || !isDigitForBase(byte, base);
                    hasDigit = hasDigit || isDigitForBase(byte, base);
                    previousUnderscore = false;
                    ++offset_;
                } else {
                    break;
                }
            }
            if (!hasDigit || previousUnderscore || invalid) {
                fail();
                return;
            }
            result.tokens.push_back({TokenKind::IntegerLiteral, {start, offset_}});
            return;
        }
    }

    bool previousUnderscore = false;
    bool invalid = false;
    while (!atEnd() && (isAsciiDigit(static_cast<unsigned char>(current())) || current() == '_')) {
        if (current() == '_') {
            invalid = invalid || previousUnderscore;
            previousUnderscore = true;
        } else {
            previousUnderscore = false;
        }
        ++offset_;
    }
    invalid = invalid || previousUnderscore;

    bool isFloat = false;
    if (!atEnd() && current() == '.' && !startsWith("..")) {
        if (offset_ + 1 < text.size() && text[offset_ + 1] == '_') {
            offset_ += 2;
            fail();
            return;
        }
        if (offset_ + 1 < text.size() && isAsciiDigit(static_cast<unsigned char>(text[offset_ + 1]))) {
            isFloat = true;
            ++offset_;
            previousUnderscore = false;
            while (!atEnd() && (isAsciiDigit(static_cast<unsigned char>(current())) || current() == '_')) {
                if (current() == '_') {
                    invalid = invalid || previousUnderscore;
                    previousUnderscore = true;
                } else {
                    previousUnderscore = false;
                }
                ++offset_;
            }
            invalid = invalid || previousUnderscore;
        }
    }

    if (!atEnd() && (current() == 'e' || current() == 'E')) {
        isFloat = true;
        ++offset_;
        if (!atEnd() && (current() == '+' || current() == '-')) {
            ++offset_;
        }
        const auto exponentStart = offset_;
        previousUnderscore = false;
        while (!atEnd() && (isAsciiDigit(static_cast<unsigned char>(current())) || current() == '_')) {
            if (current() == '_') {
                invalid = invalid || offset_ == exponentStart || previousUnderscore;
                previousUnderscore = true;
            } else {
                previousUnderscore = false;
            }
            ++offset_;
        }
        invalid = invalid || offset_ == exponentStart || previousUnderscore;
    }

    if (invalid) {
        fail();
        return;
    }
    result.tokens.push_back({isFloat ? TokenKind::FloatLiteral : TokenKind::IntegerLiteral,
                             {start, offset_}});
}

void Lexer::lexQuoted(LexResult& result) {
    const auto start = offset_;
    const auto quote = current();
    const bool isChar = quote == '\'';
    ++offset_;
    std::size_t scalarCount = 0;

    auto fail = [&](std::string message) {
        result.error = Diagnostic{std::move(message), {start, offset_}};
    };

    while (!atEnd() && current() != quote) {
        if (current() == '\n' || current() == '\r') {
            fail(isChar ? "unterminated char literal" : "unterminated string literal");
            return;
        }

        if (current() == '\\') {
            ++offset_;
            if (atEnd()) {
                fail(isChar ? "unterminated char literal" : "unterminated string literal");
                return;
            }
            const auto escaped = current();
            if (escaped == 'n' || escaped == 'r' || escaped == 't' || escaped == '0' ||
                escaped == '\\' || escaped == '\"' || escaped == '\'' || escaped == '$') {
                ++offset_;
                ++scalarCount;
                continue;
            }
            if (escaped != 'u') {
                ++offset_;
                fail("invalid escape sequence");
                return;
            }

            ++offset_;
            if (atEnd() || current() != '{') {
                fail("invalid Unicode escape");
                return;
            }
            ++offset_;
            std::size_t digits = 0;
            std::uint32_t codePoint = 0;
            while (!atEnd() && current() != '}') {
                const auto digit = hexValue(current());
                if (digit < 0 || digits == 6) {
                    fail("invalid Unicode escape");
                    return;
                }
                codePoint = codePoint * 16u + static_cast<std::uint32_t>(digit);
                ++digits;
                ++offset_;
            }
            if (atEnd() || digits == 0) {
                fail("invalid Unicode escape");
                return;
            }
            ++offset_;
            if (codePoint > 0x10FFFFu || (codePoint >= 0xD800u && codePoint <= 0xDFFFu)) {
                fail("invalid Unicode scalar value");
                return;
            }
            ++scalarCount;
            continue;
        }

        const auto length = utf8ScalarLength(source_.text(), offset_);
        offset_ += length;
        ++scalarCount;
    }

    if (atEnd()) {
        fail(isChar ? "unterminated char literal" : "unterminated string literal");
        return;
    }
    ++offset_;
    if (isChar && scalarCount != 1) {
        fail("char literal must contain exactly one Unicode scalar");
        return;
    }
    result.tokens.push_back({isChar ? TokenKind::CharLiteral : TokenKind::StringLiteral,
                             {start, offset_}});
}

bool Lexer::lexOperator(LexResult& result) {
    for (const auto& [spelling, kind] : operators) {
        if (startsWith(spelling)) {
            const auto start = offset_;
            offset_ += spelling.size();
            result.tokens.push_back({kind, {start, offset_}});
            return true;
        }
    }
    return false;
}

LexResult Lexer::lexAll() {
    LexResult result;
    if (!source_.isValidUtf8()) {
        const auto offset = source_.invalidUtf8Offset();
        result.error = Diagnostic{"malformed UTF-8", {offset, offset + 1}};
        return result;
    }

    while (true) {
        skipTrivia(result);
        if (result.error.has_value()) {
            return result;
        }
        if (atEnd()) {
            result.tokens.push_back({TokenKind::EndOfFile, {offset_, offset_}});
            return result;
        }

        const auto byte = static_cast<unsigned char>(current());
        if (isAsciiIdentifierStart(byte) || byte >= 0x80u) {
            lexIdentifier(result);
            continue;
        }
        if (isAsciiDigit(byte)) {
            lexNumber(result);
            if (result.error.has_value()) {
                return result;
            }
            continue;
        }
        if (current() == '\'' || current() == '\"') {
            lexQuoted(result);
            if (result.error.has_value()) {
                return result;
            }
            continue;
        }
        if (lexOperator(result)) {
            continue;
        }

        result.error = Diagnostic{"unexpected character", {offset_, offset_ + 1}};
        return result;
    }
}

}
