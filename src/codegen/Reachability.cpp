#include "codegen/Reachability.h"

#include "lang/Source.h"

#include <unordered_map>
#include <vector>

namespace k {

namespace {

std::string spelling(const Source& source, SourceSpan span) {
    return std::string{source.text().substr(span.start, span.end - span.start)};
}

class DependencyCollector {
public:
    explicit DependencyCollector(const std::vector<ParsedModule>& modules)
        : modules_{modules} {
        for (std::size_t i = 0; i < modules_.size(); ++i) {
            const auto& program = *modules_[i].program;
            const auto& semantic = *modules_[i].semantic;
            for (const auto& function : program.functions) owner_[&function] = i;
            for (const auto& structure : program.structs) {
                owner_[&structure] = i;
                for (const auto& method : structure.methods)
                    owner_[&method] = i;
            }
            for (const auto& enumeration : program.enums)
                owner_[&enumeration] = i;
            for (const auto& constant : program.constants)
                owner_[&constant] = i;
            for (const auto& [name, symbol] : semantic.functions)
                functionSymbols_.emplace(symbol.declaration, &symbol);
            for (const auto& [name, symbol] : semantic.structs)
                structSymbols_.emplace(symbol.declaration, &symbol);
            for (const auto& [name, symbol] : semantic.enums)
                enumSymbols_.emplace(symbol.declaration, &symbol);
            for (const auto& [name, symbol] : semantic.constants)
                constantSymbols_.emplace(symbol.declaration, &symbol);
        }
    }

    ReachableDeclarations compute() {
        ReachableDeclarations result;
        const FunctionDecl* entry = nullptr;
        for (const auto& module : modules_) {
            const auto found = module.semantic->functions.find("main");
            if (found != module.semantic->functions.end() &&
                !found->second.declaration->isExtern) {
                entry = found->second.declaration;
                break;
            }
        }
        if (!entry) return result;

        result.filtered = true;
        std::vector<const void*> worklist{entry};
        while (!worklist.empty()) {
            const void* declaration = worklist.back();
            worklist.pop_back();
            if (!visited_.insert(declaration).second) continue;
            visit(declaration, worklist, result);
        }
        return result;
    }

private:
    const SemanticResult& semanticOf(const void* declaration) const {
        return *modules_[owner_.at(declaration)].semantic;
    }

    const Source& sourceOf(const void* declaration) const {
        return *modules_[owner_.at(declaration)].source;
    }

    void visit(const void* declaration,
               std::vector<const void*>& worklist,
               ReachableDeclarations& result) {
        if (const auto* function =
                static_cast<const FunctionDecl*>(declaration);
            functionSymbols_.count(function) != 0) {
            result.functions.insert(function);
            visitFunction(function, worklist);
            return;
        }
        if (const auto* structure =
                static_cast<const StructDecl*>(declaration);
            structSymbols_.count(structure) != 0) {
            result.structs.insert(structure);
            visitStruct(structure, worklist);
            return;
        }
        if (const auto* enumeration =
                static_cast<const EnumDecl*>(declaration);
            enumSymbols_.count(enumeration) != 0) {
            result.enums.insert(enumeration);
            return;
        }
        if (const auto* constant =
                static_cast<const ConstantDecl*>(declaration);
            constantSymbols_.count(constant) != 0) {
            result.constants.insert(constant);
            visitConstant(constant, worklist);
        }
    }

    void visitFunction(const FunctionDecl* function,
                       std::vector<const void*>& worklist) {
        const auto& semantic = semanticOf(function);
        const auto found = functionSymbols_.find(function);
        if (found == functionSymbols_.end()) return;
        for (const auto& type : found->second->parameterTypes)
            addType(type, semantic, worklist);
        addType(found->second->returnType, semantic, worklist);
        for (const auto& specialization : semantic.requestedSpecializations) {
            if (specialization.declaration != function) continue;
            for (const auto& argument : specialization.typeArguments)
                addType(argument, semantic, worklist);
        }
        if (function->body) {
            const auto& source = sourceOf(function);
            for (const auto& statement : function->body->statements)
                visitStatement(*statement, source, semantic, worklist);
        }
    }

    void visitStruct(const StructDecl* structure,
                     std::vector<const void*>& worklist) {
        const auto found = structSymbols_.find(structure);
        if (found == structSymbols_.end()) return;
        for (const auto& field : found->second->fields)
            addType(field.type, semanticOf(structure), worklist);
        for (const auto& method : structure->methods)
            worklist.push_back(&method);
    }

void visitConstant(const ConstantDecl* constant,
                       std::vector<const void*>& worklist) {
        const auto& semantic = semanticOf(constant);
        const auto& source = sourceOf(constant);
        const auto found = constantSymbols_.find(constant);
        if (found == constantSymbols_.end()) return;
        addType(found->second->type, semantic, worklist);
        if (constant->initializer)
            visitExpr(*constant->initializer, source, semantic, worklist);
    }

