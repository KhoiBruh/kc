#include "lang/Diagnostic.h"

#include <sstream>

namespace k {

std::string formatDiagnostic(const Source& source, const Diagnostic& diagnostic) {
    const auto position = source.positionAt(diagnostic.span.start);
    std::ostringstream output;
    output << source.path() << ':' << position.line << ':' << position.column
           << ": error: " << diagnostic.message;
    return output.str();
}

}
