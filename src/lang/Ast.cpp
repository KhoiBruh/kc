#include "lang/Ast.h"

namespace k {

SourceSpan spanFrom(SourceSpan first, SourceSpan last) noexcept {
    return {first.start, last.end};
}

}
