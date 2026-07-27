#include "TestHarness.h"
#include "codegen/LlvmCodegen.h"
#include "lang/Lexer.h"
#include "lang/Parser.h"
#include "lang/Semantic.h"

#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/raw_ostream.h>

#include <string>

namespace {

std::string generateIr(std::string text, std::vector<k::Diagnostic>& diagnostics) {
    k::Source source{"test.k", std::move(text)};
    const auto lexed = k::Lexer{source}.lexAll();
    auto parsed = k::Parser{source, lexed.tokens}.parseProgram();
    const auto semantic = k::SemanticAnalyzer{source, parsed.program}.analyze();
    llvm::LLVMContext context;
    std::vector<k::ParsedModule> modules;
    auto programPtr = std::make_unique<k::Program>(std::move(parsed.program));
    auto semanticPtr = std::make_unique<k::SemanticResult>(std::move(semantic));
    auto sourcePtr = std::make_unique<k::Source>(std::move(source));
    k::ParsedModule module;
    module.source = std::move(sourcePtr);
    module.program = std::move(programPtr);
    module.semantic = std::move(semanticPtr);
    modules.push_back(std::move(module));
    auto generated = k::LlvmCodegen{std::move(modules), context}.generate();
    diagnostics = std::move(generated.diagnostics);
    std::string ir;
    llvm::raw_string_ostream output{ir};
    if (generated.module) generated.module->print(output, nullptr);
    return ir;
}

}

TEST(codegen_creates_a_verified_module) {
    k::Source source{"module.k", "fn main(): i32 { return 42; }"};
    const auto lexed = k::Lexer{source}.lexAll();
    auto parsed = k::Parser{source, lexed.tokens}.parseProgram();
    const auto semantic = k::SemanticAnalyzer{source, parsed.program}.analyze();
    llvm::LLVMContext context;
    std::vector<k::ParsedModule> modules;
    auto programPtr = std::make_unique<k::Program>(std::move(parsed.program));
    auto semanticPtr = std::make_unique<k::SemanticResult>(std::move(semantic));
    auto sourcePtr = std::make_unique<k::Source>(std::move(source));
    k::ParsedModule module;
    module.source = std::move(sourcePtr);
    module.program = std::move(programPtr);
    module.semantic = std::move(semanticPtr);
    modules.push_back(std::move(module));

    auto generated = k::LlvmCodegen{std::move(modules), context}.generate();

    EXPECT_TRUE(generated.diagnostics.empty());
    EXPECT_TRUE(generated.module != nullptr);
    EXPECT_EQ(generated.module->getName().str(), "module.k");
}

TEST(codegen_lowers_local_integer_arithmetic_and_return) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn main(): i32 { val x: i32 = 40; return x + 2; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("define i32 @main()") != std::string::npos);
    EXPECT_TRUE(ir.find("alloca i32") != std::string::npos);
    EXPECT_TRUE(ir.find("store i32 40") != std::string::npos);
    EXPECT_TRUE(ir.find("load i32") != std::string::npos);
    EXPECT_TRUE(ir.find("add i32") != std::string::npos);
    EXPECT_TRUE(ir.find("ret i32") != std::string::npos);
}

TEST(codegen_lowers_print_builtins_to_runtime_calls) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn main(): i32 { print(\"value=\"); print(42); return 0; }",
        diagnostics);
    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("@k_std_print_bytes") != std::string::npos);
    EXPECT_TRUE(ir.find("@k_std_print_i32") != std::string::npos);
}

TEST(codegen_lowers_direct_user_function_calls) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn add(val a: i32, val b: i32): i32 { return a + b; }"
        "fn main(): i32 { print(add(40, 2)); return 0; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(
        ir.find("call i32 @add(i32 40, i32 2)") != std::string::npos);
}

TEST(codegen_lowers_tagged_nullable_and_unwrap) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn maybe(value: i32, enabled: bool): i32? {"
        "if (enabled) { return value; }"
        "return null;"
        "}"
        "fn main(): i32 { return maybe(42, true)!; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("{ i1, i32 }") != std::string::npos);
    EXPECT_TRUE(ir.find("insertvalue") != std::string::npos);
    EXPECT_TRUE(ir.find("extractvalue") != std::string::npos);
    EXPECT_TRUE(ir.find("@k_boot_panic") != std::string::npos);
}

