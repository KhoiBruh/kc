#pragma once

#include "lang/Ast.h"
#include "lang/Diagnostic.h"
#include "lang/Source.h"

#include <filesystem>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace k {

struct ModuleSource {
    std::filesystem::path path;
    std::unique_ptr<Source> source;
    std::unique_ptr<std::vector<Token>> tokens;
    std::unique_ptr<Program> program;
};

class ModuleLoader {
public:
    explicit ModuleLoader(std::filesystem::path entryPath);

    [[nodiscard]] bool load();
    [[nodiscard]] const std::vector<Diagnostic>& diagnostics() const noexcept;
    [[nodiscard]] std::vector<ModuleSource>& modules() noexcept;
    [[nodiscard]] const std::filesystem::path& entryPath() const noexcept;

private:
    [[nodiscard]] bool loadInto(const std::filesystem::path& path,
                                std::size_t depth);
    [[nodiscard]] std::optional<std::filesystem::path> resolveImport(
        const std::vector<std::string>& modulePath,
        const std::filesystem::path& currentPath) const;
    void report(SourceSpan span, std::string message,
                const std::filesystem::path& path);

    std::filesystem::path entryPath_;
    std::vector<ModuleSource> modules_;
    std::vector<Diagnostic> diagnostics_;
    std::unordered_map<std::string, std::size_t> visited_;
    std::vector<std::filesystem::path> moduleSearchPaths_;
};

}
