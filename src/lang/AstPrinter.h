#pragma once

#include "lang/Ast.h"

#include <string>

namespace k {

[[nodiscard]] std::string printAst(const Source& source, const Program& program);

}