    void addType(const SemanticType& type, const SemanticResult& semantic,
                 std::vector<const void*>& worklist) {
        if (type.kind == SemanticTypeKind::Struct) {
            if (const auto found = semantic.structs.find(type.name);
                found != semantic.structs.end())
                worklist.push_back(found->second.declaration);
        } else if (type.kind == SemanticTypeKind::Enum) {
            if (const auto found = semantic.enums.find(type.name);
                found != semantic.enums.end())
                worklist.push_back(found->second.declaration);
        }
        if (type.element) addType(*type.element, semantic, worklist);
        for (const auto& argument : type.typeArguments)
            addType(argument, semantic, worklist);
    }

    void visitStatement(const Stmt& statement, const Source& source,
                        const SemanticResult& semantic,
                        std::vector<const void*>& worklist) {
        if (const auto* block = std::get_if<BlockStmt>(&statement.node)) {
            for (const auto& child : block->statements)
                visitStatement(*child, source, semantic, worklist);
        } else if (const auto* ifStatement =
                       std::get_if<IfStmt>(&statement.node)) {
            visitExpr(*ifStatement->condition, source, semantic, worklist);
            if (ifStatement->thenBranch)
                for (const auto& child : ifStatement->thenBranch->statements)
                    visitStatement(*child, source, semantic, worklist);
            if (ifStatement->elseBranch)
                for (const auto& child : ifStatement->elseBranch->statements)
                    visitStatement(*child, source, semantic, worklist);
        } else if (const auto* whileStatement =
                       std::get_if<WhileStmt>(&statement.node)) {
            visitExpr(*whileStatement->condition, source, semantic, worklist);
            if (whileStatement->body)
                for (const auto& child : whileStatement->body->statements)
                    visitStatement(*child, source, semantic, worklist);
        } else if (const auto* forStatement =
                       std::get_if<ForStmt>(&statement.node)) {
            visitExpr(*forStatement->collection, source, semantic, worklist);
            if (forStatement->body)
                for (const auto& child : forStatement->body->statements)
                    visitStatement(*child, source, semantic, worklist);
        } else if (const auto* whenStatement =
                       std::get_if<WhenStmt>(&statement.node)) {
            if (whenStatement->subject)
                visitExpr(*whenStatement->subject, source, semantic, worklist);
            for (const auto& branch : whenStatement->branches) {
                for (const auto& condition : branch.conditions)
                    visitExpr(*condition, source, semantic, worklist);
                if (branch.body)
                    for (const auto& child : branch.body->statements)
                        visitStatement(*child, source, semantic, worklist);
            }
        } else if (const auto* variable =
                       std::get_if<VariableDecl>(&statement.node)) {
            if (const auto found = semantic.declarationTypes.find(variable);
                found != semantic.declarationTypes.end())
                addType(found->second, semantic, worklist);
            if (variable->initializer)
                visitExpr(*variable->initializer, source, semantic, worklist);
        } else if (const auto* returnStatement =
                       std::get_if<ReturnStmt>(&statement.node)) {
            if (returnStatement->value)
                visitExpr(*returnStatement->value, source, semantic, worklist);
        } else if (const auto* expression =
                       std::get_if<ExpressionStmt>(&statement.node)) {
            visitExpr(*expression->expression, source, semantic, worklist);
        } else if (const auto* defer = std::get_if<DeferStmt>(&statement.node)) {
            visitStatement(*defer->statement, source, semantic, worklist);
        }
    }

