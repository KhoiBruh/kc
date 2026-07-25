#include "codegen/LlvmCodegen.h"
#include "codegen/ClangLinker.h"
#include "codegen/NativeEmitter.h"
#include "lang/AstPrinter.h"
#include "lang/Diagnostic.h"
#include "lang/Lexer.h"
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

    auto parsed = k::Parser{source, result.tokens}.parseProgram();
    if (!parsed.diagnostics.empty()) {
        for (const auto& diagnostic : parsed.diagnostics) {
            std::cerr << k::formatDiagnostic(source, diagnostic) << '\n';
        }
        return 2;
    }

    if (outputMode == OutputMode::Ast) {
        std::cout << k::printAst(source, parsed.program);
        return 0;
    }

    auto semantic = k::SemanticAnalyzer{source, parsed.program}.analyze();
    if (!semantic.diagnostics.empty()) {
        for (const auto& diagnostic : semantic.diagnostics) {
            std::cerr << k::formatDiagnostic(source, diagnostic) << '\n';
        }
        return 2;
    }
    if (outputMode == OutputMode::Check) {
        std::cout << "check succeeded\n";
    } else if (outputMode == OutputMode::EmitLlvm ||
               outputMode == OutputMode::EmitObject ||
               outputMode == OutputMode::Executable) {
        if (outputMode != OutputMode::EmitLlvm) {
            const auto mainFunction = semantic.functions.find("main");
            if (mainFunction == semantic.functions.end() ||
                !mainFunction->second.parameterTypes.empty() ||
                mainFunction->second.returnType.kind != k::SemanticTypeKind::I32) {
                std::cerr << "kc: error: native output requires fn main(): i32\n";
                return 2;
            }
        }
        llvm::LLVMContext context;
        auto generated =
            k::LlvmCodegen{source, parsed.program, semantic, context}.generate();
        if (!generated.diagnostics.empty()) {
            for (const auto& diagnostic : generated.diagnostics) {
                std::cerr << k::formatDiagnostic(source, diagnostic) << '\n';
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
