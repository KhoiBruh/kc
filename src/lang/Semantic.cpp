#include "lang/Semantic.h"

#include <algorithm>
#include <charconv>
#include <optional>
#include <unordered_map>
#include <utility>

namespace k {
namespace {

std::string spelling(const Source& source, SourceSpan span) {
    return std::string{source.text().substr(span.start, span.end - span.start)};
}

std::optional<GenericConstraint> parseConstraint(std::string_view name) {
    if (name == "any") return GenericConstraint::Any;
    if (name == "comparable") return GenericConstraint::Comparable;
    if (name == "ordered") return GenericConstraint::Ordered;
    if (name == "number") return GenericConstraint::Number;
    if (name == "integer") return GenericConstraint::Integer;
    if (name == "unsigned") return GenericConstraint::Unsigned;
    if (name == "float") return GenericConstraint::Float;
    return std::nullopt;
}

bool constraintProvides(
    GenericConstraint actual, GenericConstraint required) {
    if (required == GenericConstraint::Any || actual == required) return true;
    switch (actual) {
    case GenericConstraint::Unsigned:
        return constraintProvides(GenericConstraint::Integer, required);
    case GenericConstraint::Integer:
    case GenericConstraint::Float:
        return constraintProvides(GenericConstraint::Number, required);
    case GenericConstraint::Number:
        return constraintProvides(GenericConstraint::Ordered, required);
    case GenericConstraint::Ordered:
        return constraintProvides(GenericConstraint::Comparable, required);
    case GenericConstraint::Comparable:
        return required == GenericConstraint::Any;
    case GenericConstraint::Any:
        return false;
    }
    return false;
}

std::string_view constraintName(GenericConstraint constraint) {
    switch (constraint) {
    case GenericConstraint::Any: return "any";
    case GenericConstraint::Comparable: return "comparable";
    case GenericConstraint::Ordered: return "ordered";
    case GenericConstraint::Number: return "number";
    case GenericConstraint::Integer: return "integer";
    case GenericConstraint::Unsigned: return "unsigned";
    case GenericConstraint::Float: return "float";
    }
    return "any";
}

struct VariableSymbol {
    SemanticType type;
    bool mutableBinding;
};

class Analysis {
public:
    Analysis(const Source& source, const Program& program)
        : source_{source}, program_{program} {}

    SemanticResult run() {
        if (program_.module) {
            result_.moduleName = spelling(source_, program_.module->name);
        }
        for (const auto& imp : program_.imports) {
            ImportedSymbol symbol;
            symbol.isWildcard = imp.isWildcard;
            if (imp.isWildcard) {
                for (const auto& part : imp.path) {
                    symbol.modulePath.push_back(spelling(source_, part));
                }
                symbol.symbolOrWildcard = "*";
            } else if (!imp.path.empty()) {
                for (std::size_t i = 0; i < imp.path.size() - 1; ++i) {
                    symbol.modulePath.push_back(spelling(source_, imp.path[i]));
                }
                symbol.symbolOrWildcard = spelling(source_, imp.path.back());
            }
            result_.importedSymbols.push_back(std::move(symbol));
        }
        for (const auto& structure : program_.structs) declareStruct(structure);
        for (const auto& structure : program_.structs) defineStruct(structure);
        for (const auto& function : program_.functions) collect(function);
        for (const auto& function : program_.functions) {
            const auto found = result_.functions.find(spelling(source_, function.name));
            if (found != result_.functions.end() &&
                found->second.declaration == &function) {
                analyzeFunction(function, found->second);
            }
        }
        return std::move(result_);
    }

private:
    SemanticType resolve(const Type& syntax) {
        if (std::holds_alternative<UnitType>(syntax.node)) return {SemanticTypeKind::Unit};
        if (const auto* named = std::get_if<NamedType>(&syntax.node)) {
            if (named->parts.size() != 1) {
                diagnose("qualified types are not supported yet", syntax.span);
                return {};
            }
            const auto name = spelling(source_, named->parts.front());
            if (const auto parameter = typeParameters_.find(name);
                parameter != typeParameters_.end()) {
                SemanticType type{SemanticTypeKind::TypeParameter};
                type.name = name;
                type.typeParameterIndex =
                    static_cast<std::uint32_t>(parameter->second.index);
                return type;
            }
            const std::pair<std::string_view, SemanticTypeKind> primitives[] = {
                {"bool", SemanticTypeKind::Bool}, {"char", SemanticTypeKind::Char},
                {"string", SemanticTypeKind::String}, {"i8", SemanticTypeKind::I8},
                {"i16", SemanticTypeKind::I16}, {"i32", SemanticTypeKind::I32},
                {"i64", SemanticTypeKind::I64}, {"i128", SemanticTypeKind::I128},
                {"u8", SemanticTypeKind::U8}, {"u16", SemanticTypeKind::U16},
                {"u32", SemanticTypeKind::U32}, {"u64", SemanticTypeKind::U64},
                {"u128", SemanticTypeKind::U128}, {"f8", SemanticTypeKind::F8},
                {"f16", SemanticTypeKind::F16}, {"f32", SemanticTypeKind::F32},
                {"f64", SemanticTypeKind::F64},
            };
            for (const auto& [text, kind] : primitives) if (name == text) return {kind};
            if (const auto structure = result_.structs.find(name);
                structure != result_.structs.end()) {
                if (named->arguments.size() !=
                    structure->second.typeParameters.size()) {
                    diagnose("wrong number of struct type arguments", syntax.span);
                    return {};
                }
                std::vector<SemanticType> arguments;
                for (const auto& argument : named->arguments)
                    arguments.push_back(resolve(*argument));
                for (std::size_t i = 0; i < arguments.size(); ++i) {
                    if (!acceptsConstraint(
                            structure->second.typeParameters[i].constraint,
                            arguments[i])) {
                        diagnose("struct type argument does not satisfy constraint",
                                 named->arguments[i]->span);
                    }
                }
                return structType(name, std::move(arguments));
            }
            if (!named->arguments.empty()) {
                diagnose("type does not accept type arguments", syntax.span);
                return {};
            }
            diagnose("type '" + name + "' is not supported yet", syntax.span);
            return {};
        }
        if (const auto* value = std::get_if<NullableType>(&syntax.node))
            return nullableType(resolve(*value->inner));
        if (const auto* value = std::get_if<PointerType>(&syntax.node)) {
            auto pointee = resolve(*value->pointee);
            if (pointee.kind == SemanticTypeKind::TypeParameter)
                diagnose("generic parameter may only be used as T or T?",
                         syntax.span);
            return pointerType(std::move(pointee));
        }
        if (const auto* value = std::get_if<SliceType>(&syntax.node)) {
            auto element = resolve(*value->element);
            if (element.kind == SemanticTypeKind::TypeParameter)
                diagnose("generic parameter may only be used as T or T?",
                         syntax.span);
            return sliceType(std::move(element));
        }
        if (const auto* value = std::get_if<ArrayType>(&syntax.node)) {
            auto element = resolve(*value->element);
            if (element.kind == SemanticTypeKind::TypeParameter)
                diagnose("generic parameter may only be used as T or T?",
                         syntax.span);
            if (!value->size) return inferredArrayType(std::move(element));
            if (const auto* literal = std::get_if<LiteralExpr>(&value->size->node);
                literal && literal->kind == TokenKind::IntegerLiteral) {
                const auto text = spelling(source_, literal->spelling);
                std::uint64_t size{};
                const auto converted = std::from_chars(text.data(), text.data() + text.size(), size);
                if (converted.ec == std::errc{} && converted.ptr == text.data() + text.size())
                    return arrayType(std::move(element), size);
                diagnose("array size must be a valid integer", value->size->span);
                return {};
            }
            return runtimeArrayType(std::move(element));
        }
        diagnose("union types are not supported yet", syntax.span);
        return {};
    }

