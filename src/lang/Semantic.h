#pragma once

#include "lang/Ast.h"
#include "lang/Diagnostic.h"
#include "lang/SemanticType.h"

#include <string>
#include <unordered_map>
#include <vector>

namespace k {

enum class GenericConstraint {
    Any,
    Comparable,
    Ordered,
    Number,
    Integer,
    Unsigned,
    Float,
};

struct TypeParameterSymbol {
    std::string name;
    GenericConstraint constraint = GenericConstraint::Any;
    std::size_t index = 0;
};

struct FunctionSymbol {
    const FunctionDecl* declaration;
    std::vector<TypeParameterSymbol> typeParameters;
    std::vector<SemanticType> parameterTypes;
    SemanticType returnType;
};

struct SpecializationKey {
    const FunctionDecl* declaration = nullptr;
    std::vector<SemanticType> typeArguments;

    bool operator==(const SpecializationKey&) const = default;
};

struct ResolvedCall {
    const FunctionSymbol* function = nullptr;
    std::vector<SemanticType> typeArguments;
    std::vector<SemanticType> parameterTypes;
    SemanticType returnType;
};

struct StructFieldSymbol {
    std::string name;
    SemanticType type;
    std::size_t index;
};

struct StructSymbol {
    const StructDecl* declaration;
    std::vector<TypeParameterSymbol> typeParameters;
    std::vector<StructFieldSymbol> fields;
};

struct RuntimeArraySizeCheck {
    const Expr* sizeExpression;
    std::uint64_t literalLength;
};

struct ImportedSymbol {
    std::vector<std::string> modulePath;
    std::string symbolOrWildcard;
    bool isWildcard = false;
};

struct SemanticResult {
    std::vector<Diagnostic> diagnostics;
    std::optional<std::string> moduleName;
    std::vector<ImportedSymbol> importedSymbols;
    std::unordered_map<std::string, StructSymbol> structs;
    std::unordered_map<std::string, FunctionSymbol> functions;
    std::unordered_map<const Expr*, SemanticType> expressionTypes;
    std::unordered_map<const Expr*, SemanticType> sizeofTypes;
    std::unordered_map<const Expr*, SemanticType> implicitConversions;
    std::unordered_map<const CallExpr*, ResolvedCall> resolvedCalls;
    std::vector<SpecializationKey> requestedSpecializations;
    std::unordered_map<const VariableDecl*, SemanticType> declarationTypes;
    std::vector<RuntimeArraySizeCheck> runtimeArraySizeChecks;
};

class SemanticAnalyzer {
public:
    SemanticAnalyzer(const Source& source, const Program& program);
    [[nodiscard]] SemanticResult analyze();

private:
    const Source& source_;
    const Program& program_;
};

}
