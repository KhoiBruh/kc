#include "TestHarness.h"
#include "lang/Diagnostic.h"
#include "lang/Lexer.h"
#include "lang/Source.h"
#include "lang/Token.h"

#include <vector>

namespace {

std::vector<k::TokenKind> kindsOf(const k::LexResult& result) {
    std::vector<k::TokenKind> kinds;
    for (const auto& token : result.tokens) {
        kinds.push_back(token.kind);
    }
    return kinds;
}

}

TEST(source_keeps_its_name) {
    k::Source source{"sample.k", "val answer = 42"};
    EXPECT_EQ(source.path(), "sample.k");
}

TEST(source_reports_unicode_columns) {
    k::Source source{"sample.k", "val tiếng = 1\r\nreturn tiếng"};
    EXPECT_TRUE(source.isValidUtf8());
    const auto offset = source.text().find("tiếng", source.text().find("return"));
    const auto position = source.positionAt(offset);
    EXPECT_EQ(position.line, 2u);
    EXPECT_EQ(position.column, 8u);
}

TEST(source_rejects_malformed_utf8) {
    k::Source source{"bad.k", std::string{"\xC3\x28", 2}};
    EXPECT_TRUE(!source.isValidUtf8());
    EXPECT_EQ(source.invalidUtf8Offset(), 0u);
}

TEST(token_exposes_kind_name_and_lexeme) {
    k::Source source{"sample.k", "->"};
    const k::Token token{k::TokenKind::Arrow, {0, 2}};
    EXPECT_EQ(k::tokenKindName(token.kind), "Arrow");
    EXPECT_EQ(token.lexeme(source), "->");
}

TEST(token_lexeme_display_is_single_line) {
    EXPECT_EQ(k::escapeLexeme("a\n\tb\\c"), "a\\n\\tb\\\\c");
}

TEST(diagnostic_includes_source_position) {
    k::Source source{"sample.k", "val x ="};
    const k::Diagnostic diagnostic{"unexpected character", {6, 7}};
    EXPECT_EQ(
        k::formatDiagnostic(source, diagnostic),
        "sample.k:1:7: error: unexpected character");
}

TEST(lexer_skips_comments_and_recognizes_identifiers) {
    k::Source source{
        "sample.k",
        "val answer // line\n/* outer /* inner */ end */ var tiếng"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(!result.error.has_value());
    EXPECT_EQ(
        kindsOf(result),
        (std::vector<k::TokenKind>{
            k::TokenKind::KwVal,
            k::TokenKind::Identifier,
            k::TokenKind::KwVar,
            k::TokenKind::Identifier,
            k::TokenKind::EndOfFile}));
}

TEST(lexer_prefers_longest_operator) {
    k::Source source{"sample.k", "-> => .. ..< += == != <= >= && ||"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_EQ(
        kindsOf(result),
        (std::vector<k::TokenKind>{
            k::TokenKind::Arrow, k::TokenKind::FatArrow,
            k::TokenKind::Range, k::TokenKind::RangeExclusive,
            k::TokenKind::PlusEqual, k::TokenKind::EqualEqual,
            k::TokenKind::BangEqual, k::TokenKind::LessEqual,
            k::TokenKind::GreaterEqual, k::TokenKind::AndAnd,
            k::TokenKind::OrOr, k::TokenKind::EndOfFile}));
}

TEST(lexer_reports_unterminated_nested_comment) {
    k::Source source{"sample.k", "val x /* outer /* inner */"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(result.error.has_value());
    EXPECT_EQ(result.error->message, "unterminated block comment");
    EXPECT_EQ(result.error->span.start, 6u);
}

TEST(lexer_treats_unit_as_keyword_and_void_as_identifier) {
    k::Source source{"unit.k", "unit void"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(!result.error.has_value());
    EXPECT_EQ(result.tokens[0].kind, k::TokenKind::KwUnit);
    EXPECT_EQ(result.tokens[1].kind, k::TokenKind::Identifier);
}

TEST(lexer_recognizes_numeric_literals) {
    k::Source source{
        "numbers.k",
        "123 1_000_000 0b1010 0o755 0xFF_A0 1.25 1e10 2.5e-3 -10 1..2"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(!result.error.has_value());
    EXPECT_EQ(
        kindsOf(result),
        (std::vector<k::TokenKind>{
            k::TokenKind::IntegerLiteral, k::TokenKind::IntegerLiteral,
            k::TokenKind::IntegerLiteral, k::TokenKind::IntegerLiteral,
            k::TokenKind::IntegerLiteral, k::TokenKind::FloatLiteral,
            k::TokenKind::FloatLiteral, k::TokenKind::FloatLiteral,
            k::TokenKind::Minus, k::TokenKind::IntegerLiteral,
            k::TokenKind::IntegerLiteral, k::TokenKind::Range,
            k::TokenKind::IntegerLiteral, k::TokenKind::EndOfFile}));
}

TEST(lexer_rejects_malformed_numeric_literals) {
    for (const auto spelling : {
             "0b", "0b102", "0o8", "0x", "1__0", "1_", "1._0", "1e", "1e+"}) {
        k::Source source{"bad-number.k", spelling};
        const auto result = k::Lexer{source}.lexAll();
        EXPECT_TRUE(result.error.has_value());
        if (result.error.has_value()) {
            EXPECT_EQ(result.error->message, "malformed numeric literal");
        }
    }
}

TEST(lexer_recognizes_char_and_string_literals) {
    k::Source source{
        "text.k",
        R"K('a' 'ế' '\n' '\u{1F600}' "" "hello $name ${name.get()} \$")K"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(!result.error.has_value());
    EXPECT_EQ(
        kindsOf(result),
        (std::vector<k::TokenKind>{
            k::TokenKind::CharLiteral, k::TokenKind::CharLiteral,
            k::TokenKind::CharLiteral, k::TokenKind::CharLiteral,
            k::TokenKind::StringLiteral, k::TokenKind::StringLiteral,
            k::TokenKind::EndOfFile}));
}

TEST(lexer_rejects_invalid_char_and_string_literals) {
    const std::vector<std::string> spellings{
        "''", "'ab'", R"('\u{D800}')", R"('\u{110000}')",
        R"('\q')", R"('\u{12')", "\"line\nbreak\"", "'a", "\"x"};
    for (const auto& spelling : spellings) {
        k::Source source{"bad-text.k", spelling};
        const auto result = k::Lexer{source}.lexAll();
        EXPECT_TRUE(result.error.has_value());
        if (result.error.has_value()) {
            EXPECT_EQ(result.error->span.start, 0u);
        }
    }
}

int main() {
    return test::runAll();
}