    void declareStruct(const StructDecl& structure) {
        const auto name = spelling(source_, structure.name);
        if (result_.structs.contains(name)) {
            diagnose("duplicate struct '" + name + "'", structure.name);
            return;
        }
        result_.structs.emplace(name, StructSymbol{&structure, {}, {}});
    }

    void defineStruct(const StructDecl& structure) {
        const auto name = spelling(source_, structure.name);
        const auto found = result_.structs.find(name);
        if (found == result_.structs.end() ||
            found->second.declaration != &structure) return;
        typeParameters_.clear();
        for (std::size_t i = 0; i < structure.typeParameters.size(); ++i) {
            const auto& syntax = structure.typeParameters[i];
            const auto parameterName = spelling(source_, syntax.name);
            if (typeParameters_.contains(parameterName)) {
                diagnose("duplicate type parameter '" + parameterName + "'",
                         syntax.name);
                continue;
            }
            auto constraint = GenericConstraint::Any;
            if (syntax.constraint) {
                const auto text = spelling(source_, *syntax.constraint);
                const auto parsed = parseConstraint(text);
                if (!parsed)
                    diagnose("unknown generic constraint '" + text + "'",
                             *syntax.constraint);
                else
                    constraint = *parsed;
            }
            TypeParameterSymbol symbol{
                parameterName, constraint, found->second.typeParameters.size()};
            typeParameters_.emplace(parameterName, symbol);
            found->second.typeParameters.push_back(std::move(symbol));
        }
        for (std::size_t i = 0; i < structure.fields.size(); ++i) {
            const auto& field = structure.fields[i];
            const auto fieldName = spelling(source_, field.name);
            const auto duplicate = std::find_if(
                found->second.fields.begin(), found->second.fields.end(),
                [&](const StructFieldSymbol& existing) {
                    return existing.name == fieldName;
                });
            if (duplicate != found->second.fields.end()) {
                diagnose("duplicate field '" + fieldName + "'", field.name);
                continue;
            }
            found->second.fields.push_back(
                {fieldName, resolve(*field.type), i});
        }
        typeParameters_.clear();
    }

    void collect(const FunctionDecl& function) {
        const auto name = spelling(source_, function.name);
        if (result_.functions.contains(name)) {
            diagnose("duplicate function '" + name + "'", function.name);
            return;
        }
        typeParameters_.clear();
        std::vector<TypeParameterSymbol> typeParameters;
        for (std::size_t i = 0; i < function.typeParameters.size(); ++i) {
            const auto& syntax = function.typeParameters[i];
            const auto parameterName = spelling(source_, syntax.name);
            if (typeParameters_.contains(parameterName)) {
                diagnose(
                    "duplicate type parameter '" + parameterName + "'",
                    syntax.name);
                continue;
            }
            auto constraint = GenericConstraint::Any;
            if (syntax.constraint) {
                const auto constraintText =
                    spelling(source_, *syntax.constraint);
                const auto parsed = parseConstraint(constraintText);
                if (!parsed) {
                    diagnose(
                        "unknown generic constraint '" + constraintText + "'",
                        *syntax.constraint);
                } else {
                    constraint = *parsed;
                }
            }
            TypeParameterSymbol symbol{
                parameterName, constraint, typeParameters.size()};
            typeParameters_.emplace(parameterName, symbol);
            typeParameters.push_back(std::move(symbol));
        }
        if (function.isExtern && !typeParameters.empty())
            diagnose("extern functions cannot be generic", function.name);
        std::vector<SemanticType> parameters;
        for (const auto& parameter : function.parameters)
            parameters.push_back(resolve(*parameter.type));
        result_.functions.emplace(name, FunctionSymbol{
            &function, std::move(typeParameters), std::move(parameters),
            resolve(*function.returnType)});
        typeParameters_.clear();
    }

