#pragma once

#include "lang/Ast.h"
#include "lang/ModuleSystem.h"
#include "lang/Semantic.h"

#include <unordered_set>
#include <vector>

namespace k {

struct ReachableDeclarations {
    // When no entry point (fn main) exists, filtered is false and the caller
    // emits every declaration (preserves library-style compilation).
    bool filtered = false;
    std::unordered_set<const FunctionDecl*> functions;
    std::unordered_set<const StructDecl*> structs;
    std::unordered_set<const EnumDecl*> enums;
    std::unordered_set<const ConstantDecl*> constants;
};

// Computes the set of declarations reachable from the entry point `main`
// through call, type, and constant references across all loaded modules.
[[nodiscard]] ReachableDeclarations computeReachable(
    const std::vector<ParsedModule>& modules);

}
