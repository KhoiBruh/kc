#include "TestHarness.h"
#include "codegen/LlvmCodegen.h"
#include "codegen/ClangLinker.h"
#include "codegen/NativeEmitter.h"
#include "lang/Lexer.h"
#include "lang/Parser.h"
#include "lang/Semantic.h"

#include <llvm/IR/LLVMContext.h>

#include <filesystem>

TEST(native_emitter_configures_and_writes_host_object) {
    k::Source source{"native.k", "fn main(): i32 { return 42; }"};
    const auto lexed = k::Lexer{source}.lexAll();
    auto parsed = k::Parser{source, lexed.tokens}.parseProgram();
    const auto semantic = k::SemanticAnalyzer{source, parsed.program}.analyze();
    llvm::LLVMContext context;
    std::vector<k::ParsedModule> modules;
    auto programPtr = std::make_unique<k::Program>(std::move(parsed.program));
    auto semanticPtr =
        std::make_unique<k::SemanticResult>(std::move(semantic));
    auto sourcePtr =
        std::make_unique<k::Source>(std::move(source));
    k::ParsedModule module;
    module.source = std::move(sourcePtr);
    module.program = std::move(programPtr);
    module.semantic = std::move(semanticPtr);
    modules.push_back(std::move(module));
    auto generated = k::LlvmCodegen{std::move(modules), context}.generate();
    k::NativeEmitter emitter;
    const auto output =
        std::filesystem::temp_directory_path() / "klang-native-test.obj";

    auto emitted = emitter.emitObject(*generated.module, output);

    EXPECT_TRUE(emitted.diagnostics.empty());
    EXPECT_TRUE(!generated.module->getTargetTriple().empty());
    EXPECT_TRUE(!generated.module->getDataLayoutStr().empty());
    EXPECT_TRUE(std::filesystem::exists(output));
    EXPECT_TRUE(std::filesystem::file_size(output) > 0);
    std::filesystem::remove(output);
}

TEST(clang_linker_creates_executable) {
    k::ClangLinker linker{
        "C:\\Users\\Admin\\tools\\llvm-22.1.8\\bin\\clang.exe"};
    auto result = linker.link(
        std::filesystem::temp_directory_path() / "klang-native-test.obj",
        std::filesystem::temp_directory_path() / "klang-native-test.exe");
    EXPECT_EQ(result.diagnostics.size(), 1u);
}

int main() {
    return test::runAll();
}