    void analyzeFunction(const FunctionDecl& function, const FunctionSymbol& symbol) {
        if (function.isExtern) return;
        scopes_.clear();
        scopes_.emplace_back();
        typeParameters_.clear();
        for (const auto& parameter : symbol.typeParameters)
            typeParameters_.emplace(parameter.name, parameter);
        currentReturn_ = symbol.returnType;
        for (std::size_t i = 0; i < function.parameters.size(); ++i) {
            const auto& parameter = function.parameters[i];
            const auto name = spelling(source_, parameter.name);
            if (scopes_.back().contains(name)) {
                diagnose("duplicate parameter '" + name + "'", parameter.name);
            } else {
                scopes_.back().emplace(name, VariableSymbol{
                    symbol.parameterTypes[i],
                    parameter.mode != ParameterMode::ImmutableBorrow});
            }
        }
        for (const auto& parameter : function.parameters)
            validateRuntimeArraySize(*parameter.type);
        validateRuntimeArraySize(*function.returnType);
        const bool terminates = analyzeBlock(*function.body, false);
        if (currentReturn_.kind != SemanticTypeKind::Unit && !terminates)
            diagnose("non-unit function may reach the end without returning", function.name);
        typeParameters_.clear();
    }

    bool analyzeBlock(const BlockStmt& block, bool nested) {
        if (nested) scopes_.emplace_back();
        bool terminates = false;
        for (const auto& statement : block.statements) {
            const bool current = analyzeStatement(*statement);
            terminates = terminates || current;
        }
        if (nested) scopes_.pop_back();
        return terminates;
    }

    void validateRuntimeArraySize(const Type& type) {
        if (const auto* array = std::get_if<ArrayType>(&type.node)) {
            if (array->size && !std::holds_alternative<LiteralExpr>(array->size->node)) {
                const auto sizeType = analyzeExpr(*array->size);
                if (!isInteger(sizeType))
                    diagnose("runtime array size must be an integer", array->size->span);
            }
            validateRuntimeArraySize(*array->element);
        } else if (const auto* nullable = std::get_if<NullableType>(&type.node)) {
            validateRuntimeArraySize(*nullable->inner);
        } else if (const auto* pointer = std::get_if<PointerType>(&type.node)) {
            validateRuntimeArraySize(*pointer->pointee);
        } else if (const auto* slice = std::get_if<SliceType>(&type.node)) {
            validateRuntimeArraySize(*slice->element);
        }
    }

    bool analyzeStatement(const Stmt& statement) {
        if (const auto* block = std::get_if<BlockStmt>(&statement.node))
            return analyzeBlock(*block, true);
        if (const auto* ifStatement = std::get_if<IfStmt>(&statement.node)) {
            const auto condition = analyzeExpr(*ifStatement->condition);
            if (condition.kind != SemanticTypeKind::Bool)
                diagnose("if condition must be bool", ifStatement->condition->span);
            const bool thenTerminates = analyzeBlock(*ifStatement->thenBranch, true);
            const bool elseTerminates = ifStatement->elseBranch &&
                analyzeBlock(*ifStatement->elseBranch, true);
            return thenTerminates && elseTerminates;
        }
        if (const auto* whileStatement = std::get_if<WhileStmt>(&statement.node)) {
            const auto condition = analyzeExpr(*whileStatement->condition);
            if (condition.kind != SemanticTypeKind::Bool)
                diagnose("while condition must be bool", whileStatement->condition->span);
            analyzeBlock(*whileStatement->body, true);
            return false;
        }
        if (const auto* variable = std::get_if<VariableDecl>(&statement.node)) {
            std::optional<SemanticType> declared;
            if (variable->declaredType) declared = resolve(*variable->declaredType);
            auto initializer = analyzeExpr(*variable->initializer, declared);
            if (!declared && (initializer.kind == SemanticTypeKind::NullLiteral ||
                              (initializer.kind == SemanticTypeKind::Array &&
                               initializer.arraySizeKind == ArraySizeKind::Inferred))) {
                diagnose("cannot infer type from this initializer", variable->initializer->span);
                initializer = {};
            }
            auto type = declared.value_or(initializer);
            if (declared && !compatible(*declared, initializer))
                diagnose("initializer type does not match declared type", variable->initializer->span);
            if (declared && declared->kind == SemanticTypeKind::Array &&
                declared->arraySizeKind == ArraySizeKind::Inferred &&
                initializer.kind == SemanticTypeKind::Array)
                type = initializer;
            result_.declarationTypes[variable] = type;
            if (variable->declaredType) {
                if (const auto* arraySyntax =
                        std::get_if<ArrayType>(&variable->declaredType->node);
                    arraySyntax && arraySyntax->size &&
                    declared->arraySizeKind == ArraySizeKind::Runtime) {
                    const auto sizeType = analyzeExpr(*arraySyntax->size);
                    if (!isInteger(sizeType))
                        diagnose("runtime array size must be an integer", arraySyntax->size->span);
                    if (initializer.kind == SemanticTypeKind::Array &&
                        initializer.arraySizeKind == ArraySizeKind::Known) {
                        result_.runtimeArraySizeChecks.push_back(
                            {arraySyntax->size.get(), initializer.knownArraySize});
                    }
                }
            }
            const auto name = spelling(source_, variable->name);
            if (scopes_.back().contains(name))
                diagnose("duplicate variable '" + name + "'", variable->name);
            else
                scopes_.back().emplace(name, VariableSymbol{
                    type, variable->mode == VariableMode::Var});
            return false;
        }
        if (const auto* value = std::get_if<ReturnStmt>(&statement.node)) {
            if (!value->value) {
                if (currentReturn_.kind != SemanticTypeKind::Unit)
                    diagnose("non-unit function must return a value", statement.span);
            } else if (currentReturn_.kind == SemanticTypeKind::Unit) {
                analyzeExpr(*value->value);
                diagnose("unit function cannot return a value", value->value->span);
            } else {
                const auto type = analyzeExpr(*value->value, currentReturn_);
                if (!compatible(currentReturn_, type))
                    diagnose("return type does not match function return type", value->value->span);
                else if (!(currentReturn_ == type))
                    result_.implicitConversions[value->value.get()] =
                        currentReturn_;
            }
            return true;
        }
        analyzeExpr(*std::get<ExpressionStmt>(statement.node).expression);
        return false;
    }

