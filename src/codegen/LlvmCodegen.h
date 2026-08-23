#pragma once

#include "codegen/Reachability.h"
#include "lang/Ast.h"
#include "lang/Diagnostic.h"
#include "lang/ModuleSystem.h"
#include "lang/Semantic.h"

#include <llvm/IR/Module.h>

#include <memory>
#include <vector>

namespace llvm {
class LLVMContext;
}

namespace k {

struct CodegenResult {
    std::unique_ptr<llvm::Module> module;
    std::vector<Diagnostic> diagnostics;
};

class LlvmCodegen {
public:
    LlvmCodegen(
        std::vector<ParsedModule> modules,
        llvm::LLVMContext& context,
        ReachableDeclarations reachable = {});

    [[nodiscard]] CodegenResult generate();

private:
    std::vector<ParsedModule> modules_;
    llvm::LLVMContext& context_;
    ReachableDeclarations reachable_;
};

}
