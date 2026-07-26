#include "lang/ModuleSystem.h"

#include "lang/Lexer.h"
#include "lang/Parser.h"

#include <algorithm>
#include <fstream>
#include <iterator>
#include <sstream>
#include <string>

namespace k {

ModuleLoader::ModuleLoader(std::filesystem::path entryPath)
    : entryPath_(std::move(entryPath)) {
    moduleSearchPaths_.push_back(std::filesystem::current_path());
    if (entryPath_.has_parent_path()) {
        std::error_code ec;
        moduleSearchPaths_.push_back(
            std::filesystem::absolute(entryPath_.parent_path(), ec));
    }
    if (entryPath_.has_parent_path()) {
        moduleSearchPaths_.push_back(entryPath_.parent_path());
    }
}

const std::filesystem::path& ModuleLoader::entryPath() const noexcept {
    return entryPath_;
}

std::vector<ModuleSource>& ModuleLoader::modules() noexcept {
    return modules_;
}

const std::vector<Diagnostic>& ModuleLoader::diagnostics() const noexcept {
    return diagnostics_;
}

void ModuleLoader::report(SourceSpan span, std::string message,
                          const std::filesystem::path& path) {
    Diagnostic diagnostic;
    diagnostic.message = std::move(message);
    diagnostic.span = span;
    diagnostic.path = path.string();
    diagnostics_.push_back(std::move(diagnostic));
}

bool ModuleLoader::load() {
    return loadInto(std::filesystem::absolute(entryPath_), 0);
}

bool ModuleLoader::loadInto(const std::filesystem::path& path,
                            std::size_t depth) {
    if (depth > 64) {
        Diagnostic diagnostic;
        diagnostic.message = "module import depth exceeded";
        diagnostic.path = path.string();
        diagnostics_.push_back(std::move(diagnostic));
        return false;
    }
    std::error_code ec;
    auto canonical = std::filesystem::weakly_canonical(path, ec);
    if (ec) canonical = path;
    const auto key = canonical.string();
    if (visited_.find(key) != visited_.end()) return true;

    std::ifstream input{path, std::ios::binary};
    if (!input) {
        Diagnostic diagnostic;
        diagnostic.message = "cannot open module file: " + path.string();
        diagnostic.path = path.string();
        diagnostics_.push_back(std::move(diagnostic));
        return false;
    }
    std::string text{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{}};

    ModuleSource module;
    module.path = path;
    module.source = std::make_unique<Source>(path.string(), std::move(text));
    auto lexed = Lexer{*module.source}.lexAll();
    if (lexed.error.has_value()) {
        report(lexed.error->span, lexed.error->message, path);
        return false;
    }
    module.tokens = std::make_unique<std::vector<Token>>(
        std::move(lexed.tokens));
    auto parsed = Parser{*module.source, *module.tokens}.parseProgram();
    if (!parsed.diagnostics.empty()) {
        for (auto& diagnostic : parsed.diagnostics) {
            if (diagnostic.path.empty()) diagnostic.path = path.string();
            diagnostics_.push_back(std::move(diagnostic));
        }
        return false;
    }
    auto program = std::make_unique<Program>(std::move(parsed.program));
    const auto importsCopy = program->imports;
    const auto& sourceText = module.source->text();
    module.program = std::move(program);
    visited_[key] = modules_.size();
    for (const auto& imp : importsCopy) {
        std::vector<std::string> modulePath;
        modulePath.reserve(imp.path.size());
        for (const auto& part : imp.path) {
            modulePath.emplace_back(
                sourceText.substr(part.start, part.end - part.start));
        }
        if (modulePath.empty()) continue;
        if (imp.isWildcard) {
            // Keep the full path (e.g. "std.io") for wildcard imports.
        } else {
            // Single-symbol imports drop the last path component so that
            // `import std.io.print` resolves the `std.io` module.
            if (!modulePath.empty()) modulePath.pop_back();
        }
        if (modulePath.empty()) {
            std::ostringstream oss;
            oss << "import is missing module path: ";
            for (const auto& part : imp.path) {
                oss << sourceText.substr(part.start, part.end - part.start) << '.';
            }
            Diagnostic diagnostic;
            diagnostic.message = oss.str();
            diagnostic.path = path.string();
            diagnostic.span = imp.span;
            diagnostics_.push_back(std::move(diagnostic));
            return false;
        }
        if (modulePath.empty()) continue;
        auto resolved = resolveImport(modulePath, path, imp.isWildcard);
        if (!resolved.has_value()) {
            std::ostringstream oss;
            oss << "cannot resolve import: ";
            for (std::size_t i = 0; i < imp.path.size(); ++i) {
                if (i > 0) oss << '.';
                const auto& part = imp.path[i];
                oss << sourceText.substr(part.start, part.end - part.start);
            }
            Diagnostic diagnostic;
            diagnostic.message = oss.str();
            diagnostic.path = path.string();
            diagnostic.span = imp.span;
            diagnostics_.push_back(std::move(diagnostic));
            return false;
        }
        if (!loadInto(*resolved, depth + 1)) return false;
    }
    modules_.push_back(std::move(module));
    return true;
}

std::optional<std::filesystem::path> ModuleLoader::resolveImport(
    const std::vector<std::string>& modulePath,
    const std::filesystem::path& currentPath,
    bool isWildcard) const {
    if (modulePath.empty()) return std::nullopt;
    if (isWildcard) {
        std::filesystem::path dir;
        for (std::size_t i = 0; i < modulePath.size(); ++i) {
            if (i == 0) dir = modulePath[i];
            else dir /= modulePath[i];
        }
        for (const auto& search : moduleSearchPaths_) {
            auto candidate = search / dir;
            std::error_code ec;
            if (std::filesystem::is_directory(candidate, ec)) {
                return candidate / "mod.k";
            }
        }
        return std::nullopt;
    }
    std::filesystem::path relative;
    for (std::size_t i = 0; i < modulePath.size(); ++i) {
        if (i == 0) relative = modulePath[i];
        else relative /= modulePath[i];
    }
    auto relativeWithExt = relative;
    relativeWithExt.replace_extension(".k");
    auto parent = currentPath.parent_path();
    std::error_code ec;
    for (const auto& search : moduleSearchPaths_) {
        auto candidate = search / relativeWithExt;
        if (std::filesystem::exists(candidate, ec)) {
            return candidate;
        }
    }
    auto localCandidate = parent / relativeWithExt;
    if (std::filesystem::exists(localCandidate, ec)) return localCandidate;
    return std::nullopt;
}

}
