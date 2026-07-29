#include "lang/Token.h"

#include <algorithm>
#include <array>
#include <cstdio>

namespace k {

std::string_view Token::lexeme(const Source& source) const {
    const auto text = source.text();
    const auto start = std::min(span.start, text.size());
    const auto end = std::min(std::max(span.end, start), text.size());
    return text.substr(start, end - start);
}

std::string_view tokenKindName(TokenKind kind) noexcept {
#define K_TOKEN_NAME(name) case TokenKind::name: return #name
    switch (kind) {
        K_TOKEN_NAME(EndOfFile); K_TOKEN_NAME(Identifier);
        K_TOKEN_NAME(IntegerLiteral); K_TOKEN_NAME(FloatLiteral);
        K_TOKEN_NAME(CharLiteral); K_TOKEN_NAME(StringLiteral);
        K_TOKEN_NAME(KwVal); K_TOKEN_NAME(KwVar); K_TOKEN_NAME(KwConst);
        K_TOKEN_NAME(KwExtern); K_TOKEN_NAME(KwFn); K_TOKEN_NAME(KwStruct);
        K_TOKEN_NAME(KwTrait);
        K_TOKEN_NAME(KwOverride); K_TOKEN_NAME(KwWhen); K_TOKEN_NAME(KwIf);
        K_TOKEN_NAME(KwElse);
        K_TOKEN_NAME(KwFor); K_TOKEN_NAME(KwIn); K_TOKEN_NAME(KwWhile);
        K_TOKEN_NAME(KwReturn); K_TOKEN_NAME(KwDefer); K_TOKEN_NAME(KwFault);
        K_TOKEN_NAME(KwModule); K_TOKEN_NAME(KwImport); K_TOKEN_NAME(KwEnum);
        K_TOKEN_NAME(KwCatch); K_TOKEN_NAME(KwAs); K_TOKEN_NAME(KwSizeof);
        K_TOKEN_NAME(KwTrue); K_TOKEN_NAME(KwFalse);
        K_TOKEN_NAME(KwNull); K_TOKEN_NAME(KwBool); K_TOKEN_NAME(KwI8);
        K_TOKEN_NAME(KwI16); K_TOKEN_NAME(KwI32); K_TOKEN_NAME(KwI64);
        K_TOKEN_NAME(KwI128); K_TOKEN_NAME(KwU8); K_TOKEN_NAME(KwU16);
        K_TOKEN_NAME(KwU32); K_TOKEN_NAME(KwU64); K_TOKEN_NAME(KwU128);
        K_TOKEN_NAME(KwF8); K_TOKEN_NAME(KwF16); K_TOKEN_NAME(KwF32);
        K_TOKEN_NAME(KwF64); K_TOKEN_NAME(KwChar); K_TOKEN_NAME(KwString);
        K_TOKEN_NAME(KwUnit); K_TOKEN_NAME(LeftParen); K_TOKEN_NAME(RightParen);
        K_TOKEN_NAME(LeftBrace); K_TOKEN_NAME(RightBrace);
        K_TOKEN_NAME(LeftBracket); K_TOKEN_NAME(RightBracket);
        K_TOKEN_NAME(Comma); K_TOKEN_NAME(Colon); K_TOKEN_NAME(Semicolon);
        K_TOKEN_NAME(Dot); K_TOKEN_NAME(Plus); K_TOKEN_NAME(Minus);
        K_TOKEN_NAME(Star); K_TOKEN_NAME(Slash); K_TOKEN_NAME(Percent);
        K_TOKEN_NAME(Equal); K_TOKEN_NAME(Less); K_TOKEN_NAME(Greater);
        K_TOKEN_NAME(Ampersand); K_TOKEN_NAME(Pipe); K_TOKEN_NAME(Caret);
        K_TOKEN_NAME(Tilde); K_TOKEN_NAME(Question); K_TOKEN_NAME(Bang);
        K_TOKEN_NAME(PlusEqual); K_TOKEN_NAME(MinusEqual);
        K_TOKEN_NAME(StarEqual); K_TOKEN_NAME(SlashEqual);
        K_TOKEN_NAME(PercentEqual); K_TOKEN_NAME(EqualEqual);
        K_TOKEN_NAME(BangEqual); K_TOKEN_NAME(LessEqual);
        K_TOKEN_NAME(GreaterEqual); K_TOKEN_NAME(AndAnd); K_TOKEN_NAME(OrOr);
        K_TOKEN_NAME(Arrow); K_TOKEN_NAME(FatArrow); K_TOKEN_NAME(Range);
        K_TOKEN_NAME(RangeExclusive); K_TOKEN_NAME(KwBreak);
        K_TOKEN_NAME(KwContinue); K_TOKEN_NAME(PlusPlus);
        K_TOKEN_NAME(MinusMinus); K_TOKEN_NAME(RangeExclusiveStart);
        K_TOKEN_NAME(RangeExclusiveBoth);
    }
#undef K_TOKEN_NAME
    return "Unknown";
}

std::string escapeLexeme(std::string_view text) {
    std::string result;
    for (const auto value : text) {
        const auto byte = static_cast<unsigned char>(value);
        switch (value) {
        case '\n': result += "\\n"; break;
        case '\r': result += "\\r"; break;
        case '\t': result += "\\t"; break;
        case '\\': result += "\\\\"; break;
        case '\"': result += "\\\""; break;
        default:
            if (byte < 0x20u || byte == 0x7Fu) {
                std::array<char, 5> buffer{};
                std::snprintf(buffer.data(), buffer.size(), "\\x%02X", byte);
                result += buffer.data();
            } else {
                result.push_back(value);
            }
            break;
        }
    }
    return result;
}

}