    SemanticType analyzeExpr(
        const Expr& expression,
        std::optional<SemanticType> expected = std::nullopt) {
        SemanticType type;
        if (const auto* identifier = std::get_if<IdentifierExpr>(&expression.node)) {
            const auto name = spelling(source_, identifier->name);
            if (const auto* variable = findVariable(name)) type = variable->type;
            else {
                diagnose(result_.functions.contains(name)
                    ? "functions cannot be used as values yet"
                    : "unknown identifier '" + name + "'", identifier->name);
            }
        } else if (const auto* literal = std::get_if<LiteralExpr>(&expression.node)) {
            type = literalType(*literal, expected);
        } else if (std::holds_alternative<UnitLiteralExpr>(expression.node)) {
            type = {SemanticTypeKind::Unit};
        } else if (const auto* array = std::get_if<ArrayLiteralExpr>(&expression.node)) {
            type = analyzeArray(*array, expression.span, expected);
        } else if (const auto* size = std::get_if<SizeofExpr>(&expression.node)) {
            result_.sizeofTypes[&expression] = resolve(*size->type);
            type = {SemanticTypeKind::U64};
        } else if (const auto* call = std::get_if<CallExpr>(&expression.node)) {
            type = analyzeCall(*call);
        } else if (const auto* member = std::get_if<MemberExpr>(&expression.node)) {
            type = analyzeMember(*member);
        } else if (const auto* index = std::get_if<IndexExpr>(&expression.node)) {
            type = analyzeIndex(*index);
        } else if (const auto* binary = std::get_if<BinaryExpr>(&expression.node)) {
            auto left = analyzeExpr(*binary->left);
            auto right = analyzeExpr(
                *binary->right,
                std::holds_alternative<LiteralExpr>(binary->right->node) &&
                        isNumeric(left)
                    ? std::optional<SemanticType>{left}
                    : std::nullopt);
            if (std::holds_alternative<LiteralExpr>(binary->left->node) &&
                isNumeric(right))
                left = analyzeExpr(*binary->left, right);
            if (left.kind == SemanticTypeKind::TypeParameter &&
                right.kind == SemanticTypeKind::TypeParameter &&
                left == right) {
                GenericConstraint required = GenericConstraint::Number;
                if (binary->op == TokenKind::EqualEqual ||
                    binary->op == TokenKind::BangEqual)
                    required = GenericConstraint::Comparable;
                if (binary->op == TokenKind::Less ||
                    binary->op == TokenKind::LessEqual ||
                    binary->op == TokenKind::Greater ||
                    binary->op == TokenKind::GreaterEqual)
                    required = GenericConstraint::Ordered;
                const auto parameter = typeParameters_.find(left.name);
                if (parameter != typeParameters_.end() &&
                    !constraintProvides(
                        parameter->second.constraint, required)) {
                    const auto op = binary->op == TokenKind::Less ? "<" :
                        binary->op == TokenKind::LessEqual ? "<=" :
                        binary->op == TokenKind::Greater ? ">" :
                        binary->op == TokenKind::GreaterEqual ? ">=" :
                        binary->op == TokenKind::EqualEqual ? "==" :
                        binary->op == TokenKind::BangEqual ? "!=" :
                        tokenKindName(binary->op);
                    diagnose(
                        "operator '" + std::string{op} +
                            "' requires constraint '" +
                            std::string{constraintName(required)} + "'",
                        expression.span);
                }
                type = required == GenericConstraint::Comparable ||
                               required == GenericConstraint::Ordered
                    ? SemanticType{SemanticTypeKind::Bool}
                    : left;
            } else if (binary->op == TokenKind::AndAnd || binary->op == TokenKind::OrOr) {
                if (left.kind != SemanticTypeKind::Bool || right.kind != SemanticTypeKind::Bool)
                    diagnose("logical operands must be bool", expression.span);
                type = {SemanticTypeKind::Bool};
            } else if (binary->op == TokenKind::EqualEqual || binary->op == TokenKind::BangEqual ||
                       binary->op == TokenKind::Less || binary->op == TokenKind::LessEqual ||
                       binary->op == TokenKind::Greater || binary->op == TokenKind::GreaterEqual) {
                if (!compatible(left, right) && !(isNumeric(left) && isNumeric(right)))
                    diagnose("comparison operands are incompatible", expression.span);
                type = {SemanticTypeKind::Bool};
            } else type = promote(left, right, expression.span);
        } else if (const auto* assignment = std::get_if<AssignmentExpr>(&expression.node)) {
            type = analyzeAssignment(*assignment, expression.span);
        } else if (const auto* unary = std::get_if<UnaryExpr>(&expression.node)) {
            type = analyzeExpr(*unary->operand);
            if (unary->op == TokenKind::Ampersand) {
                const auto* identifier =
                    std::get_if<IdentifierExpr>(&unary->operand->node);
                const auto* variable = identifier
                    ? findVariable(spelling(source_, identifier->name))
                    : nullptr;
                if (!variable || !variable->mutableBinding)
                    diagnose("address-of requires a mutable local",
                             unary->operand->span);
                type = pointerType(type);
            } else if (unary->op == TokenKind::Star) {
                if (type.kind == SemanticTypeKind::Pointer && type.element)
                    type = *type.element;
                else {
                    diagnose("raw pointer dereference requires a pointer",
                             expression.span);
                    type = {};
                }
            } else if (unary->op == TokenKind::Bang) {
                if (type.kind != SemanticTypeKind::Bool) diagnose("'!' requires bool", expression.span);
                type = {SemanticTypeKind::Bool};
            } else if (!isNumeric(type)) diagnose("unary operator requires a number", expression.span);
        } else if (const auto* cast = std::get_if<CastExpr>(&expression.node)) {
            auto from = analyzeExpr(*cast->value);
            type = resolve(*cast->type);
            const bool numericCast = isNumeric(from) && isNumeric(type);
            const bool pointerCast =
                from.kind == SemanticTypeKind::Pointer &&
                type.kind == SemanticTypeKind::Pointer;
            if (!numericCast && !pointerCast)
                diagnose("cast requires numeric types or raw pointers",
                         expression.span);
        } else if (const auto* postfix = std::get_if<PostfixExpr>(&expression.node)) {
            auto value = analyzeExpr(*postfix->value);
            if (postfix->op == TokenKind::Bang && value.kind == SemanticTypeKind::Nullable)
                type = *value.element;
            else {
                diagnose(postfix->op == TokenKind::Question
                    ? "nullable propagation is not supported yet"
                    : "nullable unwrap requires a nullable value", expression.span);
            }
        } else {
            diagnose("member access is not supported yet", expression.span);
        }
        result_.expressionTypes[&expression] = type;
        return type;
    }

