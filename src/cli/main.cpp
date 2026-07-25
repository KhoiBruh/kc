#include "codegen/LlvmCodegen.h"
#include "codegen/ClangLinker.h"
#include "codegen/NativeEmitter.h"
#include "lang/AstPrinter.h"
#include "lang/Diagnostic.h"
#include "lang/Lexer.h"
#include "lang/ModuleSystem.h"
#include "lang/Parser.h"
#include "lang/Semantic.h"
#include "lang/Source.h"
#include "lang/Token.h"

#include <llvm/IR/LLVMContext.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/raw_ostream.h>

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <string>

namespace {

enum class OutputMode { None, Tokens, Ast, Check, EmitLlvm, EmitObject, Executable };

int usageError(std::string_view message) {
    std::cerr << "kc: error: " << message << '\n';
    std::cerr << "usage: kc [--tokens|--ast|--check] file.k\n"
              << "       kc --emit-llvm file.k -o file.ll\n"
              << "       kc --emit-obj file.k -o file.obj\n"
              << "       kc file.k -o file.exe\n";
    return 1;
}

}

int main(int argc, char** argv) {
    auto outputMode = OutputMode::None;
    std::filesystem::path inputPath;
    std::filesystem::path outputPath;

    if (argc == 2) {
        inputPath = argv[1];
    } else if (argc == 3) {
        const std::string_view option{argv[1]};
        if (option == "--tokens") outputMode = OutputMode::Tokens;
        else if (option == "--ast") outputMode = OutputMode::Ast;
        else if (option == "--check") outputMode = OutputMode::Check;
        else return usageError("unknown option");
        inputPath = argv[2];
    } else if (argc == 5 &&
               (std::string_view{argv[1]} == "--emit-llvm" ||
                std::string_view{argv[1]} == "--emit-obj") &&
               std::string_view{argv[3]} == "-o") {
        outputMode = std::string_view{argv[1]} == "--emit-llvm"
            ? OutputMode::EmitLlvm : OutputMode::EmitObject;
        inputPath = argv[2];
        outputPath = argv[4];
    } else if (argc == 4 && std::string_view{argv[2]} == "-o") {
        outputMode = OutputMode::Executable;
        inputPath = argv[1];
        outputPath = argv[3];
    } else {
        return usageError("expected one .k source file");
    }

    if (inputPath.extension() != ".k") {
        return usageError("source file must use the .k extension");
    }
    if (outputMode == OutputMode::EmitLlvm && outputPath.extension() != ".ll") {
        return usageError("LLVM IR output file must use the .ll extension");
    }
    if (outputMode == OutputMode::EmitObject && outputPath.extension() != ".obj")
        return usageError("object output file must use the .obj extension");
    if (outputMode == OutputMode::Executable && outputPath.extension() != ".exe")
        return usageError("executable output file must use the .exe extension");

    std::ifstream input{inputPath, std::ios::binary};
    if (!input) {
        std::cerr << "kc: error: cannot open " << inputPath.string() << '\n';
        return 1;
    }
    std::string text{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{}};
    k::Source source{inputPath.string(), std::move(text)};
    const auto result = k::Lexer{source}.lexAll();

    if (result.error.has_value()) {
        std::cerr << k::formatDiagnostic(source, *result.error) << '\n';
        return 2;
    }

    if (outputMode == OutputMode::Tokens) {
        for (const auto& token : result.tokens) {
            const auto position = source.positionAt(token.span.start);
            std::cout << position.line << ':' << position.column << "  "
                      << std::left << std::setw(20) << k::tokenKindName(token.kind)
                      << " \"" << k::escapeLexeme(token.lexeme(source)) << "\"\n";
        }
        return 0;
    }

    k::ModuleLoader loader{inputPath};
    if (!loader.load()) {
        for (const auto& diagnostic : loader.diagnostics()) {
            std::cerr << diagnostic.message << '\n';
        }
        return 2;
    }
    std::vector<k::ParsedModule> parsedModules;
    {
        auto& rawModules = loader.modules();
        parsedModules.reserve(rawModules.size());
        for (auto& module : rawModules) {
            k::ParsedModule parsed;
            parsed.source = std::move(module.source);
            parsed.program = std::move(module.program);
            parsedModules.push_back(std::move(parsed));
        }
    }
    for (std::size_t i = parsedModules.size(); i > 0; --i) {
        const auto idx = i - 1;
        auto& module = parsedModules[idx];
        if (module.semantic != nullptr) continue;
        k::SemanticAnalyzer analyzer{*module.source, *module.program};
        for (std::size_t j = idx + 1; j < parsedModules.size(); ++j) {
            if (parsedModules[j].semantic == nullptr) {
                k::SemanticAnalyzer otherAnalyzer{
                    *parsedModules[j].source,
                    *parsedModules[j].program};
                parsedModules[j].semantic =
                    std::make_unique<k::SemanticResult>(otherAnalyzer.analyze());
            }
            analyzer.importExports(*parsedModules[j].semantic);
        }
        module.semantic = std::make_unique<k::SemanticResult>(analyzer.analyze());
    }
    if (outputMode == OutputMode::Ast) {
        for (const auto& module : parsedModules) {
            std::cout << k::printAst(*module.source, *module.program);
        }
        return 0;
    }
    bool anyDiagnostics = false;
    for (const auto& module : parsedModules) {
        for (const auto& diagnostic : module.semantic->diagnostics) {
            std::cerr << k::formatDiagnostic(*module.source, diagnostic) << '\n';
            anyDiagnostics = true;
        }
    }
    if (anyDiagnostics) return 2;
    if (outputMode == OutputMode::Check) {
        std::cout << "check succeeded\n";
        return 0;
    } else if (outputMode == OutputMode::EmitLlvm ||
               outputMode == OutputMode::EmitObject ||
               outputMode == OutputMode::Executable) {
        if (outputMode != OutputMode::EmitLlvm) {
            const k::FunctionSymbol* mainSymbol = nullptr;
            for (const auto& module : parsedModules) {
                const auto found = module.semantic->functions.find("main");
                if (found != module.semantic->functions.end() &&
                    !found->second.declaration->isExtern) {
                    mainSymbol = &found->second;
                    break;
                }
            }
            if (mainSymbol == nullptr ||
                !mainSymbol->parameterTypes.empty() ||
                mainSymbol->returnType.kind != k::SemanticTypeKind::I32) {
                std::cerr << "kc: error: native output requires fn main(): i32\n";
                return 2;
            }
        }
        llvm::LLVMContext context;
        auto generated =
            k::LlvmCodegen{std::move(parsedModules), context}.generate();
        if (!generated.diagnostics.empty()) {
            for (const auto& diagnostic : generated.diagnostics) {
                k::Source fallback{inputPath.string(), ""};
                std::cerr << k::formatDiagnostic(fallback, diagnostic) << '\n';
            }
            return 2;
        }
        if (outputMode == OutputMode::EmitLlvm) {
            std::error_code error;
            llvm::raw_fd_ostream output{
                outputPath.string(), error, llvm::sys::fs::OF_Text};
            if (error) {
                std::cerr << "kc: error: cannot write " << outputPath.string()
                          << ": " << error.message() << '\n';
                return 1;
            }
            generated.module->print(output, nullptr);
        } else {
            auto objectPath = outputMode == OutputMode::EmitObject
                ? outputPath : std::filesystem::path{outputPath.string() + ".tmp.obj"};
            k::NativeEmitter emitter;
            auto emitted = emitter.emitObject(*generated.module, objectPath);
            if (!emitted.diagnostics.empty()) {
                std::cerr << "kc: error: " << emitted.diagnostics.front().message << '\n';
                return 2;
            }
            if (outputMode == OutputMode::Executable) {
                auto linked = k::ClangLinker{k::configuredClangPath()}
                    .link(objectPath, outputPath);
                if (!linked.diagnostics.empty()) {
                    std::cerr << "kc: error: " << linked.diagnostics.front().message << '\n';
                    return 2;
                }
                std::filesystem::remove(objectPath);
            }
        }
    }
    return 0;
}
