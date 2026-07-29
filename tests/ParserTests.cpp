#include "TestHarness.h"
#include "lang/Ast.h"
#include "lang/AstPrinter.h"
#include "lang/Lexer.h"
#include "lang/Parser.h"

#include <string>
#include <variant>

namespace {

struct ParseFixture {
    k::Source source;
    k::LexResult lexed;
    k::ParseResult parsed;

    explicit ParseFixture(std::string text)
        : source{"parser.k", std::move(text)},
          lexed{k::Lexer{source}.lexAll()},
          parsed{k::Parser{source, lexed.tokens}.parseProgram()} {}

    std::string_view text(k::SourceSpan span) const {
        return source.text().substr(span.start, span.end - span.start);
    }
};

}

TEST(lexer_recognizes_as_keyword) {
    k::Source source{"cast.k", "as"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(!result.error.has_value());
    EXPECT_EQ(result.tokens.front().kind, k::TokenKind::KwAs);
}

TEST(lexer_recognizes_if_keyword) {
    k::Source source{"if.k", "if"};
    const auto result = k::Lexer{source}.lexAll();
    EXPECT_TRUE(!result.error.has_value());
    EXPECT_EQ(result.tokens.front().kind, k::TokenKind::KwIf);
}

TEST(ast_expression_owns_variant_node) {
    auto value = k::makeExpr(
        k::SourceSpan{0, 1},
        k::LiteralExpr{k::TokenKind::IntegerLiteral, {0, 1}});
    EXPECT_EQ(value->span.start, 0u);
    EXPECT_TRUE(std::holds_alternative<k::LiteralExpr>(value->node));
}

TEST(parser_parses_function_parameters_and_types) {
    ParseFixture fixture{
        "fn f(val a: Player?, var b: []i8, c: Map<string, pkg.Item> | IO_ERROR): i8[10] {}"};
    EXPECT_TRUE(!fixture.lexed.error.has_value());
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.functions.size(), 1u);
    const auto& function = fixture.parsed.program.functions.front();
    EXPECT_EQ(function.parameters.size(), 3u);
    EXPECT_EQ(function.parameters[0].mode, k::ParameterMode::ImmutableBorrow);
    EXPECT_TRUE(std::holds_alternative<k::NullableType>(function.parameters[0].type->node));
    EXPECT_EQ(function.parameters[1].mode, k::ParameterMode::MutableBorrow);
    EXPECT_TRUE(std::holds_alternative<k::SliceType>(function.parameters[1].type->node));
    EXPECT_EQ(function.parameters[2].mode, k::ParameterMode::Owned);
    EXPECT_TRUE(std::holds_alternative<k::UnionType>(function.parameters[2].type->node));
    EXPECT_TRUE(std::holds_alternative<k::ArrayType>(function.returnType->node));
}

TEST(parser_parses_generic_function_parameters) {
    ParseFixture fixture{
        "fn identity<T>(value: T): T { return value; }"
        "fn max<T: ordered>(a: T, b: T): T { return a; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.functions[0].typeParameters.size(), 1u);
    EXPECT_EQ(
        fixture.text(
            fixture.parsed.program.functions[0].typeParameters[0].name),
        "T");
    EXPECT_TRUE(
        !fixture.parsed.program.functions[0].typeParameters[0]
             .constraint.has_value());
    EXPECT_TRUE(
        fixture.parsed.program.functions[1].typeParameters[0]
            .constraint.has_value());
    EXPECT_EQ(
        fixture.text(
            *fixture.parsed.program.functions[1].typeParameters[0]
                 .constraint),
        "ordered");
}

TEST(parser_parses_explicit_call_type_arguments) {
    ParseFixture fixture{
        "fn identity<T>(value: T): T { return value; }"
        "fn main(): i32 { return identity<i32>(42); }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& returned = std::get<k::ReturnStmt>(
        fixture.parsed.program.functions[1].body->statements[0]->node);
    const auto& call = std::get<k::CallExpr>(returned.value->node);
    EXPECT_EQ(call.typeArguments.size(), 1u);
    EXPECT_TRUE(
        std::holds_alternative<k::NamedType>(call.typeArguments[0]->node));
    const auto printed =
        k::printAst(fixture.source, fixture.parsed.program);
    EXPECT_TRUE(printed.find("TypeParameter T any") != std::string::npos);
    EXPECT_TRUE(printed.find("TypeArguments") != std::string::npos);
}

TEST(parser_keeps_less_than_as_comparison) {
    ParseFixture fixture{
        "fn less(a: i32, b: i32): bool { return a < b; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& returned = std::get<k::ReturnStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    EXPECT_EQ(
        std::get<k::BinaryExpr>(returned.value->node).op,
        k::TokenKind::Less);
}

TEST(parser_rejects_nested_nullable_type) {
    ParseFixture fixture{"fn f(x: Player??) {}"};
    EXPECT_EQ(fixture.parsed.diagnostics.size(), 1u);
    EXPECT_EQ(fixture.parsed.diagnostics[0].message, "nullable type cannot be nested");
}

TEST(parser_represents_explicit_unit_as_unit_type) {
    ParseFixture fixture{"fn f(): unit {}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_TRUE(std::holds_alternative<k::UnitType>(
        fixture.parsed.program.functions[0].returnType->node));
}