    SemanticType literalType(
        const LiteralExpr& literal,
        const std::optional<SemanticType>& expected) {
        if (literal.kind == TokenKind::KwNull)
            return expected && expected->kind == SemanticTypeKind::Nullable
                ? *expected : SemanticType{SemanticTypeKind::NullLiteral};
        if (literal.kind == TokenKind::IntegerLiteral) {
            if (expected && isNumeric(*expected)) return *expected;
            return {SemanticTypeKind::I32};
        }
        if (literal.kind == TokenKind::FloatLiteral) {
            if (expected && isFloat(*expected)) return *expected;
            return {SemanticTypeKind::F64};
        }
        if (literal.kind == TokenKind::KwTrue || literal.kind == TokenKind::KwFalse)
            return {SemanticTypeKind::Bool};
        if (literal.kind == TokenKind::CharLiteral) return {SemanticTypeKind::Char};
        return {SemanticTypeKind::String};
    }

    SemanticType analyzeArray(
        const ArrayLiteralExpr& array,
        SourceSpan span,
        const std::optional<SemanticType>& expected) {
        const SemanticType* elementExpected = expected && expected->kind == SemanticTypeKind::Array
            ? expected->element.get() : nullptr;
        if (array.elements.empty()) {
            if (!elementExpected) {
                return inferredArrayType({});
            }
            return arrayType(*elementExpected, 0);
        }
        auto element = analyzeExpr(*array.elements.front(),
            elementExpected ? std::optional<SemanticType>{*elementExpected} : std::nullopt);
        for (std::size_t i = 1; i < array.elements.size(); ++i) {
            auto next = analyzeExpr(*array.elements[i],
                elementExpected ? std::optional<SemanticType>{*elementExpected} : std::nullopt);
            if (!compatible(element, next)) {
                if (isNumeric(element) && isNumeric(next)) element = promote(element, next, span);
                else diagnose("array elements must have a common type", array.elements[i]->span);
            }
        }
        if (elementExpected) element = *elementExpected;
        return arrayType(std::move(element), array.elements.size());
    }

    bool inferTypeArgument(
        const SemanticType& pattern,
        const SemanticType& actual,
        std::vector<std::optional<SemanticType>>& inferred,
        SourceSpan span) {
        if (pattern.kind == SemanticTypeKind::TypeParameter) {
            const auto index = pattern.typeParameterIndex;
            if (index >= inferred.size()) return false;
            if (!inferred[index]) {
                inferred[index] = actual;
                return true;
            }
            if (!(*inferred[index] == actual)) {
                diagnose(
                    "inconsistent inference for type parameter '" +
                        pattern.name + "'",
                    span);
                return false;
            }
            return true;
        }
        if (pattern.kind == SemanticTypeKind::Nullable &&
            actual.kind == SemanticTypeKind::Nullable &&
            pattern.element && actual.element)
            return inferTypeArgument(
                *pattern.element, *actual.element, inferred, span);
        return true;
    }

    SemanticType substitute(
        const SemanticType& type,
        const std::vector<SemanticType>& arguments) {
        if (type.kind == SemanticTypeKind::TypeParameter) {
            if (type.typeParameterIndex < arguments.size())
                return arguments[type.typeParameterIndex];
            return {};
        }
        if (type.kind == SemanticTypeKind::Struct) {
            auto result = type;
            for (auto& argument : result.typeArguments)
                argument = substitute(argument, arguments);
            return result;
        }
        if (!type.element) return type;
        auto element = substitute(*type.element, arguments);
        if (type.kind == SemanticTypeKind::Nullable)
            return nullableType(std::move(element));
        if (type.kind == SemanticTypeKind::Pointer)
            return pointerType(std::move(element));
        if (type.kind == SemanticTypeKind::Slice)
            return sliceType(std::move(element));
        if (type.kind == SemanticTypeKind::Array) {
            if (type.arraySizeKind == ArraySizeKind::Known)
                return arrayType(
                    std::move(element), type.knownArraySize);
            if (type.arraySizeKind == ArraySizeKind::Runtime)
                return runtimeArrayType(std::move(element));
            return inferredArrayType(std::move(element));
        }
        return type;
    }

    bool acceptsConstraint(
        GenericConstraint constraint,
        const SemanticType& type) const {
        if (type.kind == SemanticTypeKind::TypeParameter) {
            const auto found = typeParameters_.find(type.name);
            return found != typeParameters_.end() &&
                constraintProvides(found->second.constraint, constraint);
        }
        if (type.kind == SemanticTypeKind::Error ||
            type.kind == SemanticTypeKind::Unit ||
            type.kind == SemanticTypeKind::NullLiteral ||
            type.kind == SemanticTypeKind::Nullable)
            return false;
        if (constraint == GenericConstraint::Any) return true;
        if (constraint == GenericConstraint::Float) return isFloat(type);
        if (constraint == GenericConstraint::Unsigned)
            return type.kind >= SemanticTypeKind::U8 &&
                type.kind <= SemanticTypeKind::U128;
        if (constraint == GenericConstraint::Integer)
            return isInteger(type);
        if (constraint == GenericConstraint::Number)
            return isNumeric(type);
        if (constraint == GenericConstraint::Ordered)
            return isNumeric(type) ||
                type.kind == SemanticTypeKind::Char;
        if (constraint == GenericConstraint::Comparable)
            return isNumeric(type) ||
                type.kind == SemanticTypeKind::Bool ||
                type.kind == SemanticTypeKind::Char ||
                type.kind == SemanticTypeKind::String ||
                type.kind == SemanticTypeKind::Pointer;
        return false;
    }

