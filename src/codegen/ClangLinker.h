#pragma once

#include "lang/Diagnostic.h"

#include <filesystem>
#include <vector>

namespace k {

struct LinkResult {
    std::vector<Diagnostic> diagnostics;
};

std::filesystem::path configuredClangPath();

class ClangLinker {
public:
    explicit ClangLinker(std::filesystem::path clangPath);
    LinkResult link(
        const std::filesystem::path& objectPath,
        const std::filesystem::path& executablePath) const;

private:
    std::filesystem::path clangPath_;
};

}
