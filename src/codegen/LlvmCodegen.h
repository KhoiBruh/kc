#pragma once

#include "lang/Ast.h"
#include "lang/Diagnostic.h"
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
        const Source& source,
        const Program& program,
        const SemanticResult& semantic,
        llvm::LLVMContext& context);

    [[nodiscard]] CodegenResult generate();

private:
    const Source& source_;
    const Program& program_;
    const SemanticResult& semantic_;
    llvm::LLVMContext& context_;
};

}