    SemanticType analyzeCall(const CallExpr& call) {
        const auto* identifier = std::get_if<IdentifierExpr>(&call.callee->node);
        if (!identifier) {
            analyzeExpr(*call.callee);
            diagnose("callee must be a function name", call.callee->span);
            for (const auto& argument : call.arguments) analyzeExpr(*argument);
            return {};
        }
        const auto name = spelling(source_, identifier->name);
        if (name == "print") {
            if (call.arguments.size() != 1) {
                diagnose("print expects exactly one argument", call.callee->span);
                for (const auto& argument : call.arguments) analyzeExpr(*argument);
                return {SemanticTypeKind::Unit};
            }
            const auto argument = analyzeExpr(*call.arguments.front());
            if (argument.kind != SemanticTypeKind::String &&
                argument.kind != SemanticTypeKind::I32)
                diagnose("print currently accepts only string or i32", call.arguments.front()->span);
            result_.expressionTypes[call.callee.get()] = {SemanticTypeKind::Unit};
            return {SemanticTypeKind::Unit};
        }
        if (const auto structure = result_.structs.find(name);
            structure != result_.structs.end()) {
            std::vector<SemanticType> typeArguments;
            if (structure->second.typeParameters.empty()) {
                if (!call.typeArguments.empty())
                    diagnose("non-generic struct does not accept type arguments",
                             call.callee->span);
            } else {
                if (call.typeArguments.size() !=
                    structure->second.typeParameters.size()) {
                    diagnose("wrong number of explicit struct type arguments",
                             call.callee->span);
                } else {
                    for (const auto& argument : call.typeArguments)
                        typeArguments.push_back(resolve(*argument));
                }
            }
            if (call.arguments.size() != structure->second.fields.size())
                diagnose("struct argument count does not match", call.callee->span);
            for (std::size_t i = 0; i < call.arguments.size(); ++i) {
                const auto expected = i < structure->second.fields.size()
                    ? std::optional<SemanticType>{substitute(
                        structure->second.fields[i].type, typeArguments)}
                    : std::nullopt;
                const auto actual = analyzeExpr(*call.arguments[i], expected);
                if (expected && !compatible(*expected, actual))
                    diagnose("struct field argument has the wrong type",
                             call.arguments[i]->span);
            }
            const auto type = structType(name, std::move(typeArguments));
            result_.expressionTypes[call.callee.get()] = type;
            return type;
        }
        const auto function = result_.functions.find(name);
        if (function == result_.functions.end()) {
            if (findVariable(name)) diagnose("a variable cannot be called", identifier->name);
            else diagnose("unknown function '" + name + "'", identifier->name);
            for (const auto& argument : call.arguments) analyzeExpr(*argument);
            return {};
        }
        if (!function->second.typeParameters.empty()) {
            const auto& symbol = function->second;
            std::vector<SemanticType> typeArguments;
            if (!call.typeArguments.empty()) {
                if (call.typeArguments.size() !=
                    symbol.typeParameters.size()) {
                    diagnose(
                        "wrong number of explicit type arguments",
                        call.callee->span);
                    for (const auto& argument : call.arguments)
                        analyzeExpr(*argument);
                    return {};
                }
                for (const auto& argument : call.typeArguments)
                    typeArguments.push_back(resolve(*argument));
            }

            std::vector<std::optional<SemanticType>> inferred(
                symbol.typeParameters.size());
            if (!typeArguments.empty()) {
                for (std::size_t i = 0; i < typeArguments.size(); ++i)
                    inferred[i] = typeArguments[i];
            }

            std::vector<SemanticType> actualTypes;
            actualTypes.reserve(call.arguments.size());
            bool inferenceOk = true;
            for (std::size_t i = 0; i < call.arguments.size(); ++i) {
                std::optional<SemanticType> expected;
                if (!typeArguments.empty() &&
                    i < symbol.parameterTypes.size())
                    expected = substitute(
                        symbol.parameterTypes[i], typeArguments);
                auto actual = analyzeExpr(*call.arguments[i], expected);
                actualTypes.push_back(actual);
                if (typeArguments.empty() &&
                    i < symbol.parameterTypes.size())
                    inferenceOk = inferTypeArgument(
                        symbol.parameterTypes[i], actual, inferred,
                        call.arguments[i]->span) && inferenceOk;
            }

            if (call.arguments.size() != symbol.parameterTypes.size())
                diagnose(
                    "function argument count does not match",
                    call.callee->span);

            if (typeArguments.empty()) {
                for (std::size_t i = 0; i < inferred.size(); ++i) {
                    if (!inferred[i]) {
                        diagnose(
                            "unable to infer type parameter '" +
                                symbol.typeParameters[i].name + "'",
                            call.callee->span);
                        inferenceOk = false;
                        typeArguments.push_back({});
                    } else {
                        typeArguments.push_back(*inferred[i]);
                    }
                }
            }

            for (std::size_t i = 0;
                 i < typeArguments.size() &&
                 i < symbol.typeParameters.size();
                 ++i) {
                if (!inferenceOk) break;
                if (!acceptsConstraint(
                        symbol.typeParameters[i].constraint,
                        typeArguments[i])) {
                    diagnose(
                        "type '" + semanticTypeName(typeArguments[i]) +
                            "' does not satisfy constraint '" +
                            std::string{constraintName(
                                symbol.typeParameters[i].constraint)} +
                            "'",
                        call.callee->span);
                    inferenceOk = false;
                }
            }

            std::vector<SemanticType> parameterTypes;
            parameterTypes.reserve(symbol.parameterTypes.size());
            for (const auto& parameter : symbol.parameterTypes)
                parameterTypes.push_back(
                    substitute(parameter, typeArguments));
            for (std::size_t i = 0;
                 i < actualTypes.size() && i < parameterTypes.size();
                 ++i) {
                if (!inferenceOk) break;
                if (!compatible(parameterTypes[i], actualTypes[i]))
                    diagnose(
                        "argument type does not match parameter type",
                        call.arguments[i]->span);
            }
            auto returnType =
                substitute(symbol.returnType, typeArguments);
            result_.resolvedCalls.emplace(
                &call,
                ResolvedCall{
                    &symbol, typeArguments, parameterTypes, returnType});
            result_.expressionTypes[call.callee.get()] = returnType;
            if (inferenceOk && typeParameters_.empty()) {
                const SpecializationKey key{
                    symbol.declaration, typeArguments};
                if (std::find(
                        result_.requestedSpecializations.begin(),
                        result_.requestedSpecializations.end(),
                        key) ==
                    result_.requestedSpecializations.end())
                    result_.requestedSpecializations.push_back(key);
            }
            return returnType;
        }
        if (!call.typeArguments.empty()) {
            diagnose(
                "non-generic function does not accept type arguments",
                call.callee->span);
        }
        if (call.arguments.size() != function->second.parameterTypes.size())
            diagnose("function argument count does not match", call.callee->span);
        for (std::size_t i = 0; i < call.arguments.size(); ++i) {
            const auto expected = i < function->second.parameterTypes.size()
                ? std::optional<SemanticType>{function->second.parameterTypes[i]} : std::nullopt;
            const auto actual = analyzeExpr(*call.arguments[i], expected);
            if (expected && !compatible(*expected, actual))
                diagnose("argument type does not match parameter type", call.arguments[i]->span);
            if (i < function->second.declaration->parameters.size() &&
                function->second.declaration->parameters[i].mode ==
                    ParameterMode::MutableBorrow) {
                const auto* identifier =
                    std::get_if<IdentifierExpr>(&call.arguments[i]->node);
                const auto* variable = identifier
                    ? findVariable(spelling(source_, identifier->name))
                    : nullptr;
                if (!variable || !variable->mutableBinding)
                    diagnose("var argument must be a mutable local",
                             call.arguments[i]->span);
            }
        }
        result_.expressionTypes[call.callee.get()] = function->second.returnType;
        return function->second.returnType;
    }

