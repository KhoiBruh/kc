#include "codegen/NativeEmitter.h"

#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Module.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Support/CodeGen.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>
#include <llvm/TargetParser/Host.h>

#include <optional>
#include <system_error>

namespace k {

NativeEmitter::NativeEmitter() = default;
NativeEmitter::~NativeEmitter() = default;

NativeResult NativeEmitter::emitObject(
    llvm::Module& module,
    const std::filesystem::path& outputPath) {
    NativeResult result;
    static const bool initialized = [] {
        return !llvm::InitializeNativeTarget() &&
            !llvm::InitializeNativeTargetAsmParser() &&
            !llvm::InitializeNativeTargetAsmPrinter();
    }();
    if (!initialized) {
        result.diagnostics.push_back({"failed to initialize native LLVM target", {0, 0}});
        return result;
    }

    const llvm::Triple triple{llvm::sys::getDefaultTargetTriple()};
    std::string targetError;
    const auto* target = llvm::TargetRegistry::lookupTarget(triple, targetError);
    if (!target) {
        result.diagnostics.push_back(
            {"LLVM target lookup failed: " + targetError, {0, 0}});
        return result;
    }
    llvm::TargetOptions options;
    targetMachine_.reset(target->createTargetMachine(
        triple, "generic", "", options, std::nullopt));
    if (!targetMachine_) {
        result.diagnostics.push_back({"failed to create LLVM target machine", {0, 0}});
        return result;
    }
    module.setTargetTriple(triple);
    module.setDataLayout(targetMachine_->createDataLayout());

    auto temporary = outputPath;
    temporary += ".tmp";
    std::error_code error;
    llvm::raw_fd_ostream output{
        temporary.string(), error, llvm::sys::fs::OF_None};
    if (error) {
        result.diagnostics.push_back(
            {"cannot open object output: " + error.message(), {0, 0}});
        return result;
    }
    llvm::legacy::PassManager passes;
    if (targetMachine_->addPassesToEmitFile(
            passes, output, nullptr, llvm::CodeGenFileType::ObjectFile)) {
        result.diagnostics.push_back(
            {"LLVM target cannot emit object files", {0, 0}});
        return result;
    }
    passes.run(module);
    output.flush();
    output.close();
    std::filesystem::remove(outputPath, error);
    error.clear();
    std::filesystem::rename(temporary, outputPath, error);
    if (error) {
        std::filesystem::remove(temporary);
        result.diagnostics.push_back(
            {"cannot publish object output: " + error.message(), {0, 0}});
    }
    return result;
}

}
#include <llvm/TargetParser/Triple.h>