    void visitExpr(const Expr& expression, const Source& source,
                   const SemanticResult& semantic,
                   std::vector<const void*>& worklist) {
        if (const auto found = semantic.expressionTypes.find(&expression);
            found != semantic.expressionTypes.end())
            addType(found->second, semantic, worklist);
        if (const auto found = semantic.sizeofTypes.find(&expression);
            found != semantic.sizeofTypes.end())
            addType(found->second, semantic, worklist);
        if (const auto* call = std::get_if<CallExpr>(&expression.node)) {
            const auto resolved = semantic.resolvedCalls.find(call);
            if (resolved != semantic.resolvedCalls.end() &&
                resolved->second.declaration != nullptr) {
                worklist.push_back(resolved->second.declaration);
                for (const auto& argument : resolved->second.typeArguments)
                    addType(argument, semantic, worklist);
            } else if (const auto* callee =
                           std::get_if<IdentifierExpr>(&call->callee->node)) {
                const auto name = spelling(source, callee->name);
                const auto structure = semantic.structs.find(name);
                if (structure != semantic.structs.end()) {
                    worklist.push_back(structure->second.declaration);
                } else {
                    const auto function = semantic.functions.find(name);
                    if (function != semantic.functions.end())
                        worklist.push_back(function->second.declaration);
                }
            }
            for (const auto& argument : call->arguments)
                visitExpr(*argument, source, semantic, worklist);
        } else if (const auto* member =
                       std::get_if<MemberExpr>(&expression.node)) {
            if (semantic.enumVariantIndices.find(member) !=
                semantic.enumVariantIndices.end()) {
                if (const auto found =
                        semantic.expressionTypes.find(&expression);
                    found != semantic.expressionTypes.end() &&
                    found->second.kind == SemanticTypeKind::Enum)
                    addType(found->second, semantic, worklist);
            }
            visitExpr(*member->object, source, semantic, worklist);
        } else if (const auto* identifier =
                       std::get_if<IdentifierExpr>(&expression.node)) {
            const auto name = spelling(source, identifier->name);
            if (const auto found = semantic.constants.find(name);
                found != semantic.constants.end())
                worklist.push_back(found->second.declaration);
        } else if (const auto* unary =
                       std::get_if<UnaryExpr>(&expression.node)) {
            visitExpr(*unary->operand, source, semantic, worklist);
        } else if (const auto* binary =
                       std::get_if<BinaryExpr>(&expression.node)) {
            visitExpr(*binary->left, source, semantic, worklist);
            visitExpr(*binary->right, source, semantic, worklist);
        } else if (const auto* assignment =
                       std::get_if<AssignmentExpr>(&expression.node)) {
            visitExpr(*assignment->target, source, semantic, worklist);
            visitExpr(*assignment->value, source, semantic, worklist);
        } else if (const auto* cast =
                       std::get_if<CastExpr>(&expression.node)) {
            visitExpr(*cast->value, source, semantic, worklist);
        } else if (const auto* index =
                       std::get_if<IndexExpr>(&expression.node)) {
            visitExpr(*index->object, source, semantic, worklist);
            visitExpr(*index->index, source, semantic, worklist);
        } else if (const auto* postfix =
                       std::get_if<PostfixExpr>(&expression.node)) {
            visitExpr(*postfix->value, source, semantic, worklist);
        } else if (const auto* array =
                       std::get_if<ArrayLiteralExpr>(&expression.node)) {
            for (const auto& element : array->elements)
                visitExpr(*element, source, semantic, worklist);
        } else if (const auto* when =
                       std::get_if<WhenExpr>(&expression.node)) {
            if (when->subject) visitExpr(*when->subject, source, semantic, worklist);
            for (const auto& branch : when->branches) {
                for (const auto& condition : branch.conditions)
                    visitExpr(*condition, source, semantic, worklist);
                if (branch.body)
                    for (const auto& child : branch.body->statements)
                        visitStatement(*child, source, semantic, worklist);
                if (branch.value) visitExpr(*branch.value, source, semantic, worklist);
            }
        } else if (const auto* ifExpression =
                       std::get_if<IfExpr>(&expression.node)) {
            visitExpr(*ifExpression->condition, source, semantic, worklist);
            if (ifExpression->thenBranch.body)
                for (const auto& child :
                     ifExpression->thenBranch.body->statements)
                    visitStatement(*child, source, semantic, worklist);
            if (ifExpression->thenBranch.value)
                visitExpr(*ifExpression->thenBranch.value, source, semantic, worklist);
            if (ifExpression->elseBranch.body)
                for (const auto& child :
                     ifExpression->elseBranch.body->statements)
                    visitStatement(*child, source, semantic, worklist);
            if (ifExpression->elseBranch.value)
                visitExpr(*ifExpression->elseBranch.value, source, semantic, worklist);
        }
    }

    const std::vector<ParsedModule>& modules_;
    std::unordered_map<const void*, std::size_t> owner_;
    std::unordered_map<const FunctionDecl*, const FunctionSymbol*>
        functionSymbols_;
    std::unordered_map<const StructDecl*, const StructSymbol*> structSymbols_;
    std::unordered_map<const EnumDecl*, const EnumSymbol*> enumSymbols_;
    std::unordered_map<const ConstantDecl*, const ConstantSymbol*>
        constantSymbols_;
    std::unordered_set<const void*> visited_;
};

}

ReachableDeclarations computeReachable(
    const std::vector<ParsedModule>& modules) {
    return DependencyCollector{modules}.compute();
}

}