TEST(codegen_monomorphizes_generic_functions_on_demand) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn identity<T>(value: T): T { return value; }"
        "fn main(): i64 {"
        "identity(40);"
        "identity(2);"
        "return identity<i64>(42);"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    const auto first = ir.find("define i32 @identity__g");
    EXPECT_TRUE(first != std::string::npos);
    EXPECT_TRUE(
        ir.find("define i32 @identity__g", first + 1) ==
        std::string::npos);
    EXPECT_TRUE(
        ir.find("define i64 @identity__g") != std::string::npos);
}

TEST(codegen_monomorphizes_generic_to_generic_calls) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn identity<T>(value: T): T { return value; }"
        "fn twice<T>(value: T): T {"
        "return identity<T>(identity<T>(value));"
        "}"
        "fn main(): i32 { return twice(42); }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("define i32 @twice__g") != std::string::npos);
    EXPECT_TRUE(ir.find("define i32 @identity__g") != std::string::npos);
}

TEST(codegen_monomorphizes_nullable_generic_function) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn maybe<T>(value: T, enabled: bool): T? {"
        "if (enabled) { return value; }"
        "return null;"
        "}"
        "fn main(): i32 { return maybe<i32>(42, true)!; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("define { i1, i32 } @maybe__g") !=
                std::string::npos);
}

TEST(codegen_declares_and_calls_extern_functions) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "extern fn k_boot_alloc(size: u64): unit*;"
        "extern fn k_boot_free(pointer: unit*);"
        "fn main(): i32 {"
        "val memory = k_boot_alloc(16);"
        "k_boot_free(memory);"
        "return 0;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("declare ptr @k_boot_alloc(i64)") != std::string::npos);
    EXPECT_TRUE(ir.find("call ptr @k_boot_alloc(i64 16)") != std::string::npos);
    EXPECT_TRUE(ir.find("call void @k_boot_free(ptr") != std::string::npos);
}

TEST(codegen_lowers_var_parameters_as_mutable_borrows) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn increment(var value: i32) { value = value + 1; }"
        "fn main(): i32 {"
        "var value = 41;"
        "increment(value);"
        "print(value);"
        "return 0;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("define void @increment(ptr %value)") != std::string::npos);
    EXPECT_TRUE(ir.find("call void @increment(ptr %value)") != std::string::npos);
}

TEST(codegen_lowers_forward_recursive_nested_and_unit_calls) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn main(): i32 { notify(); return twice(add(20, 1)); }"
        "fn add(val a: i32, val b: i32): i32 { return a + b; }"
        "fn twice(val value: i32): i32 { return value + value; }"
        "fn recurse(val value: i32): i32 { return recurse(value); }"
        "fn notify() { print(\"called\"); }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("call void @notify()") != std::string::npos);
    EXPECT_TRUE(ir.find("call i32 @add(i32 20, i32 1)") != std::string::npos);
    EXPECT_TRUE(ir.find("call i32 @twice(i32") != std::string::npos);
    EXPECT_TRUE(ir.find("call i32 @recurse(i32") != std::string::npos);
}

TEST(codegen_lowers_mutable_local_assignment) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn main(): i32 {"
        "var value: i32 = 40;"
        "value = value + 2;"
        "return value;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("store i32 42") == std::string::npos);
    const auto firstStore = ir.find("store i32");
    EXPECT_TRUE(firstStore != std::string::npos);
    EXPECT_TRUE(ir.find("store i32", firstStore + 1) != std::string::npos);
    EXPECT_TRUE(ir.find("load i32") != std::string::npos);
}

TEST(codegen_rejects_non_identifier_assignment_targets) {
    std::vector<k::Diagnostic> diagnostics;
    generateIr("fn main(): i32 { 1 = 2; return 0; }", diagnostics);

    EXPECT_EQ(diagnostics.size(), std::size_t{1});
    if (!diagnostics.empty()) {
        EXPECT_EQ(
            diagnostics.front().message,
            std::string{"assignment target is not supported by the LLVM backend yet"});
    }
}

TEST(codegen_lowers_comparisons_if_else_and_while) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn main(): i32 {"
        "var value = 0;"
        "if (value < 1) { value = value + 1; } else { return value; }"
        "while (value < 2) { value = value + 1; }"
        "return value;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("icmp slt i32") != std::string::npos);
    EXPECT_TRUE(ir.find("br i1") != std::string::npos);
    EXPECT_TRUE(ir.find("if.then") != std::string::npos);
    EXPECT_TRUE(ir.find("while.condition") != std::string::npos);
    EXPECT_TRUE(ir.find("while.body") != std::string::npos);
}

