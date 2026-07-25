#pragma once

#include "lang/Diagnostic.h"

#include <filesystem>
#include <memory>
#include <vector>

namespace llvm {
class Module;
class TargetMachine;
}

namespace k {

struct NativeResult {
    std::vector<Diagnostic> diagnostics;
};

class NativeEmitter {
public:
    NativeEmitter();
    ~NativeEmitter();

    NativeEmitter(const NativeEmitter&) = delete;
    NativeEmitter& operator=(const NativeEmitter&) = delete;

    NativeResult emitObject(
        llvm::Module& module,
        const std::filesystem::path& outputPath);

private:
    std::unique_ptr<llvm::TargetMachine> targetMachine_;
};

}
