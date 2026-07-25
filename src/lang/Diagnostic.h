#pragma once

#include "lang/Source.h"

#include <string>

namespace k {

struct Diagnostic {
    std::string message;
    SourceSpan span;
};

[[nodiscard]] std::string formatDiagnostic(const Source& source, const Diagnostic& diagnostic);

}