TEST(codegen_lowers_comparison_kinds_and_terminating_if) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn unsignedLess(val a: u32, val b: u32): bool { return a < b; }"
        "fn floatLess(val a: f64, val b: f64): bool { return a < b; }"
        "fn choose(val value: i32): i32 {"
        "if (value == 0) { return 1; } else { return 2; }"
        "}"
        "fn main(): i32 { return choose(0); }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("icmp ult i32") != std::string::npos);
    EXPECT_TRUE(ir.find("fcmp olt double") != std::string::npos);
    EXPECT_TRUE(ir.find("icmp eq i32") != std::string::npos);
}

TEST(codegen_lowers_raw_pointer_signatures_and_values) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn identity(val value: unit*): unit* { return value; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("define ptr @identity(ptr %value)") != std::string::npos);
    EXPECT_TRUE(ir.find("load ptr") != std::string::npos);
    EXPECT_TRUE(ir.find("ret ptr") != std::string::npos);
}

TEST(codegen_lowers_raw_pointer_dereference_read_and_write) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn update(val value: i32*): i32 {"
        "*value = *value + 1;"
        "return *value;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("load ptr") != std::string::npos);
    EXPECT_TRUE(ir.find("load i32, ptr") != std::string::npos);
    EXPECT_TRUE(ir.find("store i32") != std::string::npos);
}

TEST(codegen_lowers_address_of_mutable_locals) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "extern fn fill(output: unit**);"
        "extern fn k_boot_alloc(size: u64): unit*;"
        "fn call() {"
        "var output: unit* = k_boot_alloc(1);"
        "fill(&output);"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("call void @fill(ptr %output)") != std::string::npos);
}

TEST(codegen_lowers_raw_pointer_cast_and_indexing) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn update(val opaque: unit*, val index: i64): i32 {"
        "val values = opaque as i32*;"
        "values[index] = 42;"
        "return values[index];"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("getelementptr inbounds i32") != std::string::npos);
    EXPECT_TRUE(ir.find("store i32 42") != std::string::npos);
}

TEST(codegen_indexes_raw_pointer_struct_fields) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "struct Buffer(data: i32*)"
        "fn set(var buffer: Buffer, val index: u64, val value: i32) {"
        "buffer.data[index] = value;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("getelementptr inbounds i32") != std::string::npos);
}

TEST(codegen_lowers_sizeof_for_fixed_structs) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "struct Pair(left: i32, right: i32)"
        "fn size(): u64 { return sizeof(Pair); }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("getelementptr (%Pair, ptr null, i32 1)") !=
                std::string::npos);
    EXPECT_TRUE(ir.find("ptrtoint") != std::string::npos);
}

TEST(codegen_lowers_integer_width_casts) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn narrow(val value: u64): i32 { return value as i32; }"
        "fn changeSign(val value: i32): u32 { return value as u32; }"
        "fn widen(val value: i32): i64 { return value as i64; }"
        "fn widenUnsigned(val value: u32): i64 { return value as i64; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("trunc i64") != std::string::npos);
    EXPECT_TRUE(ir.find("sext i32") != std::string::npos);
    EXPECT_TRUE(ir.find("zext i32") != std::string::npos);
    EXPECT_TRUE(ir.find("cast.valid") != std::string::npos);
    EXPECT_TRUE(ir.find("cast.panic") != std::string::npos);
    EXPECT_TRUE(ir.find("integer cast out of range") != std::string::npos);
    EXPECT_TRUE(ir.find("@k_boot_panic") != std::string::npos);
}

