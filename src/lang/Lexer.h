#pragma once

#include "lang/Diagnostic.h"
#include "lang/Token.h"

#include <optional>
#include <vector>

namespace k {

struct LexResult {
    std::vector<Token> tokens;
    std::optional<Diagnostic> error;
};

class Lexer {
public:
    explicit Lexer(const Source& source);
    [[nodiscard]] LexResult lexAll();

private:
    [[nodiscard]] bool atEnd() const noexcept;
    [[nodiscard]] char current() const noexcept;
    [[nodiscard]] bool startsWith(std::string_view spelling) const noexcept;
    void skipTrivia(LexResult& result);
    void lexIdentifier(LexResult& result);
    void lexNumber(LexResult& result);
    void lexQuoted(LexResult& result);
    bool lexOperator(LexResult& result);

    const Source& source_;
    std::size_t offset_ = 0;
};

}
