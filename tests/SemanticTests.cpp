#include "TestHarness.h"
#include "lang/Lexer.h"
#include "lang/Parser.h"
#include "lang/Semantic.h"
#include "lang/SemanticType.h"

namespace {

struct SemanticFixture {
    k::Source source;
    k::LexResult lexed;
    k::ParseResult parsed;
    k::SemanticResult semantic;

    explicit SemanticFixture(std::string text)
        : source{"semantic.k", std::move(text)},
          lexed{k::Lexer{source}.lexAll()},
          parsed{k::Parser{source, lexed.tokens}.parseProgram()},
          semantic{k::SemanticAnalyzer{source, parsed.program}.analyze()} {}
};

}

TEST(semantic_types_have_structural_equality) {
    const auto i32 = k::SemanticType{k::SemanticTypeKind::I32};
    EXPECT_EQ(i32, k::SemanticType{k::SemanticTypeKind::I32});
    EXPECT_TRUE(!(i32 == k::SemanticType{k::SemanticTypeKind::F64}));
    EXPECT_EQ(k::nullableType(i32), k::nullableType(i32));
    EXPECT_EQ(k::arrayType(i32, 3), k::arrayType(i32, 3));
    EXPECT_TRUE(!(k::arrayType(i32, 3) == k::arrayType(i32, 4)));
    EXPECT_EQ(k::inferredArrayType(i32), k::inferredArrayType(i32));
    EXPECT_EQ(k::runtimeArrayType(i32), k::runtimeArrayType(i32));
    EXPECT_EQ(k::sliceType(i32), k::sliceType(i32));
    EXPECT_EQ(k::pointerType(i32), k::pointerType(i32));
}

TEST(semantic_types_have_stable_names) {
    const auto i32 = k::SemanticType{k::SemanticTypeKind::I32};
    EXPECT_EQ(k::semanticTypeName(k::SemanticType{k::SemanticTypeKind::Unit}), "unit");
    EXPECT_EQ(k::semanticTypeName(k::SemanticType{k::SemanticTypeKind::F64}), "f64");
    EXPECT_EQ(k::semanticTypeName(k::nullableType(i32)), "i32?");
    EXPECT_EQ(k::semanticTypeName(k::arrayType(i32, 3)), "i32[3]");
    EXPECT_EQ(k::semanticTypeName(k::inferredArrayType(i32)), "i32[]");
    EXPECT_EQ(k::semanticTypeName(k::runtimeArrayType(i32)), "i32[?]");
    EXPECT_EQ(k::semanticTypeName(k::sliceType(i32)), "[]i32");
    EXPECT_EQ(k::semanticTypeName(k::pointerType(i32)), "i32*");
    EXPECT_EQ(k::semanticTypeName(k::SemanticType{k::SemanticTypeKind::NullLiteral}), "null");
    EXPECT_EQ(k::semanticTypeName(k::SemanticType{k::SemanticTypeKind::Error}), "<error>");
}

TEST(semantic_numeric_metadata_is_available) {
    const auto i16 = k::SemanticType{k::SemanticTypeKind::I16};
    const auto u32 = k::SemanticType{k::SemanticTypeKind::U32};
    const auto f64 = k::SemanticType{k::SemanticTypeKind::F64};
    EXPECT_TRUE(k::isInteger(i16));
    EXPECT_TRUE(k::isNumeric(f64));
    EXPECT_TRUE(!k::isFloat(u32));
    EXPECT_EQ(k::numericBitWidth(u32), 32u);
    EXPECT_TRUE(k::isSignedInteger(i16));
    EXPECT_TRUE(!k::isSignedInteger(u32));
}

