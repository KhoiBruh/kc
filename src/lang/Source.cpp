#include "lang/Source.h"

#include <algorithm>
#include <limits>
#include <utility>

namespace k {

namespace {

bool isContinuation(unsigned char byte) noexcept {
    return (byte & 0xC0u) == 0x80u;
}

}

std::size_t utf8ScalarLength(std::string_view text, std::size_t offset) noexcept {
    if (offset >= text.size()) {
        return 0;
    }

    const auto first = static_cast<unsigned char>(text[offset]);
    if (first <= 0x7Fu) {
        return 1;
    }

    if (first >= 0xC2u && first <= 0xDFu) {
        return offset + 1 < text.size() &&
                       isContinuation(static_cast<unsigned char>(text[offset + 1]))
                   ? 2
                   : 0;
    }

    if (first >= 0xE0u && first <= 0xEFu) {
        if (offset + 2 >= text.size()) {
            return 0;
        }
        const auto second = static_cast<unsigned char>(text[offset + 1]);
        const auto third = static_cast<unsigned char>(text[offset + 2]);
        if (!isContinuation(second) || !isContinuation(third)) {
            return 0;
        }
        if ((first == 0xE0u && second < 0xA0u) ||
            (first == 0xEDu && second >= 0xA0u)) {
            return 0;
        }
        return 3;
    }

    if (first >= 0xF0u && first <= 0xF4u) {
        if (offset + 3 >= text.size()) {
            return 0;
        }
        const auto second = static_cast<unsigned char>(text[offset + 1]);
        if (!isContinuation(second) ||
            !isContinuation(static_cast<unsigned char>(text[offset + 2])) ||
            !isContinuation(static_cast<unsigned char>(text[offset + 3]))) {
            return 0;
        }
        if ((first == 0xF0u && second < 0x90u) ||
            (first == 0xF4u && second >= 0x90u)) {
            return 0;
        }
        return 4;
    }

    return 0;
}

Source::Source(std::string path, std::string text)
    : path_(std::move(path)),
      text_(std::move(text)),
      lineStarts_{0},
      invalidUtf8Offset_(std::numeric_limits<std::size_t>::max()) {
    for (std::size_t offset = 0; offset < text_.size();) {
        const auto length = utf8ScalarLength(text_, offset);
        if (length == 0) {
            invalidUtf8Offset_ = offset;
            break;
        }
        if (text_[offset] == '\n') {
            lineStarts_.push_back(offset + 1);
        }
        offset += length;
    }
}

std::string_view Source::path() const noexcept {
    return path_;
}

std::string_view Source::text() const noexcept {
    return text_;
}

bool Source::isValidUtf8() const noexcept {
    return invalidUtf8Offset_ == std::numeric_limits<std::size_t>::max();
}

std::size_t Source::invalidUtf8Offset() const noexcept {
    return invalidUtf8Offset_;
}

SourcePosition Source::positionAt(std::size_t offset) const noexcept {
    offset = std::min(offset, text_.size());
    const auto upper = std::upper_bound(lineStarts_.begin(), lineStarts_.end(), offset);
    const auto lineIndex = static_cast<std::size_t>(upper - lineStarts_.begin() - 1);
    const auto lineStart = lineStarts_[lineIndex];

    std::size_t column = 1;
    for (std::size_t cursor = lineStart; cursor < offset;) {
        const auto length = utf8ScalarLength(text_, cursor);
        cursor += length == 0 ? 1 : length;
        ++column;
    }
    return {lineIndex + 1, column};
}

}