TEST(parser_parses_postfix_raw_pointer_types) {
    ParseFixture fixture{"fn pointers(val value: i32*, opaque: unit*): unit* {}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& function = fixture.parsed.program.functions[0];
    EXPECT_TRUE(std::holds_alternative<k::PointerType>(
        function.parameters[0].type->node));
    EXPECT_TRUE(std::holds_alternative<k::PointerType>(
        function.parameters[1].type->node));
    EXPECT_TRUE(std::holds_alternative<k::PointerType>(
        function.returnType->node));
}

TEST(parser_parses_fixed_struct_declarations_and_members) {
    ParseFixture fixture{
        "struct SourceSpan(start: i64, end: i64) {}"
        "fn read(var span: SourceSpan): i64 {"
        "span.end = span.start;"
        "return span.end;"
        "}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.structs.size(), 1u);
    EXPECT_EQ(fixture.parsed.program.structs[0].fields.size(), 2u);
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& assignment = std::get<k::AssignmentExpr>(
        std::get<k::ExpressionStmt>(statements[0]->node).expression->node);
    EXPECT_TRUE(std::holds_alternative<k::MemberExpr>(assignment.target->node));
}

TEST(parser_accepts_data_only_struct_without_body_braces) {
    ParseFixture fixture{
        "struct Player(name: string, playtime: u32)"
        "fn playtime(val player: Player): u32 { return player.playtime; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.structs.size(), 1u);
    EXPECT_EQ(fixture.parsed.program.structs[0].fields.size(), 2u);
    EXPECT_EQ(fixture.parsed.program.functions.size(), 1u);
}

TEST(parser_parses_generic_struct_declaration_and_explicit_constructor) {
    ParseFixture fixture{
        "struct Pair<A, B>(first: A, second: B)"
        "fn read(): i32 {"
        "val pair: Pair<i32, bool> = Pair<i32, bool>(42, true);"
        "return pair.first;"
        "}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.structs[0].typeParameters.size(), 2u);
}

TEST(parser_parses_extern_function_declarations) {
    ParseFixture fixture{
        "extern fn k_boot_alloc(size: u64): unit*;"
        "fn main(): i32 { return 0; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.functions.size(), 2u);
    EXPECT_TRUE(fixture.parsed.program.functions[0].isExtern);
    EXPECT_TRUE(fixture.parsed.program.functions[0].body == nullptr);
    EXPECT_TRUE(!fixture.parsed.program.functions[1].isExtern);
}

TEST(parser_distinguishes_unit_literal_from_empty_call) {
    ParseFixture fixture{"fn f() { val nothing: unit = (); f(); }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& variable = std::get<k::VariableDecl>(statements[0]->node);
    EXPECT_TRUE(std::holds_alternative<k::UnitLiteralExpr>(
        variable.initializer->node));
    const auto& callStatement = std::get<k::ExpressionStmt>(statements[1]->node);
    EXPECT_TRUE(std::holds_alternative<k::CallExpr>(
        callStatement.expression->node));
}

TEST(parser_parses_module_and_import_declarations) {
    ParseFixture fixture{
        "module math;\n"
        "import std.io.print;\n"
        "import std.io.Lexer;\n"
        "import math.vector.*;\n"
        "struct Point(x: i32, y: i32)\n"
        "fn get_x(p: Point): i32 { return p.x; }\n"
    };
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_TRUE(fixture.parsed.program.module.has_value());
    EXPECT_EQ(fixture.text(fixture.parsed.program.module->name), "math");
    EXPECT_EQ(fixture.parsed.program.imports.size(), 3u);
    EXPECT_TRUE(!fixture.parsed.program.imports[0].isWildcard);
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[0].path[0]), "std");
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[0].path[1]), "io");
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[0].path[2]), "print");

    EXPECT_TRUE(!fixture.parsed.program.imports[1].isWildcard);
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[1].path[0]), "std");
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[1].path[1]), "io");
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[1].path[2]), "Lexer");

    EXPECT_TRUE(fixture.parsed.program.imports[2].isWildcard);
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[2].path[0]), "math");
    EXPECT_EQ(fixture.text(fixture.parsed.program.imports[2].path[1]), "vector");

    const auto printed = k::printAst(fixture.source, fixture.parsed.program);
    EXPECT_TRUE(printed.find("Module math") != std::string::npos);
    EXPECT_TRUE(printed.find("Import std.io.print") != std::string::npos);
    EXPECT_TRUE(printed.find("Import std.io.Lexer") != std::string::npos);
    EXPECT_TRUE(printed.find("Import math.vector.*") != std::string::npos);
}