TEST(semantic_collects_all_function_signatures_before_bodies) {
    SemanticFixture fixture{
        "fn first(): i32 { return second(); } "
        "fn second(): i32 { return first(); }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
    EXPECT_EQ(fixture.semantic.functions.size(), 2u);
    EXPECT_EQ(fixture.semantic.functions.at("first").returnType,
              k::SemanticType{k::SemanticTypeKind::I32});
}

TEST(semantic_treats_unconstrained_type_parameter_as_any) {
    SemanticFixture fixture{
        "fn identity<T>(value: T): T { return value; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
    const auto& symbol = fixture.semantic.functions.at("identity");
    EXPECT_EQ(symbol.typeParameters.size(), 1u);
    EXPECT_EQ(
        symbol.typeParameters[0].constraint,
        k::GenericConstraint::Any);
}

TEST(semantic_checks_operators_against_generic_constraints) {
    SemanticFixture valid{
        "fn max<T: ordered>(a: T, b: T): T {"
        "if (a > b) { return a; }"
        "return b;"
        "}"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn invalid<T>(a: T, b: T): bool { return a < b; }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 1u);
    EXPECT_EQ(
        invalid.semantic.diagnostics[0].message,
        "operator '<' requires constraint 'ordered'");
}

TEST(semantic_rejects_unknown_generic_constraint) {
    SemanticFixture fixture{
        "fn invalid<T: magical>(value: T): T { return value; }"};
    EXPECT_EQ(fixture.semantic.diagnostics.size(), 1u);
    EXPECT_EQ(
        fixture.semantic.diagnostics[0].message,
        "unknown generic constraint 'magical'");
}

TEST(semantic_infers_and_accepts_explicit_generic_arguments) {
    SemanticFixture fixture{
        "fn identity<T>(value: T): T { return value; }"
        "fn main(): i64 {"
        "identity(42);"
        "return identity<i64>(42);"
        "}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
    EXPECT_EQ(fixture.semantic.resolvedCalls.size(), 2u);
    EXPECT_EQ(fixture.semantic.requestedSpecializations.size(), 2u);
}

TEST(semantic_rejects_inconsistent_generic_inference) {
    SemanticFixture fixture{
        "fn same<T>(a: T, b: T): T { return a; }"
        "fn main(): i32 { return same(1, 2.0); }"};
    EXPECT_EQ(fixture.semantic.diagnostics.size(), 1u);
    EXPECT_EQ(
        fixture.semantic.diagnostics[0].message,
        "inconsistent inference for type parameter 'T'");
}

TEST(semantic_requires_explicit_return_only_type_argument) {
    SemanticFixture fixture{
        "fn make<T>(): T { return make<T>(); }"
        "fn main(): i32 { return make(); }"};
    EXPECT_EQ(fixture.semantic.diagnostics.size(), 1u);
    EXPECT_EQ(
        fixture.semantic.diagnostics[0].message,
        "unable to infer type parameter 'T'");
}

TEST(semantic_supports_minimal_nullable_values) {
    SemanticFixture fixture{
        "fn maybe(value: i32, enabled: bool): i32? {"
        "if (enabled) { return value; }"
        "return null;"
        "}"
        "fn main(): i32 { return maybe(42, true)!; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_rejects_duplicate_functions) {
    SemanticFixture fixture{"fn same() {} fn same() {}"};
    EXPECT_EQ(fixture.semantic.diagnostics.size(), 1u);
}

TEST(semantic_resolves_composite_signature_types) {
    SemanticFixture fixture{
        "fn types(val a: i32?, var b: []u8, c: i16[3]): unit {}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
    const auto& function = fixture.semantic.functions.at("types");
    EXPECT_EQ(function.parameterTypes[0],
              k::nullableType(k::SemanticType{k::SemanticTypeKind::I32}));
    EXPECT_EQ(function.parameterTypes[1],
              k::sliceType(k::SemanticType{k::SemanticTypeKind::U8}));
    EXPECT_EQ(function.parameterTypes[2],
              k::arrayType(k::SemanticType{k::SemanticTypeKind::I16}, 3));
}

TEST(semantic_resolves_raw_pointer_signature_types) {
    SemanticFixture fixture{
        "fn pointers(val value: i32*, opaque: unit*): unit* { return opaque; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
    const auto& function = fixture.semantic.functions.at("pointers");
    EXPECT_EQ(
        function.parameterTypes[0],
        k::pointerType(k::SemanticType{k::SemanticTypeKind::I32}));
    EXPECT_EQ(
        function.parameterTypes[1],
        k::pointerType(k::SemanticType{k::SemanticTypeKind::Unit}));
    EXPECT_EQ(
        function.returnType,
        k::pointerType(k::SemanticType{k::SemanticTypeKind::Unit}));
}

TEST(semantic_checks_raw_pointer_dereference) {
    SemanticFixture valid{
        "fn update(val value: i32*): i32 {"
        "*value = *value + 1;"
        "return *value;"
        "}"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{"fn bad(val value: i32) { *value; }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 1u);
}

TEST(semantic_allows_address_of_mutable_locals) {
    SemanticFixture valid{
        "extern fn fill(output: unit**);"
        "fn call() { var output: unit* = k_boot_alloc(1); fill(&output); }"
        "extern fn k_boot_alloc(size: u64): unit*;"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn bad() { val value = 1; val pointer = &value; }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 1u);
}

TEST(semantic_allows_explicit_pointer_cast_and_raw_indexing) {
    SemanticFixture fixture{
        "fn update(val opaque: unit*, val index: i64): i32 {"
        "val values = opaque as i32*;"
        "values[index] = 42;"
        "return values[index];"
        "}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_allows_indexing_raw_pointer_struct_fields) {
    SemanticFixture fixture{
        "struct Buffer(data: i32*)"
        "fn set(var buffer: Buffer, val index: u64, val value: i32) {"
        "buffer.data[index] = value;"
        "}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_types_sizeof_as_u64) {
    SemanticFixture fixture{
        "struct Pair(left: i32, right: i32)"
        "fn size(): u64 { return sizeof(Pair); }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_checks_struct_construction_and_field_access) {
    SemanticFixture valid{
        "struct SourceSpan(start: i64, end: i64) {}"
        "fn read(): i64 {"
        "var span = SourceSpan(1, 2);"
        "span.end = span.start;"
        "return span.end;"
        "}"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());
    EXPECT_EQ(valid.semantic.structs.size(), 1u);

    SemanticFixture invalid{
        "struct Pair(left: i32, right: i32) {}"
        "fn bad() {"
        "val pair = Pair(1);"
        "pair.missing;"
        "pair.left = 2;"
        "}"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 3u);
}

TEST(semantic_checks_explicit_generic_struct_construction_and_fields) {
    SemanticFixture fixture{
        "struct Pair<A, B>(first: A, second: B)"
        "fn read(): i32 {"
        "val pair: Pair<i32, bool> = Pair<i32, bool>(42, true);"
        "return pair.first;"
        "}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_reports_unsupported_signature_types) {
    SemanticFixture fixture{"fn bad(x: Player): i32 | string { return 0; }"};
    EXPECT_EQ(fixture.semantic.diagnostics.size(), 2u);
}

TEST(semantic_checks_scopes_and_binding_mutability) {
    SemanticFixture valid{
        "fn ok(var p: i32) { var x = p; { val x = 2; } x += 1; }"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn bad(val p: i32) { p = 1; val x = x; val y = 1; val y = 2; z; }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 4u);
}

TEST(semantic_infers_literals_nullable_and_arrays) {
    SemanticFixture fixture{
        "fn values() { val x = 1; val y: f64 = 1; "
        "val n: i32? = null; val a = [1, 2, 3]; val e: i32[] = []; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());

    SemanticFixture invalid{"fn bad() { val n = null; val e = []; }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 2u);
}

TEST(semantic_checks_array_index_read_and_write) {
    SemanticFixture valid{
        "fn read(): i32 {"
        "var values: i32[2] = [1, 2];"
        "values[1] = values[0];"
        "return values[1];"
        "}"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn bad() {"
        "val values: i32[2] = [1, 2];"
        "values[true];"
        "values[2];"
        "values[0] = 3;"
        "}"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 3u);
}

TEST(semantic_converts_fixed_arrays_to_slices) {
    SemanticFixture fixture{
        "fn first(val values: []i32): i32 { return values[0]; }"
        "fn main(): i32 {"
        "val values: i32[2] = [1, 2];"
        "val view: []i32 = values;"
        "return first(view);"
        "}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_checks_calls_and_returns) {
    SemanticFixture valid{
        "fn main() { val x = later(1); } "
        "fn later(val x: i32): i32 { return x; }"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn unitFn() { return (); } "
        "fn needs(x: i32): i32 { return; } "
        "fn missing(): i32 {} "
        "fn caller() { needs(true); needs(); }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 5u);
}

TEST(semantic_checks_extern_function_calls) {
    SemanticFixture fixture{
        "extern fn k_boot_alloc(size: u64): unit*;"
        "extern fn k_boot_free(pointer: unit*);"
        "fn main(): i32 {"
        "val memory = k_boot_alloc(16);"
        "k_boot_free(memory);"
        "return 0;"
        "}"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_requires_mutable_arguments_for_var_parameters) {
    SemanticFixture valid{
        "fn increment(var value: i32) { value = value + 1; }"
        "fn main() { var value = 0; increment(value); }"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn increment(var value: i32) { value = value + 1; }"
        "fn main() { val value = 0; increment(value); increment(1); }"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 2u);
}

TEST(semantic_types_numeric_expressions_and_nullable_unwrap) {
    SemanticFixture fixture{
        "fn calc(var a: i16, val b: u16, val n: i32?): i32 { "
        "val sum = a + b; val value = n!; a = 2; return value; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_defers_runtime_array_size_equality) {
    SemanticFixture fixture{
        "fn sized(val n: i32) { val values: i32[n] = [1, 2]; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
    EXPECT_EQ(fixture.semantic.runtimeArraySizeChecks.size(), 1u);
    EXPECT_EQ(fixture.semantic.runtimeArraySizeChecks[0].literalLength, 2u);
}

TEST(semantic_requires_integer_runtime_sizes_in_signatures) {
    SemanticFixture fixture{"fn sized(val n: bool, val values: i32[n]) {}"};
    EXPECT_EQ(fixture.semantic.diagnostics.size(), 1u);
}

TEST(semantic_accepts_print_string_and_i32_builtins) {
    SemanticFixture fixture{
        "fn main(): i32 { print(\"value=\"); print(42); return 0; }"};
    EXPECT_TRUE(fixture.semantic.diagnostics.empty());
}

TEST(semantic_checks_control_flow_conditions_and_scopes) {
    SemanticFixture valid{
        "fn main(): i32 {"
        "var value = 0;"
        "if (value < 1) { val inner = value; value = inner + 1; }"
        "while (value < 2) { value = value + 1; }"
        "return value;"
        "}"};
    EXPECT_TRUE(valid.semantic.diagnostics.empty());

    SemanticFixture invalid{
        "fn bad() {"
        "if (1) { val hidden = 0; }"
        "while (2) {}"
        "hidden;"
        "}"};
    EXPECT_EQ(invalid.semantic.diagnostics.size(), 3u);
}

int main() {
    return test::runAll();
}