    SemanticType analyzeMember(const MemberExpr& member) {
        const auto objectType = analyzeExpr(*member.object);
        if (objectType.kind != SemanticTypeKind::Struct) {
            diagnose("member access requires a struct value", member.object->span);
            return {};
        }
        const auto structure = result_.structs.find(objectType.name);
        if (structure == result_.structs.end()) return {};
        const auto name = spelling(source_, member.name);
        const auto field = std::find_if(
            structure->second.fields.begin(), structure->second.fields.end(),
            [&](const StructFieldSymbol& candidate) {
                return candidate.name == name;
            });
        if (field == structure->second.fields.end()) {
            diagnose("unknown field '" + name + "'", member.name);
            return {};
        }
        return substitute(field->type, objectType.typeArguments);
    }

    SemanticType analyzeIndex(const IndexExpr& index) {
        const auto objectType = analyzeExpr(*index.object);
        const auto indexType = analyzeExpr(*index.index);
        if (!isInteger(indexType))
            diagnose("index must be an integer", index.index->span);
        if (objectType.kind != SemanticTypeKind::Array &&
            objectType.kind != SemanticTypeKind::Slice &&
            objectType.kind != SemanticTypeKind::Pointer) {
            diagnose("indexing requires an array, slice, or raw pointer",
                     index.object->span);
            return {};
        }
        if (objectType.kind == SemanticTypeKind::Array &&
            objectType.arraySizeKind == ArraySizeKind::Known) {
            if (const auto* literal =
                    std::get_if<LiteralExpr>(&index.index->node);
                literal && literal->kind == TokenKind::IntegerLiteral) {
                const auto text = spelling(source_, literal->spelling);
                std::uint64_t value{};
                const auto parsed =
                    std::from_chars(text.data(), text.data() + text.size(), value);
                if (parsed.ec == std::errc{} &&
                    parsed.ptr == text.data() + text.size() &&
                    value >= objectType.knownArraySize) {
                    diagnose("constant index is out of bounds", index.index->span);
                }
            }
        }
        return objectType.element ? *objectType.element : SemanticType{};
    }

