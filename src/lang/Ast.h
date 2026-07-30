#pragma once

#include "lang/Source.h"
#include "lang/Token.h"

#include <memory>
#include <optional>
#include <utility>
#include <variant>
#include <vector>

namespace k {

struct Expr;
struct Type;
struct Stmt;

using ExprPtr = std::unique_ptr<Expr>;
using TypePtr = std::unique_ptr<Type>;
using StmtPtr = std::unique_ptr<Stmt>;

struct BlockStmt { std::vector<StmtPtr> statements; };

enum class ParameterMode { Owned, ImmutableBorrow, MutableBorrow };
enum class VariableMode { Val, Var };

struct IdentifierExpr { SourceSpan name; };
struct LiteralExpr { TokenKind kind; SourceSpan spelling; };
struct UnaryExpr { TokenKind op; ExprPtr operand; };
struct BinaryExpr { ExprPtr left; TokenKind op; ExprPtr right; };
struct AssignmentExpr { ExprPtr target; TokenKind op; ExprPtr value; };
struct CastExpr { ExprPtr value; TypePtr type; };
struct CallExpr {
    ExprPtr callee;
    std::vector<TypePtr> typeArguments;
    std::vector<ExprPtr> arguments;
};
struct MemberExpr { ExprPtr object; SourceSpan name; };
struct IndexExpr { ExprPtr object; ExprPtr index; };
struct PostfixExpr { ExprPtr value; TokenKind op; };
struct UnitLiteralExpr {};
struct ArrayLiteralExpr { std::vector<ExprPtr> elements; };
struct SizeofExpr { TypePtr type; };
struct WhenExprBranch {
    std::vector<ExprPtr> conditions;
    std::unique_ptr<BlockStmt> body;
    ExprPtr value;
};
struct WhenExpr {
    ExprPtr subject;
    std::vector<WhenExprBranch> branches;
};
struct IfExprBranch {
    std::unique_ptr<BlockStmt> body;
    ExprPtr value;
};
struct IfExpr {
    ExprPtr condition;
    IfExprBranch thenBranch;
    IfExprBranch elseBranch;
};

struct Expr {
    using Node = std::variant<IdentifierExpr, LiteralExpr, UnaryExpr, BinaryExpr,
                              AssignmentExpr, CastExpr, CallExpr, MemberExpr,
                              IndexExpr, PostfixExpr, UnitLiteralExpr,
                              ArrayLiteralExpr, SizeofExpr, WhenExpr, IfExpr>;
    SourceSpan span;
    Node node;
};

struct NamedType {
    std::vector<SourceSpan> parts;
    std::vector<TypePtr> arguments;
};
struct NullableType { TypePtr inner; };
struct PointerType { TypePtr pointee; };
struct ArrayType { TypePtr element; ExprPtr size; };
struct SliceType { TypePtr element; };
struct UnionType { std::vector<TypePtr> members; };
struct UnitType {};

struct Type {
    using Node = std::variant<NamedType, NullableType, PointerType, ArrayType,
                              SliceType, UnionType, UnitType>;
    SourceSpan span;
    Node node;
};

struct IfStmt {
    ExprPtr condition;
    std::unique_ptr<BlockStmt> thenBranch;
    std::unique_ptr<BlockStmt> elseBranch;
};
struct WhileStmt {
    ExprPtr condition;
    std::unique_ptr<BlockStmt> body;
};
struct ForStmt {
    SourceSpan valueName;
    std::optional<SourceSpan> indexName;
    ExprPtr collection;
    std::unique_ptr<BlockStmt> body;
};
struct WhenBranch {
    std::vector<ExprPtr> conditions;
    std::unique_ptr<BlockStmt> body;
};
struct WhenStmt {
    ExprPtr subject;
    std::vector<WhenBranch> branches;
};
struct BreakStmt {};
struct ContinueStmt {};
struct VariableDecl {
    VariableMode mode;
    SourceSpan name;
    TypePtr declaredType;
    ExprPtr initializer;
};
struct ReturnStmt { ExprPtr value; };
struct ExpressionStmt { ExprPtr expression; };
struct DeferStmt { StmtPtr statement; };

struct Stmt {
    using Node = std::variant<BlockStmt, IfStmt, WhileStmt, ForStmt, WhenStmt,
                              BreakStmt, ContinueStmt, VariableDecl,
                              ReturnStmt, DeferStmt, ExpressionStmt>;
    SourceSpan span;
    Node node;
};

struct Parameter {
    ParameterMode mode;
    SourceSpan name;
    TypePtr type;
    SourceSpan span;
};

struct StructField {
    SourceSpan name;
    TypePtr type;
    SourceSpan span;
};

struct TypeParameter {
    SourceSpan name;
    std::optional<SourceSpan> constraint;
    SourceSpan span;
};

struct FunctionDecl {
    SourceSpan name;
    std::vector<TypeParameter> typeParameters;
    std::vector<Parameter> parameters;
    TypePtr returnType;
    std::unique_ptr<BlockStmt> body;
    SourceSpan span;
    bool isExtern = false;
    bool isExpressionBody = false;
    bool infersReturnType = false;
    std::optional<SourceSpan> ownerStruct;
    bool isAssociated = false;
};

struct StructDecl {
    SourceSpan name;
    std::vector<TypeParameter> typeParameters;
    std::vector<StructField> fields;
    std::vector<FunctionDecl> methods;
    SourceSpan span;
};

struct EnumVariant { SourceSpan name; SourceSpan span; };
struct EnumDecl {
    SourceSpan name;
    std::vector<EnumVariant> variants;
    SourceSpan span;
};

struct ConstantDecl {
    SourceSpan name;
    TypePtr declaredType;
    ExprPtr initializer;
    SourceSpan span;
};

struct ModuleDecl {
    SourceSpan name;
    SourceSpan span;
};

struct ImportDecl {
    std::vector<SourceSpan> path;
    bool isWildcard = false;
    SourceSpan span;
};

struct Program {
    std::optional<ModuleDecl> module;
    std::vector<ImportDecl> imports;
    std::vector<EnumDecl> enums;
    std::vector<ConstantDecl> constants;
    std::vector<StructDecl> structs;
    std::vector<FunctionDecl> functions;
    SourceSpan span{0, 0};
};

template <typename Node>
ExprPtr makeExpr(SourceSpan span, Node node) {
    return std::make_unique<Expr>(Expr{span, Expr::Node{std::move(node)}});
}

template <typename Node>
TypePtr makeType(SourceSpan span, Node node) {
    return std::make_unique<Type>(Type{span, Type::Node{std::move(node)}});
}

template <typename Node>
StmtPtr makeStmt(SourceSpan span, Node node) {
    return std::make_unique<Stmt>(Stmt{span, Stmt::Node{std::move(node)}});
}

[[nodiscard]] SourceSpan spanFrom(SourceSpan first, SourceSpan last) noexcept;

}