TEST(parser_reports_error_when_module_is_not_first) {
    ParseFixture fixture{
        "import std.io;\n"
        "module math;\n"
    };
    EXPECT_TRUE(!fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.diagnostics[0].message, "'module' declaration must be at top of file");
}

TEST(parser_reports_error_when_import_is_after_item) {
    ParseFixture fixture{
        "struct Point(x: i32)\n"
        "import std.io;\n"
    };
    EXPECT_TRUE(!fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.diagnostics[0].message, "'import' declaration must precede items");
}

TEST(parser_parses_array_literals) {
    ParseFixture fixture{
        "fn f() { val values = [1, 2 + 3, 4]; val empty: i32[] = []; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& values = std::get<k::VariableDecl>(statements[0]->node);
    const auto& valuesArray = std::get<k::ArrayLiteralExpr>(
        values.initializer->node);
    EXPECT_EQ(valuesArray.elements.size(), 3u);
    const auto& empty = std::get<k::VariableDecl>(statements[1]->node);
    const auto& emptyArray = std::get<k::ArrayLiteralExpr>(
        empty.initializer->node);
    EXPECT_EQ(emptyArray.elements.size(), 0u);
}

TEST(parser_parses_index_read_and_assignment) {
    ParseFixture fixture{
        "fn array() {"
        "var values: i32[2] = [1, 2];"
        "values[1] = values[0];"
        "}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statement = std::get<k::ExpressionStmt>(
        fixture.parsed.program.functions[0].body->statements[1]->node);
    const auto& assignment =
        std::get<k::AssignmentExpr>(statement.expression->node);
    EXPECT_TRUE(std::holds_alternative<k::IndexExpr>(
        assignment.target->node));
    EXPECT_TRUE(std::holds_alternative<k::IndexExpr>(
        assignment.value->node));
}

TEST(parser_parses_raw_pointer_dereference_read_and_write) {
    ParseFixture fixture{
        "fn pointer(val value: i32*) { *value = *value + 1; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statement = std::get<k::ExpressionStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    const auto& assignment =
        std::get<k::AssignmentExpr>(statement.expression->node);
    EXPECT_EQ(
        std::get<k::UnaryExpr>(assignment.target->node).op,
        k::TokenKind::Star);
}

TEST(parser_parses_raw_address_of) {
    ParseFixture fixture{
        "extern fn fill(output: unit**);"
        "fn call() { var output: unit* = k_boot_alloc(1); fill(&output); }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& call = std::get<k::CallExpr>(
        std::get<k::ExpressionStmt>(
            fixture.parsed.program.functions[1].body->statements[1]->node)
            .expression->node);
    EXPECT_EQ(
        std::get<k::UnaryExpr>(call.arguments[0]->node).op,
        k::TokenKind::Ampersand);
}

TEST(parser_parses_sizeof_type_expression) {
    ParseFixture fixture{
        "struct Pair(left: i32, right: i32)"
        "fn size(): u64 { return sizeof(Pair); }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& returnStatement = std::get<k::ReturnStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    EXPECT_TRUE(std::holds_alternative<k::SizeofExpr>(
        returnStatement.value->node));
}

TEST(parser_respects_expression_precedence_and_assignment_associativity) {
    ParseFixture fixture{
        "fn main() { val x = 1 + 2 * 3; a = b = x; return object.get(1).value!?; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& variable = std::get<k::VariableDecl>(statements[0]->node);
    const auto& plus = std::get<k::BinaryExpr>(variable.initializer->node);
    EXPECT_EQ(plus.op, k::TokenKind::Plus);
    EXPECT_TRUE(std::holds_alternative<k::BinaryExpr>(plus.right->node));
    const auto& assignment = std::get<k::ExpressionStmt>(statements[1]->node);
    const auto& outer = std::get<k::AssignmentExpr>(assignment.expression->node);
    EXPECT_TRUE(std::holds_alternative<k::AssignmentExpr>(outer.value->node));
}

TEST(parser_parses_struct_methods_with_explicit_receivers) {
    ParseFixture fixture{
        "struct Counter(value: i32) {"
        "fn read(val self): i32 => self.value;"
        "fn increment(var self) { self.value++; }"
        "}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.structs.size(), 1u);
    const auto& methods = fixture.parsed.program.structs[0].methods;
    EXPECT_EQ(methods.size(), 2u);
    EXPECT_EQ(methods[0].parameters[0].mode, k::ParameterMode::ImmutableBorrow);
    EXPECT_EQ(methods[1].parameters[0].mode, k::ParameterMode::MutableBorrow);
}

TEST(parser_parses_postfix_increment_and_decrement) {
    ParseFixture fixture{"fn update() { var value = 1; value++; value--; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& increment = std::get<k::PostfixExpr>(
        std::get<k::ExpressionStmt>(statements[1]->node).expression->node);
    const auto& decrement = std::get<k::PostfixExpr>(
        std::get<k::ExpressionStmt>(statements[2]->node).expression->node);
    EXPECT_EQ(increment.op, k::TokenKind::PlusPlus);
    EXPECT_EQ(decrement.op, k::TokenKind::MinusMinus);
}

TEST(parser_parses_integer_range_membership) {
    ParseFixture fixture{
        "fn contains(value: i32): bool {"
        "return value in 65..90 && value in 65>..<90;"
        "}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& returned = std::get<k::ReturnStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    const auto& logical = std::get<k::BinaryExpr>(returned.value->node);
    EXPECT_EQ(std::get<k::BinaryExpr>(logical.left->node).op, k::TokenKind::KwIn);
    EXPECT_EQ(
        std::get<k::BinaryExpr>(
            std::get<k::BinaryExpr>(logical.right->node).right->node).op,
        k::TokenKind::RangeExclusiveBoth);
}

TEST(parser_parses_payload_free_enum_without_trailing_comma) {
    ParseFixture valid{
        "enum Status { Ready, Running, Done }"
        "fn current(): Status { return Status.Ready; }"};
    EXPECT_TRUE(valid.parsed.diagnostics.empty());
    EXPECT_EQ(valid.parsed.program.enums.size(), 1u);
    EXPECT_EQ(valid.parsed.program.enums[0].variants.size(), 3u);

    ParseFixture trailing{"enum Status { Ready, } fn main(): i32 { return 0; }"};
    EXPECT_TRUE(!trailing.parsed.diagnostics.empty());
}

TEST(parser_allows_when_expression_without_else_for_semantic_exhaustiveness) {
    ParseFixture fixture{
        "enum Status { Ready, Done }"
        "fn score(val status: Status): i32 { return when (status) {"
        "Status.Ready -> 1; Status.Done -> 2; }; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
}

TEST(parser_parses_break_and_continue_statements) {
    ParseFixture fixture{
        "fn loop() { while (true) { continue; break; } }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& loop = std::get<k::WhileStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    EXPECT_TRUE(std::holds_alternative<k::ContinueStmt>(
        loop.body->statements[0]->node));
    EXPECT_TRUE(std::holds_alternative<k::BreakStmt>(
        loop.body->statements[1]->node));
}

TEST(parser_accepts_single_statement_control_flow_bodies) {
    ParseFixture fixture{
        "fn f() {"
        "if (true)\nreturn; else while (false) continue;"
        "for (item in 0..<2) print(item);"
        "}"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    EXPECT_TRUE(std::holds_alternative<k::IfStmt>(statements[0]->node));
    EXPECT_TRUE(std::holds_alternative<k::ForStmt>(statements[1]->node));
}

TEST(parser_accepts_collection_for_with_optional_index_binding) {
    ParseFixture fixture{
        "fn f(players: []i32) { for (player in players) print(player); "
        "for (player, i in players) print(player); }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& first = std::get<k::ForStmt>(statements[0]->node);
    const auto& second = std::get<k::ForStmt>(statements[1]->node);
    EXPECT_TRUE(!first.indexName.has_value());
    EXPECT_EQ(fixture.text(*second.indexName), "i");
}

TEST(parser_accepts_subject_and_condition_when_statements) {
    ParseFixture fixture{
        "fn f(code: i32) { when (code) { 1 -> return; else -> return; } "
        "when { code == 2 -> print(code); else -> print(0); } }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    const auto& subject = std::get<k::WhenStmt>(statements[0]->node);
    const auto& condition = std::get<k::WhenStmt>(statements[1]->node);
    EXPECT_TRUE(subject.subject != nullptr);
    EXPECT_TRUE(condition.subject == nullptr);
    EXPECT_TRUE(subject.branches.back().conditions.empty());
}

TEST(parser_accepts_grouped_subject_when_patterns) {
    ParseFixture fixture{
        "fn f(code: i32): i32 { return when (code) {"
        "1, 2, 3 -> 1; 4, 5 -> 2; else -> 0; }; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& returned = std::get<k::ReturnStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    const auto& expression = std::get<k::WhenExpr>(returned.value->node);
    EXPECT_EQ(expression.branches[0].conditions.size(), 3u);
    EXPECT_EQ(expression.branches[1].conditions.size(), 2u);
    EXPECT_TRUE(expression.branches.back().conditions.empty());
}

TEST(parser_parses_left_associative_integer_casts) {
    ParseFixture fixture{
        "fn convert(val value: i32): u64 { return value as i64 as u64; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statement = fixture.parsed.program.functions[0].body->statements[0];
    const auto& returned = std::get<k::ReturnStmt>(statement->node);
    const auto& outer = std::get<k::CastExpr>(returned.value->node);
    EXPECT_TRUE(std::holds_alternative<k::CastExpr>(outer.value->node));
    const auto& target = std::get<k::NamedType>(outer.type->node);
    EXPECT_EQ(fixture.text(target.parts[0]), "u64");
}

TEST(parser_parses_when_expressions) {
    ParseFixture fixture{
        "fn choose(val code: i32): i32 { return when (code) {"
        "1 -> 10; else -> 20; }; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& returned = std::get<k::ReturnStmt>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    const auto& expression = std::get<k::WhenExpr>(returned.value->node);
    EXPECT_TRUE(expression.subject != nullptr);
    EXPECT_EQ(expression.branches.size(), 2u);
    EXPECT_TRUE(expression.branches.back().conditions.empty());

    ParseFixture blockFixture{
        "fn choose(val code: i32): i32 { return when (code) {"
        "1 -> { val value = 9; value + 1 } else -> { 20 } }; }"};
    EXPECT_TRUE(blockFixture.parsed.diagnostics.empty());
    const auto& blockReturn = std::get<k::ReturnStmt>(
        blockFixture.parsed.program.functions[0].body->statements[0]->node);
    const auto& blockWhen = std::get<k::WhenExpr>(blockReturn.value->node);
    EXPECT_EQ(blockWhen.branches[0].body->statements.size(), 1u);

    ParseFixture missingElse{
        "fn choose(val code: i32): i32 { return when (code) { 1 -> 10; }; }"};
    EXPECT_TRUE(missingElse.parsed.diagnostics.empty());
}

TEST(parser_parses_if_expressions) {
    ParseFixture fixture{
        "fn choose(val b: i32, val c: i32): i32 {"
        "val a = if (b > c) b else 1; return a; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& declaration = std::get<k::VariableDecl>(
        fixture.parsed.program.functions[0].body->statements[0]->node);
    EXPECT_TRUE(std::holds_alternative<k::IfExpr>(declaration.initializer->node));

    ParseFixture blocks{
        "fn choose(val b: i32): i32 { return if (b > 0) {"
        "val value = b + 1; value } else { 0 }; }"};
    EXPECT_TRUE(blocks.parsed.diagnostics.empty());
}

TEST(parser_requires_semicolons_and_recovers_later_statements) {
    ParseFixture fixture{
        "fn main() { val missing = 1 val kept = 2; return kept; }"};
    EXPECT_TRUE(!fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    EXPECT_EQ(statements.size(), 1u);
    EXPECT_TRUE(std::holds_alternative<k::ReturnStmt>(statements[0]->node));
}

TEST(parser_parses_if_else_and_while_statements) {
    ParseFixture fixture{
        "fn main(): i32 {"
        "var value = 0;"
        "if (value < 1) { value = value + 1; } else { return value; }"
        "while (value < 2) { value = value + 1; }"
        "return value;"
        "}"};

    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    const auto& statements = fixture.parsed.program.functions[0].body->statements;
    EXPECT_TRUE(std::holds_alternative<k::IfStmt>(statements[1]->node));
    EXPECT_TRUE(std::holds_alternative<k::WhileStmt>(statements[2]->node));
}

TEST(parser_recovers_to_later_function) {
    ParseFixture fixture{"enum Bad {} fn good() {}"};
    EXPECT_TRUE(!fixture.parsed.diagnostics.empty());
    EXPECT_EQ(fixture.parsed.program.functions.size(), 1u);
    EXPECT_EQ(
        fixture.source.text().substr(
            fixture.parsed.program.functions[0].name.start,
            fixture.parsed.program.functions[0].name.end -
                fixture.parsed.program.functions[0].name.start),
        "good");
}

TEST(ast_printer_is_deterministic) {
    ParseFixture fixture{
        "fn main(): i32 { val answer: i32 = 1 + 2 * 3; return answer; }"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_EQ(
        k::printAst(fixture.source, fixture.parsed.program),
        "Program\n"
        "  Function main\n"
        "    ReturnType\n"
        "      Type i32\n"
        "    Parameters\n"
        "    Block\n"
        "      Variable val answer\n"
        "        DeclaredType\n"
        "          Type i32\n"
        "        Binary +\n"
        "          Integer 1\n"
        "          Binary *\n"
        "            Integer 2\n"
        "            Integer 3\n"
        "      Return\n"
        "        Identifier answer\n");
}

TEST(parser_accepts_expression_bodied_functions) {
    ParseFixture fixture{
        "fn explicit(): i32 => 42; fn inferred() => explicit();"};
    EXPECT_TRUE(fixture.parsed.diagnostics.empty());
    EXPECT_TRUE(fixture.parsed.program.functions[0].isExpressionBody);
    EXPECT_TRUE(!fixture.parsed.program.functions[0].infersReturnType);
    EXPECT_TRUE(fixture.parsed.program.functions[1].isExpressionBody);
    EXPECT_TRUE(fixture.parsed.program.functions[1].infersReturnType);
}

int main() {
    return test::runAll();
}