    SemanticType analyzeAssignment(const AssignmentExpr& assignment, SourceSpan span) {
        const auto* identifier = std::get_if<IdentifierExpr>(&assignment.target->node);
        if (const auto* member = std::get_if<MemberExpr>(&assignment.target->node)) {
            const auto targetType = analyzeMember(*member);
            const auto* object =
                std::get_if<IdentifierExpr>(&member->object->node);
            if (!object) {
                analyzeExpr(*assignment.value);
                diagnose("field assignment requires a local struct",
                         member->object->span);
                return {};
            }
            const auto name = spelling(source_, object->name);
            auto* variable = findVariable(name);
            if (!variable) {
                analyzeExpr(*assignment.value);
                return {};
            }
            if (!variable->mutableBinding &&
                variable->type.kind != SemanticTypeKind::Pointer)
                diagnose("cannot assign through immutable binding", object->name);
            const auto value = analyzeExpr(*assignment.value, targetType);
            if (!compatible(targetType, value))
                diagnose("assigned value has the wrong type",
                         assignment.value->span);
            return targetType;
        }
        if (const auto* index =
                std::get_if<IndexExpr>(&assignment.target->node)) {
            const auto targetType = analyzeIndex(*index);
            const auto objectType =
                result_.expressionTypes.find(index->object.get());
            if (objectType != result_.expressionTypes.end() &&
                objectType->second.kind == SemanticTypeKind::Pointer) {
                const auto value = analyzeExpr(*assignment.value, targetType);
                if (!compatible(targetType, value))
                    diagnose("assigned value has the wrong type",
                             assignment.value->span);
                return targetType;
            }
            const auto* object =
                std::get_if<IdentifierExpr>(&index->object->node);
            if (!object) {
                analyzeExpr(*assignment.value);
                diagnose("indexed assignment requires a local collection",
                         index->object->span);
                return {};
            }
            const auto name = spelling(source_, object->name);
            auto* variable = findVariable(name);
            if (!variable) {
                analyzeExpr(*assignment.value);
                return {};
            }
            if (!variable->mutableBinding &&
                variable->type.kind != SemanticTypeKind::Pointer)
                diagnose("cannot assign through immutable binding", object->name);
            const auto value = analyzeExpr(*assignment.value, targetType);
            if (!compatible(targetType, value))
                diagnose("assigned value has the wrong type",
                         assignment.value->span);
            return targetType;
        }
        if (const auto* unary =
                std::get_if<UnaryExpr>(&assignment.target->node);
            unary && unary->op == TokenKind::Star) {
            const auto targetType = analyzeExpr(*assignment.target);
            const auto value = analyzeExpr(*assignment.value, targetType);
            if (!compatible(targetType, value))
                diagnose("assigned value has the wrong type",
                         assignment.value->span);
            return targetType;
        }
        if (!identifier) {
            analyzeExpr(*assignment.target);
            analyzeExpr(*assignment.value);
            diagnose("assignment target must be an identifier", assignment.target->span);
            return {};
        }
        const auto name = spelling(source_, identifier->name);
        auto* variable = findVariable(name);
        if (!variable) {
            diagnose("unknown identifier '" + name + "'", identifier->name);
            analyzeExpr(*assignment.value);
            return {};
        }
        result_.expressionTypes[assignment.target.get()] = variable->type;
        if (!variable->mutableBinding) diagnose("cannot assign to immutable binding", identifier->name);
        auto value = analyzeExpr(*assignment.value, variable->type);
        if (assignment.op == TokenKind::Equal) {
            if (!compatible(variable->type, value))
                diagnose("assigned value has the wrong type", assignment.value->span);
        } else {
            const auto combined = promote(variable->type, value, span);
            if (!(combined == variable->type))
                diagnose("compound assignment changes the target type", span);
        }
        return variable->type;
    }

    SemanticType promote(const SemanticType& left, const SemanticType& right, SourceSpan span) {
        if (!isNumeric(left) || !isNumeric(right)) {
            diagnose("arithmetic operands must be numbers", span);
            return {};
        }
        if (isFloat(left) || isFloat(right)) {
            const auto width = std::max(numericBitWidth(left), numericBitWidth(right));
            return {width <= 32 ? SemanticTypeKind::F32 : SemanticTypeKind::F64};
        }
        const auto width = std::max(numericBitWidth(left), numericBitWidth(right));
        if (isSignedInteger(left) == isSignedInteger(right))
            return integerType(width, isSignedInteger(left));
        const auto signedWidth = isSignedInteger(left) ? numericBitWidth(left) : numericBitWidth(right);
        const auto unsignedWidth = isSignedInteger(left) ? numericBitWidth(right) : numericBitWidth(left);
        if (signedWidth > unsignedWidth) return integerType(signedWidth, true);
        if (width < 128) return integerType(width * 2, true);
        diagnose("mixed signed arithmetic requires an explicit cast", span);
        return {};
    }

    SemanticType integerType(std::uint32_t width, bool signedValue) {
        if (signedValue) {
            if (width <= 8) return {SemanticTypeKind::I8};
            if (width <= 16) return {SemanticTypeKind::I16};
            if (width <= 32) return {SemanticTypeKind::I32};
            if (width <= 64) return {SemanticTypeKind::I64};
            return {SemanticTypeKind::I128};
        }
        if (width <= 8) return {SemanticTypeKind::U8};
        if (width <= 16) return {SemanticTypeKind::U16};
        if (width <= 32) return {SemanticTypeKind::U32};
        if (width <= 64) return {SemanticTypeKind::U64};
        return {SemanticTypeKind::U128};
    }

    bool compatible(const SemanticType& expected, const SemanticType& actual) const {
        if (expected.kind == SemanticTypeKind::Error || actual.kind == SemanticTypeKind::Error)
            return true;
        if (actual.kind == SemanticTypeKind::NullLiteral)
            return expected.kind == SemanticTypeKind::Nullable;
        if (expected.kind == SemanticTypeKind::Nullable &&
            expected.element && *expected.element == actual)
            return true;
        if (expected.kind == SemanticTypeKind::Array && actual.kind == SemanticTypeKind::Array &&
            expected.element && actual.element && *expected.element == *actual.element) {
            return expected.arraySizeKind != ArraySizeKind::Known ||
                actual.arraySizeKind != ArraySizeKind::Known ||
                expected.knownArraySize == actual.knownArraySize;
        }
        if (expected.kind == SemanticTypeKind::Slice &&
            actual.kind == SemanticTypeKind::Array &&
            expected.element && actual.element)
            return *expected.element == *actual.element;
        return expected == actual;
    }

    VariableSymbol* findVariable(const std::string& name) {
        for (auto scope = scopes_.rbegin(); scope != scopes_.rend(); ++scope) {
            const auto found = scope->find(name);
            if (found != scope->end()) return &found->second;
        }
        return nullptr;
    }

    void diagnose(std::string message, SourceSpan span) {
        result_.diagnostics.push_back({std::move(message), span});
    }

    const Source& source_;
    const Program& program_;
    SemanticResult result_;
    std::vector<std::unordered_map<std::string, VariableSymbol>> scopes_;
    std::unordered_map<std::string, TypeParameterSymbol> typeParameters_;
    SemanticType currentReturn_;
};

}

SemanticAnalyzer::SemanticAnalyzer(const Source& source, const Program& program)
    : source_{source}, program_{program} {}

SemanticResult SemanticAnalyzer::analyze() {
    return Analysis{source_, program_}.run();
}

}
