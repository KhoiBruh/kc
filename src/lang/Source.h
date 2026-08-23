#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace k {

struct SourceSpan {
    std::size_t start;
    std::size_t end;
};

struct SourcePosition {
    std::size_t line;
    std::size_t column;
};

[[nodiscard]] std::size_t utf8ScalarLength(std::string_view text, std::size_t offset) noexcept;

class Source {
public:
    Source(std::string path, std::string text);

    [[nodiscard]] std::string_view path() const noexcept;
    [[nodiscard]] std::string_view text() const noexcept;
    [[nodiscard]] bool isValidUtf8() const noexcept;
    [[nodiscard]] std::size_t invalidUtf8Offset() const noexcept;
    [[nodiscard]] SourcePosition positionAt(std::size_t offset) const noexcept;

private:
    std::string path_;
    std::string text_;
    std::vector<std::size_t> lineStarts_;
    std::size_t invalidUtf8Offset_;
};

}
