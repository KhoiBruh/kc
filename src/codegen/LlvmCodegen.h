#pragma once

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

struct ParsedModule {
    std::unique_ptr<Source> source;
    std::unique_ptr<Program> program;
    std::unique_ptr<SemanticResult> semantic;
};

class LlvmCodegen {
public:
    LlvmCodegen(
        std::vector<ParsedModule> modules,
        llvm::LLVMContext& context);

    [[nodiscard]] CodegenResult generate();

private:
    std::vector<ParsedModule> modules_;
    llvm::LLVMContext& context_;
};

}