TEST(codegen_lowers_float_casts) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn signedToFloat(val value: i32): f64 { return value as f64; }"
        "fn unsignedToFloat(val value: u32): f32 { return value as f32; }"
        "fn extend(val value: f32): f64 { return value as f64; }"
        "fn narrow(val value: f64): f32 { return value as f32; }"
        "fn checkedSigned(val value: f64): i32 { return value as i32; }"
        "fn checkedSignedWide(val value: f64): i64 { return value as i64; }"
        "fn checkedUnsigned(val value: f64): u8 { return value as u8; }"
        "fn checkedUnsigned32(val value: f64): u32 { return value as u32; }"
        "fn checkedUnsigned64(val value: f64): u64 { return value as u64; }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("sitofp i32") != std::string::npos);
    EXPECT_TRUE(ir.find("uitofp i32") != std::string::npos);
    EXPECT_TRUE(ir.find("fpext float") != std::string::npos);
    EXPECT_TRUE(ir.find("fptrunc double") != std::string::npos);
    EXPECT_TRUE(ir.find("fptosi double") != std::string::npos);
    EXPECT_TRUE(ir.find("fptoui double") != std::string::npos);
    const auto secondSigned = ir.find(
        "fptosi double", ir.find("fptosi double") + 1);
    EXPECT_TRUE(secondSigned != std::string::npos);
    const auto firstUnsigned = ir.find("fptoui double");
    const auto secondUnsigned = ir.find("fptoui double", firstUnsigned + 1);
    const auto thirdUnsigned = ir.find("fptoui double", secondUnsigned + 1);
    EXPECT_TRUE(thirdUnsigned != std::string::npos);
    EXPECT_TRUE(ir.find("fcmp ord") != std::string::npos ||
                ir.find("fcmp ogt") != std::string::npos);
    EXPECT_TRUE(ir.find("float cast out of range") != std::string::npos);
}

TEST(codegen_lowers_logical_operators_with_short_circuit_control_flow) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn rhs(): bool { val values = [1]; return values[1] == 0; }"
        "fn testAnd(val left: bool): bool { return left && rhs(); }"
        "fn testOr(val left: bool): bool { return left || rhs(); }",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("logic.rhs") != std::string::npos);
    EXPECT_TRUE(ir.find("logic.merge") != std::string::npos);
    EXPECT_TRUE(ir.find("phi i1") != std::string::npos);
    EXPECT_TRUE(ir.find(" and i1 ") == std::string::npos);
    EXPECT_TRUE(ir.find(" or i1 ") == std::string::npos);
}

TEST(codegen_lowers_struct_construction_and_field_access) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "struct SourceSpan(start: i64, end: i64)"
        "fn make(val start: i64, val end: i64): SourceSpan {"
        "return SourceSpan(start, end);"
        "}"
        "fn main(): i32 {"
        "var span = make(1, 2);"
        "span.end = span.start;"
        "print(42);"
        "return 0;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("%SourceSpan = type { i64, i64 }") != std::string::npos);
    EXPECT_TRUE(ir.find("insertvalue %SourceSpan") != std::string::npos);
    EXPECT_TRUE(ir.find("extractvalue %SourceSpan") != std::string::npos);
    EXPECT_TRUE(ir.find("getelementptr inbounds") != std::string::npos);
}

TEST(codegen_lowers_explicit_generic_struct_construction_and_field_access) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "struct Pair<A, B>(first: A, second: B)"
        "fn read(): i32 {"
        "val pair: Pair<i32, bool> = Pair<i32, bool>(42, true);"
        "return pair.first;"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("type { i32, i1 }") != std::string::npos);
}

TEST(codegen_lowers_fixed_array_index_read_write_and_bounds_check) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn read(val index: i32): i32 {"
        "var values: i32[2] = [1, 2];"
        "values[1] = values[0];"
        "return values[index];"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("[2 x i32]") != std::string::npos);
    EXPECT_TRUE(ir.find("getelementptr inbounds") != std::string::npos);
    EXPECT_TRUE(ir.find("icmp ult i32") != std::string::npos);
    EXPECT_TRUE(ir.find("@k_boot_panic") != std::string::npos);
}

TEST(codegen_lowers_array_to_slice_and_slice_indexing) {
    std::vector<k::Diagnostic> diagnostics;
    const auto ir = generateIr(
        "fn first(val values: []i32): i32 { return values[0]; }"
        "fn main(): i32 {"
        "val values: i32[2] = [1, 2];"
        "val view: []i32 = values;"
        "return first(view);"
        "}",
        diagnostics);

    EXPECT_TRUE(diagnostics.empty());
    EXPECT_TRUE(ir.find("{ ptr, i64 }") != std::string::npos);
    EXPECT_TRUE(ir.find("insertvalue { ptr, i64 }") != std::string::npos);
    EXPECT_TRUE(ir.find("extractvalue { ptr, i64 }") != std::string::npos);
    EXPECT_TRUE(ir.find("@k_boot_panic") != std::string::npos);
}

int main() {
    return test::runAll();
}
