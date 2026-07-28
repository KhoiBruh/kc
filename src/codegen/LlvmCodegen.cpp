#include "codegen/LlvmCodegen.h"

#include <llvm/IR/Constants.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Verifier.h>
#include <llvm/Support/raw_ostream.h>

#include <algorithm>
#include <charconv>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>

namespace k {
namespace {

std::string spelling(const Source& source, SourceSpan span) {
    return std::string{source.text().substr(span.start, span.end - span.start)};
}

void appendUtf8(std::string& output, std::uint32_t value) {
    if (value <= 0x7f) output.push_back(static_cast<char>(value));
    else if (value <= 0x7ff) {
        output.push_back(static_cast<char>(0xc0 | (value >> 6)));
        output.push_back(static_cast<char>(0x80 | (value & 0x3f)));
    } else if (value <= 0xffff) {
        output.push_back(static_cast<char>(0xe0 | (value >> 12)));
        output.push_back(static_cast<char>(0x80 | ((value >> 6) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | (value & 0x3f)));
    } else {
        output.push_back(static_cast<char>(0xf0 | (value >> 18)));
        output.push_back(static_cast<char>(0x80 | ((value >> 12) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | ((value >> 6) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | (value & 0x3f)));
    }
}

std::string decodeStringLiteral(std::string_view spelling) {
    std::string output;
    for (std::size_t index = 1; index + 1 < spelling.size(); ++index) {
        if (spelling[index] != '\\') {
            output.push_back(spelling[index]);
            continue;
        }
        const auto escaped = spelling[++index];
        if (escaped == 'n') output.push_back('\n');
        else if (escaped == 'r') output.push_back('\r');
        else if (escaped == 't') output.push_back('\t');
        else if (escaped == '0') output.push_back('\0');
        else if (escaped == '\\' || escaped == '"' || escaped == '\'' ||
                 escaped == '$') output.push_back(escaped);
        else {
            index += 2;
            std::uint32_t value = 0;
            while (spelling[index] != '}') {
                const auto digit = spelling[index++];
                value = value * 16 + static_cast<std::uint32_t>(
                    digit >= '0' && digit <= '9' ? digit - '0'
                    : digit >= 'a' && digit <= 'f' ? digit - 'a' + 10
                                                   : digit - 'A' + 10);
            }
            appendUtf8(output, value);
        }
    }
    return output;
}

class Generator {
public:
    const Source& source() const { return *current_->source; }
    const SemanticResult& semantic() const { return *current_->semantic; }
    const Program& program() const { return *current_->program; }
    Generator(
        std::vector<ParsedModule> modules,
        llvm::LLVMContext& context)
        : modules_{std::move(modules)},
          context_{context},
          builder_{context} {
        const auto& entry = modules_.back();
        result_.module = std::make_unique<llvm::Module>(
            std::string{entry.source->path()}, context_);
    }

    CodegenResult run() {
        for (auto& module : modules_) {
            current_ = &module;
            declareStructs();
        }
        for (auto& module : modules_) {
            current_ = &module;
            declareFunctions();
        }
        for (auto& module : modules_) {
            current_ = &module;
            for (const auto& specialization :
                 current_->semantic->requestedSpecializations)
                getOrDeclareSpecialization(specialization);
        }
        if (result_.diagnostics.empty()) {
            for (auto& module : modules_) {
                current_ = &module;
                for (const auto& function : current_->program->functions)
                    emitFunction(function);
            }
            std::size_t next = 0;
            while (next < pendingSpecializations_.size()) {
                const auto item = pendingSpecializations_[next++];
                emitFunctionBody(
                    *item.declaration, item.function,
                    item.typeArguments);
            }
        }
        if (result_.diagnostics.empty()) verify();
        if (!result_.diagnostics.empty()) result_.module.reset();
        return std::move(result_);
    }

private:
    struct PendingSpecialization {
        const FunctionDecl* declaration;
        std::vector<SemanticType> typeArguments;
        llvm::Function* function;
    };

    struct LocalSlot {
        llvm::Value* address;
        llvm::Type* type;
    };

    llvm::Type* lowerType(const SemanticType& type, SourceSpan span, bool returnType = false) {
        if (type.kind == SemanticTypeKind::TypeParameter) {
            if (type.typeParameterIndex < activeTypeArguments_.size())
                return lowerType(
                    activeTypeArguments_[type.typeParameterIndex],
                    span, returnType);
            diagnose(
                "unresolved generic type reached LLVM backend", span);
            return nullptr;
        }
        switch (type.kind) {
        case SemanticTypeKind::Unit:
            if (returnType) return llvm::Type::getVoidTy(context_);
            break;
        case SemanticTypeKind::Bool: return llvm::Type::getInt1Ty(context_);
        case SemanticTypeKind::I8:
        case SemanticTypeKind::U8: return llvm::Type::getInt8Ty(context_);
        case SemanticTypeKind::I16:
        case SemanticTypeKind::U16: return llvm::Type::getInt16Ty(context_);
        case SemanticTypeKind::I32:
        case SemanticTypeKind::U32:
        case SemanticTypeKind::Enum: return llvm::Type::getInt32Ty(context_);
        case SemanticTypeKind::I64:
        case SemanticTypeKind::U64: return llvm::Type::getInt64Ty(context_);
        case SemanticTypeKind::I128:
        case SemanticTypeKind::U128: return llvm::Type::getInt128Ty(context_);
        case SemanticTypeKind::F32: return llvm::Type::getFloatTy(context_);
        case SemanticTypeKind::F64: return llvm::Type::getDoubleTy(context_);
        case SemanticTypeKind::Pointer:
            return llvm::PointerType::getUnqual(context_);
        case SemanticTypeKind::String:
            return llvm::StructType::get(
                context_, {builder_.getPtrTy(), builder_.getInt64Ty(),
                           builder_.getInt64Ty()});
        case SemanticTypeKind::Struct: {
            if (!type.typeArguments.empty())
                return getOrDeclareStructSpecialization(type, span);
            const auto found = structs_.find(type.name);
            if (found != structs_.end()) return found->second;
            break;
        }
        case SemanticTypeKind::Array:
            if (type.arraySizeKind == ArraySizeKind::Known && type.element) {
                auto* element = lowerType(*type.element, span);
                if (element)
                    return llvm::ArrayType::get(element, type.knownArraySize);
            }
            break;
        case SemanticTypeKind::Slice:
            return llvm::StructType::get(
                context_, {builder_.getPtrTy(), builder_.getInt64Ty()});
        case SemanticTypeKind::Nullable:
            if (type.element) {
                auto* element = lowerType(*type.element, span);
                if (element)
                    return llvm::StructType::get(
                        context_, {builder_.getInt1Ty(), element});
            }
            break;
        default: break;
        }
        diagnose("type '" + semanticTypeName(type) +
                 "' is not supported by the LLVM backend yet", span);
        return nullptr;
    }

    void declareStructs() {
        for (const auto& structure : current_->program->structs) {
            if (!structure.typeParameters.empty()) continue;
            const auto name = spelling(source(), structure.name);
            structs_.emplace(
                name, llvm::StructType::create(context_, name));
        }
        for (const auto& [name, symbol] : current_->semantic->structs) {
            const auto found = structs_.find(name);
            if (found == structs_.end()) continue;
            std::vector<llvm::Type*> fields;
            for (const auto& field : symbol.fields) {
                auto* type = lowerType(field.type, symbol.declaration->fields[field.index].span);
                if (type) fields.push_back(type);
            }
            if (fields.size() == symbol.fields.size())
                found->second->setBody(fields);
        }
    }

    std::string structSpecializationName(const SemanticType& type) const {
        std::uint64_t hash = 1469598103934665603ULL;
        const auto text = semanticTypeName(type);
        for (const auto byte : text) {
            hash ^= static_cast<unsigned char>(byte);
            hash *= 1099511628211ULL;
        }
        return type.name + "__s" + std::to_string(hash);
    }

    llvm::StructType* getOrDeclareStructSpecialization(
        const SemanticType& type, SourceSpan span) {
        const auto key = semanticTypeName(type);
        if (const auto found = specializedStructs_.find(key);
            found != specializedStructs_.end())
            return found->second;
        const auto symbol = semantic().structs.find(type.name);
        if (symbol == semantic().structs.end()) {
            diagnose("unknown struct during LLVM codegen", span);
            return nullptr;
        }
        auto* result = llvm::StructType::create(
            context_, structSpecializationName(type));
        specializedStructs_.emplace(key, result);
        std::vector<llvm::Type*> fields;
        for (const auto& field : symbol->second.fields) {
            const auto concrete = substituteType(field.type, type.typeArguments);
            auto* lowered = lowerType(
                concrete, symbol->second.declaration->fields[field.index].span);
            if (!lowered) return nullptr;
            fields.push_back(lowered);
        }
        result->setBody(fields);
        return result;
    }

    void declareFunctions() {
        for (const auto& function : current_->program->functions) {
            if (!function.typeParameters.empty()) continue;
            const auto name = spelling(source(), function.name);
            const auto symbol = current_->semantic->functions.find(name);
            if (symbol == current_->semantic->functions.end()) continue;
            std::vector<llvm::Type*> parameters;
            for (std::size_t i = 0; i < symbol->second.parameterTypes.size(); ++i) {
                auto* type = lowerType(
                    symbol->second.parameterTypes[i], function.parameters[i].type->span);
                if (type) {
                    parameters.push_back(
                        function.parameters[i].mode ==
                                ParameterMode::MutableBorrow
                            ? builder_.getPtrTy()
                            : type);
                }
            }
            auto* returnType =
                lowerType(symbol->second.returnType, function.returnType->span, true);
            if (!returnType || parameters.size() != function.parameters.size()) continue;
            auto* llvmFunction = llvm::Function::Create(
                llvm::FunctionType::get(returnType, parameters, false),
                llvm::Function::ExternalLinkage,
                name,
                *result_.module);
            functions_.emplace(&function, llvmFunction);
            functionsByName_.emplace(name, llvmFunction);
        }
    }

    SemanticType substituteType(
        const SemanticType& type,
        const std::vector<SemanticType>& arguments) const {
        if (type.kind == SemanticTypeKind::TypeParameter) {
            if (type.typeParameterIndex < arguments.size())
                return arguments[type.typeParameterIndex];
            return {};
        }
        if (!type.element) return type;
        auto element = substituteType(*type.element, arguments);
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

    SemanticType substituteActive(const SemanticType& type) const {
        return substituteType(type, activeTypeArguments_);
    }

    const ParsedModule* ownerModule(
        const FunctionDecl& declaration) const {
        for (const auto& module : modules_) {
            for (const auto& candidate : module.program->functions) {
                if (&candidate == &declaration) return &module;
            }
        }
        return nullptr;
    }

    std::string specializationName(
        const FunctionDecl& declaration,
        const std::vector<SemanticType>& arguments) const {
        std::uint64_t hash = 1469598103934665603ULL;
        for (const auto& argument : arguments) {
            const auto text = semanticTypeName(argument);
            for (const auto byte : text) {
                hash ^= static_cast<unsigned char>(byte);
                hash *= 1099511628211ULL;
            }
            hash ^= 0xff;
            hash *= 1099511628211ULL;
        }
        const auto* owner = ownerModule(declaration);
        const Source* ownerSource = owner ? owner->source.get() : nullptr;
        if (ownerSource == nullptr) ownerSource = &source();
        return spelling(*ownerSource, declaration.name) +
            "__g" + std::to_string(hash);
    }

    const FunctionSymbol* functionSymbol(
        const FunctionDecl& declaration) const {
        const auto* owner = ownerModule(declaration);
        if (!owner) return nullptr;
        const auto found = owner->semantic->functions.find(
            spelling(*owner->source, declaration.name));
        if (found != owner->semantic->functions.end() &&
            found->second.declaration == &declaration)
            return &found->second;
        return nullptr;
    }

    llvm::Function* getOrDeclareSpecialization(
        const SpecializationKey& key) {
        if (!key.declaration) return nullptr;
        const auto name =
            specializationName(*key.declaration, key.typeArguments);
        if (const auto found = specializedFunctions_.find(name);
            found != specializedFunctions_.end())
            return found->second;
        const auto* symbol = functionSymbol(*key.declaration);
        if (!symbol) return nullptr;
        std::vector<llvm::Type*> parameters;
        for (std::size_t i = 0;
             i < symbol->parameterTypes.size(); ++i) {
            const auto concrete = substituteType(
                symbol->parameterTypes[i], key.typeArguments);
            auto* type = lowerType(
                concrete, key.declaration->parameters[i].type->span);
            if (!type) return nullptr;
            parameters.push_back(
                key.declaration->parameters[i].mode ==
                        ParameterMode::MutableBorrow
                    ? builder_.getPtrTy()
                    : type);
        }
        const auto concreteReturn =
            substituteType(symbol->returnType, key.typeArguments);
        auto* returnType = lowerType(
            concreteReturn, key.declaration->returnType->span, true);
        if (!returnType) return nullptr;
        auto* function = llvm::Function::Create(
            llvm::FunctionType::get(
                returnType, parameters, false),
            llvm::Function::ExternalLinkage, name,
            *result_.module);
        specializedFunctions_.emplace(name, function);
        pendingSpecializations_.push_back(
            {key.declaration, key.typeArguments, function});
        return function;
    }

    void emitFunction(const FunctionDecl& declaration) {
        if (!declaration.typeParameters.empty()) return;
        if (declaration.isExtern) return;
        const auto found = functions_.find(&declaration);
        if (found == functions_.end()) return;
        emitFunctionBody(declaration, found->second, {});
    }

    void emitFunctionBody(
        const FunctionDecl& declaration,
        llvm::Function* function,
        std::vector<SemanticType> typeArguments) {
        if (declaration.isExtern || !function->empty()) return;
        const auto outerTypeArguments = activeTypeArguments_;
        activeTypeArguments_ = std::move(typeArguments);
        ParsedModule* outerCurrent = current_;
        const auto* module = ownerModule(declaration);
        const Source* ownerSource = nullptr;
        if (module) {
            current_ = const_cast<ParsedModule*>(module);
            ownerSource = module->source.get();
        }
        if (ownerSource == nullptr) ownerSource = &source();
        const auto& owner = *ownerSource;
        auto* entry = llvm::BasicBlock::Create(context_, "entry", function);
        builder_.SetInsertPoint(entry);
        locals_.clear();

        std::size_t parameterIndex = 0;
        for (auto& argument : function->args()) {
            const auto& parameter = declaration.parameters[parameterIndex];
            const auto name = spelling(owner, parameter.name);
            argument.setName(name);
            if (parameter.mode == ParameterMode::MutableBorrow) {
                const auto symbol = current_->semantic->functions.find(
                    spelling(owner, declaration.name));
                auto* valueType = lowerType(
                    symbol->second.parameterTypes[parameterIndex],
                    parameter.type->span);
                locals_.emplace(
                    name, LocalSlot{&argument, valueType});
            } else {
                auto* slot =
                    createEntryAlloca(*function, argument.getType(), name);
                builder_.CreateStore(&argument, slot);
                locals_.emplace(
                    name, LocalSlot{slot, argument.getType()});
            }
            ++parameterIndex;
        }

        if (declaration.isExpressionBody && function->getReturnType()->isVoidTy() &&
            declaration.body->statements.size() == 1) {
            const auto& statement = *declaration.body->statements[0];
            if (const auto* value = std::get_if<ReturnStmt>(&statement.node);
                value && value->value)
                emitExpr(*value->value);
            else
                emitStatement(statement);
        } else {
            for (const auto& statement : declaration.body->statements) {
                emitStatement(*statement);
                if (builder_.GetInsertBlock()->getTerminator()) break;
            }
        }
        if (!builder_.GetInsertBlock()->getTerminator() &&
            function->getReturnType()->isVoidTy()) {
            builder_.CreateRetVoid();
        }
        activeTypeArguments_ = outerTypeArguments;
        current_ = outerCurrent;
    }

    llvm::AllocaInst* createEntryAlloca(
        llvm::Function& function,
        llvm::Type* type,
        const std::string& name) {
        llvm::IRBuilder<> entryBuilder{
            &function.getEntryBlock(), function.getEntryBlock().begin()};
        return entryBuilder.CreateAlloca(type, nullptr, name);
    }

    void emitStatement(const Stmt& statement) {
        if (const auto* block = std::get_if<BlockStmt>(&statement.node)) {
            emitScopedBlock(*block);
            return;
        }
        if (const auto* ifStatement = std::get_if<IfStmt>(&statement.node)) {
            emitIf(*ifStatement);
            return;
        }
        if (const auto* whileStatement = std::get_if<WhileStmt>(&statement.node)) {
            emitWhile(*whileStatement);
            return;
        }
        if (const auto* forStatement = std::get_if<ForStmt>(&statement.node)) {
            emitFor(*forStatement);
            return;
        }
        if (const auto* whenStatement = std::get_if<WhenStmt>(&statement.node)) {
            emitWhen(*whenStatement);
            return;
        }
        if (std::holds_alternative<BreakStmt>(statement.node)) {
            builder_.CreateBr(loopTargets_.back().second);
            return;
        }
        if (std::holds_alternative<ContinueStmt>(statement.node)) {
            builder_.CreateBr(loopTargets_.back().first);
            return;
        }
        if (const auto* variable = std::get_if<VariableDecl>(&statement.node)) {
            llvm::Value* value = nullptr;
            const auto declared = semantic().declarationTypes.find(variable);
            const auto initializerType =
                semantic().expressionTypes.find(variable->initializer.get());
            if (declared != semantic().declarationTypes.end() &&
                declared->second.kind == SemanticTypeKind::Slice &&
                initializerType != semantic().expressionTypes.end() &&
                initializerType->second.kind == SemanticTypeKind::Array) {
                value = emitArrayToSlice(
                    *variable->initializer, declared->second);
            } else {
                value = emitExpr(*variable->initializer);
            }
            if (!value) return;
            const auto name = spelling(source(), variable->name);
            auto* slot = createEntryAlloca(
                *builder_.GetInsertBlock()->getParent(), value->getType(), name);
            builder_.CreateStore(value, slot);
            locals_[name] = {slot, value->getType()};
            return;
        }
        if (const auto* returnStatement = std::get_if<ReturnStmt>(&statement.node)) {
            if (returnStatement->value) {
                if (auto* value = emitExpr(*returnStatement->value)) {
                    const auto conversion =
                        semantic().implicitConversions.find(
                            returnStatement->value.get());
                    if (conversion != semantic().implicitConversions.end())
                        value = liftNullable(
                            value, conversion->second,
                            returnStatement->value->span);
                    builder_.CreateRet(value);
                }
            } else {
                builder_.CreateRetVoid();
            }
            return;
        }
        if (const auto* expression = std::get_if<ExpressionStmt>(&statement.node)) {
            emitExpr(*expression->expression);
            return;
        }
        diagnose("statement is not supported by the LLVM backend yet", statement.span);
    }

    void emitScopedBlock(const BlockStmt& block) {
        const auto outerLocals = locals_;
        for (const auto& statement : block.statements) {
            emitStatement(*statement);
            if (builder_.GetInsertBlock()->getTerminator()) break;
        }
        locals_ = outerLocals;
    }

    void emitIf(const IfStmt& statement) {
        auto* condition = emitExpr(*statement.condition);
        if (!condition) return;
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* thenBlock = llvm::BasicBlock::Create(context_, "if.then", function);
        auto* mergeBlock = llvm::BasicBlock::Create(context_, "if.end", function);
        auto* elseBlock = statement.elseBranch
            ? llvm::BasicBlock::Create(context_, "if.else", function)
            : mergeBlock;
        builder_.CreateCondBr(condition, thenBlock, elseBlock);

        builder_.SetInsertPoint(thenBlock);
        emitScopedBlock(*statement.thenBranch);
        const bool thenTerminates = builder_.GetInsertBlock()->getTerminator();
        if (!thenTerminates) builder_.CreateBr(mergeBlock);

        bool elseTerminates = false;
        if (statement.elseBranch) {
            builder_.SetInsertPoint(elseBlock);
            emitScopedBlock(*statement.elseBranch);
            elseTerminates = builder_.GetInsertBlock()->getTerminator();
            if (!elseTerminates) builder_.CreateBr(mergeBlock);
        }

        if (statement.elseBranch && thenTerminates && elseTerminates) {
            mergeBlock->eraseFromParent();
            return;
        }
        builder_.SetInsertPoint(mergeBlock);
    }

    void emitWhile(const WhileStmt& statement) {
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* conditionBlock =
            llvm::BasicBlock::Create(context_, "while.condition", function);
        auto* bodyBlock = llvm::BasicBlock::Create(context_, "while.body", function);
        auto* exitBlock = llvm::BasicBlock::Create(context_, "while.end", function);
        builder_.CreateBr(conditionBlock);

        builder_.SetInsertPoint(conditionBlock);
        auto* condition = emitExpr(*statement.condition);
        if (!condition) return;
        builder_.CreateCondBr(condition, bodyBlock, exitBlock);

        builder_.SetInsertPoint(bodyBlock);
        loopTargets_.push_back({conditionBlock, exitBlock});
        emitScopedBlock(*statement.body);
        loopTargets_.pop_back();
        if (!builder_.GetInsertBlock()->getTerminator())
            builder_.CreateBr(conditionBlock);
        builder_.SetInsertPoint(exitBlock);
    }

    void emitWhen(const WhenStmt& statement) {
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* mergeBlock = llvm::BasicBlock::Create(context_, "when.end", function);
        llvm::Value* subject = statement.subject
            ? emitExpr(*statement.subject) : nullptr;
        bool allTerminate = !statement.branches.empty();
        bool hasElse = false;
        for (std::size_t i = 0; i < statement.branches.size(); ++i) {
            const auto& branch = statement.branches[i];
            auto* bodyBlock = llvm::BasicBlock::Create(
                context_, branch.conditions.empty() ? "when.else" : "when.branch",
                function);
            if (!branch.conditions.empty()) {
                const bool last = i + 1 == statement.branches.size();
                auto* next = last ? mergeBlock : llvm::BasicBlock::Create(
                    context_, "when.next", function);
                for (std::size_t j = 0; j < branch.conditions.size(); ++j) {
                    auto* condition = emitExpr(*branch.conditions[j]);
                    if (!condition) return;
                    if (subject) {
                        condition = subject->getType()->isFloatingPointTy()
                            ? builder_.CreateFCmpOEQ(subject, condition)
                            : builder_.CreateICmpEQ(subject, condition);
                    }
                    auto* miss = j + 1 == branch.conditions.size() ? next
                        : llvm::BasicBlock::Create(context_, "when.pattern", function);
                    builder_.CreateCondBr(condition, bodyBlock, miss);
                    if (j + 1 < branch.conditions.size()) builder_.SetInsertPoint(miss);
                }
                builder_.SetInsertPoint(bodyBlock);
                emitScopedBlock(*branch.body);
                const bool terminates = builder_.GetInsertBlock()->getTerminator();
                allTerminate = allTerminate && terminates;
                if (!terminates)
                    builder_.CreateBr(mergeBlock);
                if (!last) builder_.SetInsertPoint(next);
            } else {
                hasElse = true;
                builder_.CreateBr(bodyBlock);
                builder_.SetInsertPoint(bodyBlock);
                emitScopedBlock(*branch.body);
                const bool terminates = builder_.GetInsertBlock()->getTerminator();
                allTerminate = allTerminate && terminates;
                if (!terminates)
                    builder_.CreateBr(mergeBlock);
            }
        }
        if (statement.branches.empty()) builder_.CreateBr(mergeBlock);
        if (hasElse && allTerminate) {
            mergeBlock->eraseFromParent();
            return;
        }
        builder_.SetInsertPoint(mergeBlock);
        const auto subjectType = statement.subject
            ? semantic().expressionTypes.find(statement.subject.get())
            : semantic().expressionTypes.end();
        if (!hasElse && allTerminate &&
            subjectType != semantic().expressionTypes.end() &&
            subjectType->second.kind == SemanticTypeKind::Enum)
            builder_.CreateUnreachable();
    }

    void emitFor(const ForStmt& statement) {
        if (const auto* range = std::get_if<BinaryExpr>(&statement.collection->node);
            range && (range->op == TokenKind::Range ||
                      range->op == TokenKind::RangeExclusive)) {
            emitRangeFor(statement, *range);
            return;
        }
        const auto type = semantic().expressionTypes.find(statement.collection.get());
        const auto* identifier = std::get_if<IdentifierExpr>(&statement.collection->node);
        if (type == semantic().expressionTypes.end() || !identifier) {
            diagnose("for collection must be a local array or slice",
                     statement.collection->span);
            return;
        }
        const auto local = locals_.find(spelling(source(), identifier->name));
        if (local == locals_.end()) return;
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* indexSlot = createEntryAlloca(
            *function, builder_.getInt64Ty(), "for.index");
        builder_.CreateStore(builder_.getInt64(0), indexSlot);
        llvm::Value* data = nullptr;
        llvm::Value* length = nullptr;
        if (type->second.kind == SemanticTypeKind::Array) {
            auto* arrayType = llvm::cast<llvm::ArrayType>(
                lowerType(type->second, statement.collection->span));
            data = builder_.CreateInBoundsGEP(
                arrayType, local->second.address,
                {builder_.getInt32(0), builder_.getInt32(0)});
            length = builder_.getInt64(type->second.knownArraySize);
        } else {
            auto* sliceType = llvm::cast<llvm::StructType>(
                lowerType(type->second, statement.collection->span));
            auto* slice = builder_.CreateLoad(sliceType, local->second.address);
            data = builder_.CreateExtractValue(slice, 0);
            length = builder_.CreateExtractValue(slice, 1);
        }
        auto* conditionBlock = llvm::BasicBlock::Create(
            context_, "for.condition", function);
        auto* bodyBlock = llvm::BasicBlock::Create(context_, "for.body", function);
        auto* incrementBlock = llvm::BasicBlock::Create(
            context_, "for.increment", function);
        auto* exitBlock = llvm::BasicBlock::Create(context_, "for.end", function);
        builder_.CreateBr(conditionBlock);
        builder_.SetInsertPoint(conditionBlock);
        auto* index = builder_.CreateLoad(builder_.getInt64Ty(), indexSlot);
        builder_.CreateCondBr(
            builder_.CreateICmpULT(index, length), bodyBlock, exitBlock);
        builder_.SetInsertPoint(bodyBlock);
        auto* elementType = lowerType(*type->second.element, statement.valueName);
        auto* value = builder_.CreateLoad(
            elementType, builder_.CreateInBoundsGEP(elementType, data, index));
        const auto valueName = spelling(source(), statement.valueName);
        auto* valueSlot = createEntryAlloca(*function, elementType, valueName);
        builder_.CreateStore(value, valueSlot);
        const auto outerLocals = locals_;
        locals_[valueName] = {valueSlot, elementType};
        if (statement.indexName)
            locals_[spelling(source(), *statement.indexName)] = {
                indexSlot, builder_.getInt64Ty()};
        loopTargets_.push_back({incrementBlock, exitBlock});
        emitScopedBlock(*statement.body);
        loopTargets_.pop_back();
        locals_ = outerLocals;
        if (!builder_.GetInsertBlock()->getTerminator())
            builder_.CreateBr(incrementBlock);
        builder_.SetInsertPoint(incrementBlock);
        auto* next = builder_.CreateAdd(
            builder_.CreateLoad(builder_.getInt64Ty(), indexSlot),
            builder_.getInt64(1));
        builder_.CreateStore(next, indexSlot);
        builder_.CreateBr(conditionBlock);
        builder_.SetInsertPoint(exitBlock);
    }

    void emitRangeFor(const ForStmt& statement, const BinaryExpr& range) {
        auto* start = emitExpr(*range.left);
        auto* end = emitExpr(*range.right);
        if (!start || !end) return;
        auto* function = builder_.GetInsertBlock()->getParent();
        const auto name = spelling(source(), statement.valueName);
        auto* valueSlot = createEntryAlloca(*function, start->getType(), name);
        builder_.CreateStore(start, valueSlot);
        auto* conditionBlock = llvm::BasicBlock::Create(context_, "for.condition", function);
        auto* bodyBlock = llvm::BasicBlock::Create(context_, "for.body", function);
        auto* incrementBlock = llvm::BasicBlock::Create(context_, "for.increment", function);
        auto* exitBlock = llvm::BasicBlock::Create(context_, "for.end", function);
        builder_.CreateBr(conditionBlock);
        builder_.SetInsertPoint(conditionBlock);
        auto* value = builder_.CreateLoad(start->getType(), valueSlot);
        const auto rangeType = semantic().expressionTypes.find(statement.collection.get());
        const bool signedRange = rangeType == semantic().expressionTypes.end() ||
            isSignedInteger(rangeType->second);
        llvm::Value* condition = nullptr;
        if (range.op == TokenKind::Range)
            condition = signedRange ? builder_.CreateICmpSLE(value, end)
                                    : builder_.CreateICmpULE(value, end);
        else
            condition = signedRange ? builder_.CreateICmpSLT(value, end)
                                    : builder_.CreateICmpULT(value, end);
        builder_.CreateCondBr(condition, bodyBlock, exitBlock);
        builder_.SetInsertPoint(bodyBlock);
        const auto outerLocals = locals_;
        locals_[name] = {valueSlot, start->getType()};
        loopTargets_.push_back({incrementBlock, exitBlock});
        emitScopedBlock(*statement.body);
        loopTargets_.pop_back();
        locals_ = outerLocals;
        if (!builder_.GetInsertBlock()->getTerminator()) builder_.CreateBr(incrementBlock);
        builder_.SetInsertPoint(incrementBlock);
        auto* current = builder_.CreateLoad(start->getType(), valueSlot);
        builder_.CreateStore(builder_.CreateAdd(
            current, llvm::ConstantInt::get(start->getType(), 1)), valueSlot);
        builder_.CreateBr(conditionBlock);
        builder_.SetInsertPoint(exitBlock);
    }

    llvm::Value* emitExpr(const Expr& expression) {
        const auto typeFound = semantic().expressionTypes.find(&expression);
        if (typeFound == semantic().expressionTypes.end()) {
            diagnose("expression has no semantic type", expression.span);
            return nullptr;
        }
        const auto semanticType =
            substituteActive(typeFound->second);
        if (std::holds_alternative<SizeofExpr>(expression.node)) {
            const auto sized = semantic().sizeofTypes.find(&expression);
            if (sized == semantic().sizeofTypes.end()) return nullptr;
            auto* type = lowerType(sized->second, expression.span);
            if (!type) return nullptr;
            return llvm::ConstantExpr::getSizeOf(type);
        }
        if (const auto* conditional = std::get_if<IfExpr>(&expression.node)) {
            auto* condition = emitExpr(*conditional->condition);
            if (!condition) return nullptr;
            auto* function = builder_.GetInsertBlock()->getParent();
            auto* thenBlock = llvm::BasicBlock::Create(context_, "if.then", function);
            auto* elseBlock = llvm::BasicBlock::Create(context_, "if.else", function);
            auto* mergeBlock = llvm::BasicBlock::Create(context_, "if.merge", function);
            auto* resultType = lowerType(semanticType, expression.span);
            if (!resultType) return nullptr;
            auto* phi = llvm::PHINode::Create(resultType, 2, "if.value", mergeBlock);
            builder_.CreateCondBr(condition, thenBlock, elseBlock);
            auto emitBranch = [&](llvm::BasicBlock* block,
                                  const IfExprBranch& branch) -> bool {
                builder_.SetInsertPoint(block);
                const auto outerLocals = locals_;
                for (const auto& statement : branch.body->statements)
                    emitStatement(*statement);
                auto* value = emitExpr(*branch.value);
                locals_ = outerLocals;
                if (!value) return false;
                auto* incoming = builder_.GetInsertBlock();
                builder_.CreateBr(mergeBlock);
                phi->addIncoming(value, incoming);
                return true;
            };
            if (!emitBranch(thenBlock, conditional->thenBranch) ||
                !emitBranch(elseBlock, conditional->elseBranch))
                return nullptr;
            builder_.SetInsertPoint(mergeBlock);
            return phi;
        }
        if (const auto* when = std::get_if<WhenExpr>(&expression.node)) {
            auto* function = builder_.GetInsertBlock()->getParent();
            auto* mergeBlock = llvm::BasicBlock::Create(
                context_, "when.merge", function);
            auto* resultType = lowerType(semanticType, expression.span);
            if (!resultType) return nullptr;
            auto* phi = llvm::PHINode::Create(
                resultType, static_cast<unsigned>(when->branches.size()),
                "when.value", mergeBlock);
            llvm::Value* subject = nullptr;
            bool hasElse = false;
            if (when->subject) {
                subject = emitExpr(*when->subject);
                if (!subject) return nullptr;
            }
            for (std::size_t i = 0; i < when->branches.size(); ++i) {
                const auto& branch = when->branches[i];
                auto* bodyBlock = llvm::BasicBlock::Create(
                    context_, "when.body", function);
                if (!branch.conditions.empty()) {
                    auto* nextBlock = llvm::BasicBlock::Create(
                        context_, "when.next", function);
                    for (std::size_t j = 0; j < branch.conditions.size(); ++j) {
                        auto* condition = emitExpr(*branch.conditions[j]);
                        if (!condition) return nullptr;
                        if (subject)
                            condition = builder_.CreateICmpEQ(subject, condition);
                        auto* miss = j + 1 == branch.conditions.size() ? nextBlock
                            : llvm::BasicBlock::Create(context_, "when.pattern", function);
                        builder_.CreateCondBr(condition, bodyBlock, miss);
                        if (j + 1 < branch.conditions.size()) builder_.SetInsertPoint(miss);
                    }
                    builder_.SetInsertPoint(bodyBlock);
                    const auto outerLocals = locals_;
                    for (const auto& statement : branch.body->statements)
                        emitStatement(*statement);
                    auto* value = emitExpr(*branch.value);
                    locals_ = outerLocals;
                    if (!value) return nullptr;
                    auto* incoming = builder_.GetInsertBlock();
                    builder_.CreateBr(mergeBlock);
                    phi->addIncoming(value, incoming);
                    builder_.SetInsertPoint(nextBlock);
                } else {
                    hasElse = true;
                    builder_.CreateBr(bodyBlock);
                    builder_.SetInsertPoint(bodyBlock);
                    const auto outerLocals = locals_;
                    for (const auto& statement : branch.body->statements)
                        emitStatement(*statement);
                    auto* value = emitExpr(*branch.value);
                    locals_ = outerLocals;
                    if (!value) return nullptr;
                    auto* incoming = builder_.GetInsertBlock();
                    builder_.CreateBr(mergeBlock);
                    phi->addIncoming(value, incoming);
                }
            }
            if (!hasElse) builder_.CreateUnreachable();
            builder_.SetInsertPoint(mergeBlock);
            return phi;
        }
        if (const auto* array = std::get_if<ArrayLiteralExpr>(&expression.node)) {
            auto* type = lowerType(semanticType, expression.span);
            if (!type) return nullptr;
            llvm::Value* value = llvm::UndefValue::get(type);
            for (std::size_t i = 0; i < array->elements.size(); ++i) {
                auto* element = emitExpr(*array->elements[i]);
                if (!element) return nullptr;
                value = builder_.CreateInsertValue(
                    value, element, static_cast<unsigned>(i));
            }
            return value;
        }
        if (const auto* cast = std::get_if<CastExpr>(&expression.node)) {
            const auto sourceType =
                semantic().expressionTypes.find(cast->value.get());
            if (sourceType != semantic().expressionTypes.end() &&
                sourceType->second.kind == SemanticTypeKind::Pointer &&
                semanticType.kind == SemanticTypeKind::Pointer)
                return emitExpr(*cast->value);
            if (sourceType != semantic().expressionTypes.end() &&
                isInteger(sourceType->second) && isInteger(semanticType)) {
                auto* value = emitExpr(*cast->value);
                if (!value) return nullptr;
                const auto castInfo = semantic().integerCasts.find(cast);
                if (castInfo == semantic().integerCasts.end()) {
                    diagnose("integer cast is missing semantic metadata",
                             expression.span);
                    return nullptr;
                }
                if (castInfo->second.requiresRangeCheck)
                    emitIntegerCastRangeCheck(value, castInfo->second);
                const auto sourceWidth = numericBitWidth(sourceType->second);
                const auto targetWidth = numericBitWidth(semanticType);
                auto* targetType = lowerType(semanticType, expression.span);
                if (!targetType) return nullptr;
                if (targetWidth < sourceWidth)
                    return builder_.CreateTrunc(value, targetType);
                if (targetWidth > sourceWidth)
                    return isSignedInteger(sourceType->second)
                        ? builder_.CreateSExt(value, targetType)
                        : builder_.CreateZExt(value, targetType);
                return value;
            }
            const auto floatCast = semantic().floatCasts.find(cast);
            if (floatCast != semantic().floatCasts.end()) {
                auto* value = emitExpr(*cast->value);
                if (!value) return nullptr;
                const auto& info = floatCast->second;
                auto* targetType = lowerType(semanticType, expression.span);
                if (!targetType) return nullptr;
                switch (info.kind) {
                case FloatCastKind::Identity:
                    return value;
                case FloatCastKind::Extend:
                    return builder_.CreateFPExt(value, targetType);
                case FloatCastKind::Narrow:
                    return builder_.CreateFPTrunc(value, targetType);
                case FloatCastKind::IntegerToFloat:
                    return isSignedInteger(info.sourceType)
                        ? builder_.CreateSIToFP(value, targetType)
                        : builder_.CreateUIToFP(value, targetType);
                case FloatCastKind::FloatToInteger:
                    emitFloatCastRangeCheck(value, info);
                    return isSignedInteger(info.targetType)
                        ? builder_.CreateFPToSI(value, targetType)
                        : builder_.CreateFPToUI(value, targetType);
                }
            }
            diagnose("cast is not supported by the LLVM backend yet",
                     expression.span);
            return nullptr;
        }
        if (const auto* call = std::get_if<CallExpr>(&expression.node)) {
            const auto* callee = std::get_if<IdentifierExpr>(&call->callee->node);
            if (callee && spelling(source(), callee->name) == "print" &&
                call->arguments.size() == 1) {
                const auto& argument = *call->arguments.front();
                const auto argumentType = semantic().expressionTypes.find(&argument);
                if (argumentType != semantic().expressionTypes.end() &&
                    argumentType->second.kind == SemanticTypeKind::String) {
                    auto* value = emitExpr(argument);
                    if (!value) return nullptr;
                    auto* pointer = builder_.CreateExtractValue(value, 0);
                    auto* length = builder_.CreateExtractValue(value, 1);
                    auto function = result_.module->getOrInsertFunction(
                        "k_std_print_bytes",
                        llvm::FunctionType::get(
                            llvm::Type::getVoidTy(context_),
                            {builder_.getPtrTy(), builder_.getInt64Ty()}, false));
                    return builder_.CreateCall(
                        function, {pointer, length});
                }
                auto* value = emitExpr(argument);
                if (!value) return nullptr;
                auto function = result_.module->getOrInsertFunction(
                    "k_std_print_i32",
                    llvm::FunctionType::get(
                        llvm::Type::getVoidTy(context_),
                        {builder_.getInt32Ty()}, false));
                return builder_.CreateCall(function, {value});
            }
            if (callee) {
                const auto name = spelling(source(), callee->name);
                if (const auto resolved =
                        semantic().resolvedCalls.find(call);
                    resolved != semantic().resolvedCalls.end() &&
                    resolved->second.declaration &&
                    !resolved->second.declaration->typeParameters.empty()) {
                    std::vector<SemanticType> concreteArguments;
                    concreteArguments.reserve(
                        resolved->second.typeArguments.size());
                    for (const auto& argument :
                         resolved->second.typeArguments)
                        concreteArguments.push_back(
                            substituteActive(argument));
                    auto* target = getOrDeclareSpecialization(
                        SpecializationKey{
                            resolved->second.declaration,
                            concreteArguments});
                    if (!target) return nullptr;
                    std::vector<llvm::Value*> arguments;
                    arguments.reserve(call->arguments.size());
                    for (std::size_t i = 0;
                         i < call->arguments.size(); ++i) {
                        llvm::Value* value = nullptr;
                        if (i < resolved->second.declaration
                                    ->parameters.size() &&
                            resolved->second.declaration
                                    ->parameters[i].mode ==
                                ParameterMode::MutableBorrow) {
                            const auto* identifier =
                                std::get_if<IdentifierExpr>(
                                    &call->arguments[i]->node);
                            if (identifier) {
                                const auto local = locals_.find(
                                    spelling(
                                        source(),
                                        identifier->name));
                                if (local != locals_.end())
                                    value = local->second.address;
                            }
                        } else {
                            value = emitExpr(*call->arguments[i]);
                        }
                        if (!value) return nullptr;
                        arguments.push_back(value);
                    }
                    return builder_.CreateCall(target, arguments);
                }
                if (const auto structure = semantic().structs.find(name);
                    structure != semantic().structs.end()) {
                    auto* llvmStructure = lowerType(
                        semanticType, expression.span);
                    if (!llvmStructure) return nullptr;
                    llvm::Value* value =
                        llvm::UndefValue::get(llvmStructure);
                    for (std::size_t i = 0; i < call->arguments.size(); ++i) {
                        auto* fieldValue = emitExpr(*call->arguments[i]);
                        if (!fieldValue) return nullptr;
                        value = builder_.CreateInsertValue(
                            value, fieldValue, static_cast<unsigned>(i));
                    }
                    return value;
                }
                const auto found = functionsByName_.find(name);
                if (found == functionsByName_.end()) {
                    diagnose("unknown function during LLVM codegen", callee->name);
                    return nullptr;
                }
                std::vector<llvm::Value*> arguments;
                arguments.reserve(call->arguments.size());
                const auto semanticFunction = semantic().functions.find(name);
                for (std::size_t i = 0; i < call->arguments.size(); ++i) {
                    llvm::Value* value = nullptr;
                    if (semanticFunction != semantic().functions.end() &&
                        i < semanticFunction->second.declaration->parameters.size() &&
                        semanticFunction->second.declaration->parameters[i].mode ==
                            ParameterMode::MutableBorrow) {
                        const auto* identifier =
                            std::get_if<IdentifierExpr>(
                                &call->arguments[i]->node);
                        if (identifier) {
                            const auto local = locals_.find(
                                spelling(source(), identifier->name));
                            if (local != locals_.end())
                                value = local->second.address;
                        }
                    } else {
                        value = emitExpr(*call->arguments[i]);
                    }
                    if (!value) return nullptr;
                    arguments.push_back(value);
                }
                return builder_.CreateCall(found->second, arguments);
            }
        }
        if (const auto* literal = std::get_if<LiteralExpr>(&expression.node)) {
            auto* type = lowerType(semanticType, expression.span);
            if (!type) return nullptr;
            if (literal->kind == TokenKind::KwNull &&
                semanticType.kind == SemanticTypeKind::Nullable) {
                llvm::Value* value = llvm::UndefValue::get(type);
                return builder_.CreateInsertValue(
                    value, builder_.getFalse(), 0);
            }
            auto text = spelling(source(), literal->spelling);
            if (semanticType.kind == SemanticTypeKind::String) {
                const auto decoded = decodeStringLiteral(text);
                llvm::Value* value = llvm::UndefValue::get(type);
                value = builder_.CreateInsertValue(
                    value, builder_.CreateGlobalString(decoded), 0);
                value = builder_.CreateInsertValue(
                    value, llvm::ConstantInt::get(
                        builder_.getInt64Ty(), decoded.size()), 1);
                return builder_.CreateInsertValue(
                    value, llvm::ConstantInt::get(builder_.getInt64Ty(), 0), 2);
            }
            if (semanticType.kind == SemanticTypeKind::Bool)
                return llvm::ConstantInt::get(
                    type, literal->kind == TokenKind::KwTrue);
            if (isInteger(semanticType)) {
                std::uint64_t value{};
                const auto parsed =
                    std::from_chars(text.data(), text.data() + text.size(), value);
                if (parsed.ec != std::errc{}) {
                    diagnose("invalid integer literal for LLVM codegen", expression.span);
                    return nullptr;
                }
                return llvm::ConstantInt::get(type, value, isSignedInteger(semanticType));
            }
            if (isFloat(semanticType))
                return llvm::ConstantFP::get(type, std::stod(text));
        }
        if (const auto* identifier = std::get_if<IdentifierExpr>(&expression.node)) {
            const auto name = spelling(source(), identifier->name);
            const auto found = locals_.find(name);
            if (found == locals_.end()) {
                const auto constant = semantic().constants.find(name);
                if (constant != semantic().constants.end())
                    return emitExpr(*constant->second.declaration->initializer);
                diagnose("unknown local during LLVM codegen", identifier->name);
                return nullptr;
            }
            return builder_.CreateLoad(
                found->second.type, found->second.address,
                name + ".value");
        }
        if (const auto* member = std::get_if<MemberExpr>(&expression.node)) {
            if (const auto value = semantic().enumValues.find(member);
                value != semantic().enumValues.end())
                return llvm::ConstantInt::get(builder_.getInt32Ty(), value->second);
            const auto objectType =
                semantic().expressionTypes.find(member->object.get());
            if (objectType == semantic().expressionTypes.end() ||
                objectType->second.kind != SemanticTypeKind::Struct) {
                diagnose("member object has no struct type during LLVM codegen",
                         member->object->span);
                return nullptr;
            }
            const auto structure = semantic().structs.find(objectType->second.name);
            if (structure == semantic().structs.end()) return nullptr;
            const auto fieldName = spelling(source(), member->name);
            const auto field = std::find_if(
                structure->second.fields.begin(), structure->second.fields.end(),
                [&](const StructFieldSymbol& candidate) {
                    return candidate.name == fieldName;
                });
            if (field == structure->second.fields.end()) return nullptr;
            auto* object = emitExpr(*member->object);
            if (!object) return nullptr;
            return builder_.CreateExtractValue(
                object, static_cast<unsigned>(field->index));
        }
        if (const auto* index = std::get_if<IndexExpr>(&expression.node)) {
            auto* pointer = emitIndexPointer(*index);
            if (!pointer) return nullptr;
            auto* elementType = lowerType(semanticType, expression.span);
            if (!elementType) return nullptr;
            return builder_.CreateLoad(elementType, pointer);
        }
        if (const auto* assignment = std::get_if<AssignmentExpr>(&expression.node)) {
            if (const auto* unary =
                    std::get_if<UnaryExpr>(&assignment->target->node);
                unary && unary->op == TokenKind::Star) {
                auto* pointer = emitExpr(*unary->operand);
                auto* value = emitExpr(*assignment->value);
                if (!pointer || !value) return nullptr;
                builder_.CreateStore(value, pointer);
                return value;
            }
            if (const auto* member =
                    std::get_if<MemberExpr>(&assignment->target->node)) {
                const auto* object =
                    std::get_if<IdentifierExpr>(&member->object->node);
                if (!object) {
                    diagnose("field assignment requires a local struct",
                             member->object->span);
                    return nullptr;
                }
                const auto localName = spelling(source(), object->name);
                const auto local = locals_.find(localName);
                if (local == locals_.end()) return nullptr;
                const auto objectType =
                    semantic().expressionTypes.find(member->object.get());
                if (objectType == semantic().expressionTypes.end()) return nullptr;
                const auto structure =
                    semantic().structs.find(objectType->second.name);
                if (structure == semantic().structs.end()) return nullptr;
                auto* llvmStructure = lowerType(
                    objectType->second, member->object->span);
                if (!llvmStructure) return nullptr;
                const auto fieldName = spelling(source(), member->name);
                const auto field = std::find_if(
                    structure->second.fields.begin(),
                    structure->second.fields.end(),
                    [&](const StructFieldSymbol& candidate) {
                        return candidate.name == fieldName;
                    });
                if (field == structure->second.fields.end()) return nullptr;
                auto* value = emitExpr(*assignment->value);
                if (!value) return nullptr;
                auto* pointer = builder_.CreateStructGEP(
                    llvmStructure, local->second.address,
                    static_cast<unsigned>(field->index));
                builder_.CreateStore(value, pointer);
                return value;
            }
            if (const auto* index =
                    std::get_if<IndexExpr>(&assignment->target->node)) {
                auto* pointer = emitIndexPointer(*index);
                if (!pointer) return nullptr;
                auto* value = emitExpr(*assignment->value);
                if (!value) return nullptr;
                builder_.CreateStore(value, pointer);
                return value;
            }
            const auto* target = std::get_if<IdentifierExpr>(&assignment->target->node);
            if (!target) {
                diagnose("assignment target is not supported by the LLVM backend yet",
                         assignment->target->span);
                return nullptr;
            }
            const auto name = spelling(source(), target->name);
            const auto found = locals_.find(name);
            if (found == locals_.end()) {
                diagnose("unknown local during LLVM codegen", target->name);
                return nullptr;
            }
            auto* value = emitExpr(*assignment->value);
            if (!value) return nullptr;
            builder_.CreateStore(value, found->second.address);
            return value;
        }
        if (const auto* binary = std::get_if<BinaryExpr>(&expression.node)) {
            auto* left = emitExpr(*binary->left);
            if (!left) return nullptr;
            if (binary->op == TokenKind::AndAnd ||
                binary->op == TokenKind::OrOr) {
                auto* function = builder_.GetInsertBlock()->getParent();
                auto* leftBlock = builder_.GetInsertBlock();
                auto* rhsBlock = llvm::BasicBlock::Create(
                    context_, "logic.rhs", function);
                auto* mergeBlock = llvm::BasicBlock::Create(
                    context_, "logic.merge", function);
                if (binary->op == TokenKind::AndAnd)
                    builder_.CreateCondBr(left, rhsBlock, mergeBlock);
                else
                    builder_.CreateCondBr(left, mergeBlock, rhsBlock);
                builder_.SetInsertPoint(rhsBlock);
                auto* right = emitExpr(*binary->right);
                if (!right) return nullptr;
                auto* rightBlock = builder_.GetInsertBlock();
                builder_.CreateBr(mergeBlock);
                builder_.SetInsertPoint(mergeBlock);
                auto* result = builder_.CreatePHI(builder_.getInt1Ty(), 2);
                result->addIncoming(
                    binary->op == TokenKind::AndAnd
                        ? builder_.getFalse() : builder_.getTrue(),
                    leftBlock);
                result->addIncoming(right, rightBlock);
                return result;
            }
            auto* right = emitExpr(*binary->right);
            if (!right) return nullptr;
            const auto operandType =
                semantic().expressionTypes.find(binary->left.get());
            const auto operationType =
                operandType == semantic().expressionTypes.end()
                ? semanticType
                : substituteActive(operandType->second);
            const bool floating = isFloat(operationType);
            switch (binary->op) {
            case TokenKind::EqualEqual:
                return floating ? builder_.CreateFCmpOEQ(left, right)
                                : builder_.CreateICmpEQ(left, right);
            case TokenKind::BangEqual:
                return floating ? builder_.CreateFCmpONE(left, right)
                                : builder_.CreateICmpNE(left, right);
            case TokenKind::Less:
                if (floating) return builder_.CreateFCmpOLT(left, right);
                return isSignedInteger(operationType)
                    ? builder_.CreateICmpSLT(left, right)
                    : builder_.CreateICmpULT(left, right);
            case TokenKind::LessEqual:
                if (floating) return builder_.CreateFCmpOLE(left, right);
                return isSignedInteger(operationType)
                    ? builder_.CreateICmpSLE(left, right)
                    : builder_.CreateICmpULE(left, right);
            case TokenKind::Greater:
                if (floating) return builder_.CreateFCmpOGT(left, right);
                return isSignedInteger(operationType)
                    ? builder_.CreateICmpSGT(left, right)
                    : builder_.CreateICmpUGT(left, right);
            case TokenKind::GreaterEqual:
                if (floating) return builder_.CreateFCmpOGE(left, right);
                return isSignedInteger(operationType)
                    ? builder_.CreateICmpSGE(left, right)
                    : builder_.CreateICmpUGE(left, right);
            case TokenKind::Plus:
                return floating ? builder_.CreateFAdd(left, right) : builder_.CreateAdd(left, right);
            case TokenKind::Minus:
                return floating ? builder_.CreateFSub(left, right) : builder_.CreateSub(left, right);
            case TokenKind::Star:
                return floating ? builder_.CreateFMul(left, right) : builder_.CreateMul(left, right);
            case TokenKind::Slash:
                if (floating) return builder_.CreateFDiv(left, right);
                return isSignedInteger(semanticType)
                    ? builder_.CreateSDiv(left, right) : builder_.CreateUDiv(left, right);
            case TokenKind::Percent:
                if (floating) return builder_.CreateFRem(left, right);
                return isSignedInteger(semanticType)
                    ? builder_.CreateSRem(left, right) : builder_.CreateURem(left, right);
            default: break;
            }
        }
        if (const auto* postfix =
                std::get_if<PostfixExpr>(&expression.node)) {
            if (postfix->op == TokenKind::Bang) {
                auto* nullable = emitExpr(*postfix->value);
                if (!nullable) return nullptr;
                auto* hasValue =
                    builder_.CreateExtractValue(nullable, 0);
                auto* function =
                    builder_.GetInsertBlock()->getParent();
                auto* validBlock = llvm::BasicBlock::Create(
                    context_, "nullable.valid", function);
                auto* panicBlock = llvm::BasicBlock::Create(
                    context_, "nullable.panic", function);
                builder_.CreateCondBr(
                    hasValue, validBlock, panicBlock);
                builder_.SetInsertPoint(panicBlock);
                constexpr std::string_view message{
                    "nullable value is null"};
                auto* text = builder_.CreateGlobalString(message);
                auto panic = result_.module->getOrInsertFunction(
                    "k_boot_panic",
                    llvm::FunctionType::get(
                        llvm::Type::getVoidTy(context_),
                        {builder_.getPtrTy(), builder_.getInt64Ty()},
                        false));
                builder_.CreateCall(
                    panic,
                    {text, llvm::ConstantInt::get(
                               builder_.getInt64Ty(),
                               message.size())});
                builder_.CreateUnreachable();
                builder_.SetInsertPoint(validBlock);
                return builder_.CreateExtractValue(nullable, 1);
            }
        }
        if (const auto* unary = std::get_if<UnaryExpr>(&expression.node)) {
            if (unary->op == TokenKind::Ampersand) {
                const auto* identifier =
                    std::get_if<IdentifierExpr>(&unary->operand->node);
                if (!identifier) return nullptr;
                const auto local = locals_.find(
                    spelling(source(), identifier->name));
                return local == locals_.end()
                    ? nullptr : local->second.address;
            }
            auto* operand = emitExpr(*unary->operand);
            if (!operand) return nullptr;
            if (unary->op == TokenKind::Star) {
                auto* type = lowerType(semanticType, expression.span);
                if (!type) return nullptr;
                return builder_.CreateLoad(type, operand);
            }
            if (unary->op == TokenKind::Minus)
                return isFloat(semanticType)
                    ? builder_.CreateFNeg(operand) : builder_.CreateNeg(operand);
            if (unary->op == TokenKind::Plus) return operand;
            if (unary->op == TokenKind::Bang) return builder_.CreateNot(operand);
        }
        diagnose("expression is not supported by the LLVM backend yet", expression.span);
        return nullptr;
    }

    llvm::Value* emitIndexPointer(const IndexExpr& index) {
        const auto type = semantic().expressionTypes.find(index.object.get());
        if (type == semantic().expressionTypes.end()) {
            diagnose("indexed value has no semantic type", index.object->span);
            return nullptr;
        }
        if (type->second.kind == SemanticTypeKind::Pointer) {
            auto* pointer = emitExpr(*index.object);
            auto* indexValue = emitExpr(*index.index);
            if (!pointer || !indexValue) return nullptr;
            auto* elementType = lowerType(
                *type->second.element, index.object->span);
            return builder_.CreateInBoundsGEP(
                elementType, pointer, indexValue);
        }
        const auto* object = std::get_if<IdentifierExpr>(&index.object->node);
        if (!object) {
            diagnose("array and slice indexing requires a local collection",
                     index.object->span);
            return nullptr;
        }
        const auto name = spelling(source(), object->name);
        const auto local = locals_.find(name);
        if (type->second.kind == SemanticTypeKind::Slice) {
            if (local == locals_.end()) return nullptr;
            auto* sliceType = llvm::cast<llvm::StructType>(
                lowerType(type->second, index.object->span));
            auto* slice =
                builder_.CreateLoad(sliceType, local->second.address);
            auto* data = builder_.CreateExtractValue(slice, 0);
            auto* length = builder_.CreateExtractValue(slice, 1);
            auto* indexValue = emitExpr(*index.index);
            if (!indexValue) return nullptr;
            auto* comparableIndex = indexValue;
            if (indexValue->getType() != builder_.getInt64Ty())
                comparableIndex =
                    builder_.CreateZExtOrTrunc(
                        indexValue, builder_.getInt64Ty());
            emitBoundsCheck(comparableIndex, length);
            auto* elementType = lowerType(
                *type->second.element, index.object->span);
            return builder_.CreateInBoundsGEP(
                elementType, data, comparableIndex);
        }
        if (type->second.kind != SemanticTypeKind::Array ||
            type->second.arraySizeKind != ArraySizeKind::Known) {
            diagnose("indexed value is not an array or slice",
                     index.object->span);
            return nullptr;
        }
        auto* arrayType = llvm::cast<llvm::ArrayType>(
            lowerType(type->second, index.object->span));
        llvm::Value* address = nullptr;
        if (local != locals_.end()) {
            address = local->second.address;
        } else if (semantic().constants.contains(name)) {
            auto* value = emitExpr(*index.object);
            if (!value) return nullptr;
            address = builder_.CreateAlloca(arrayType, nullptr, name + ".const");
            builder_.CreateStore(value, address);
        } else {
            return nullptr;
        }
        auto* indexValue = emitExpr(*index.index);
        if (!indexValue) return nullptr;
        if (!std::holds_alternative<LiteralExpr>(index.index->node)) {
            auto* length = llvm::ConstantInt::get(
                indexValue->getType(), type->second.knownArraySize);
            emitBoundsCheck(indexValue, length);
        }
        return builder_.CreateInBoundsGEP(
            arrayType, address,
            {builder_.getInt32(0), indexValue});
    }

    llvm::Value* emitArrayToSlice(
        const Expr& expression,
        const SemanticType& sliceType) {
        const auto* identifier =
            std::get_if<IdentifierExpr>(&expression.node);
        if (!identifier) {
            diagnose("array-to-slice conversion requires a local array",
                     expression.span);
            return nullptr;
        }
        const auto local =
            locals_.find(spelling(source(), identifier->name));
        const auto arraySemantic =
            semantic().expressionTypes.find(&expression);
        if (local == locals_.end() ||
            arraySemantic == semantic().expressionTypes.end()) return nullptr;
        auto* arrayType = llvm::cast<llvm::ArrayType>(
            lowerType(arraySemantic->second, expression.span));
        auto* data = builder_.CreateInBoundsGEP(
            arrayType, local->second.address,
            {builder_.getInt32(0), builder_.getInt32(0)});
        auto* llvmSlice = lowerType(sliceType, expression.span);
        llvm::Value* value = llvm::UndefValue::get(llvmSlice);
        value = builder_.CreateInsertValue(value, data, 0);
        return builder_.CreateInsertValue(
            value,
            llvm::ConstantInt::get(
                builder_.getInt64Ty(),
                arraySemantic->second.knownArraySize),
            1);
    }

    llvm::Value* liftNullable(
        llvm::Value* value,
        const SemanticType& target,
        SourceSpan span) {
        auto* nullableType = lowerType(target, span);
        if (!nullableType) return nullptr;
        llvm::Value* nullable =
            llvm::UndefValue::get(nullableType);
        nullable = builder_.CreateInsertValue(
            nullable, builder_.getTrue(), 0);
        return builder_.CreateInsertValue(nullable, value, 1);
    }

    void emitBoundsCheck(llvm::Value* index, llvm::Value* length) {
        auto* inBounds = builder_.CreateICmpULT(index, length);
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* validBlock =
            llvm::BasicBlock::Create(context_, "index.valid", function);
        auto* panicBlock =
            llvm::BasicBlock::Create(context_, "index.panic", function);
        builder_.CreateCondBr(inBounds, validBlock, panicBlock);
        builder_.SetInsertPoint(panicBlock);
        constexpr std::string_view message{"index out of bounds"};
        auto* text = builder_.CreateGlobalString(message);
        auto panic = result_.module->getOrInsertFunction(
            "k_boot_panic",
            llvm::FunctionType::get(
                llvm::Type::getVoidTy(context_),
                {builder_.getPtrTy(), builder_.getInt64Ty()}, false));
        builder_.CreateCall(
            panic,
            {text, llvm::ConstantInt::get(
                       builder_.getInt64Ty(), message.size())});
        builder_.CreateUnreachable();
        builder_.SetInsertPoint(validBlock);
    }

    void emitIntegerCastRangeCheck(
        llvm::Value* value, const IntegerCastInfo& cast) {
        const auto sourceWidth = numericBitWidth(cast.sourceType);
        const auto targetWidth = numericBitWidth(cast.targetType);
        llvm::Value* valid = builder_.getTrue();
        const auto append = [&](llvm::Value* condition) {
            valid = builder_.CreateAnd(valid, condition);
        };
        if (isSignedInteger(cast.sourceType)) {
            if (!isSignedInteger(cast.targetType)) {
                append(builder_.CreateICmpSGE(
                    value, llvm::ConstantInt::get(value->getType(), 0)));
                if (targetWidth < sourceWidth) {
                    const auto maximum =
                        llvm::APInt::getMaxValue(targetWidth).zext(sourceWidth);
                    append(builder_.CreateICmpSLE(
                        value, llvm::ConstantInt::get(context_, maximum)));
                }
            } else {
                const auto minimum =
                    llvm::APInt::getSignedMinValue(targetWidth).sext(sourceWidth);
                const auto maximum =
                    llvm::APInt::getSignedMaxValue(targetWidth).sext(sourceWidth);
                append(builder_.CreateICmpSGE(
                    value, llvm::ConstantInt::get(context_, minimum)));
                append(builder_.CreateICmpSLE(
                    value, llvm::ConstantInt::get(context_, maximum)));
            }
        } else {
            const auto maximum = isSignedInteger(cast.targetType)
                ? llvm::APInt::getSignedMaxValue(targetWidth).zext(sourceWidth)
                : llvm::APInt::getMaxValue(targetWidth).zext(sourceWidth);
            append(builder_.CreateICmpULE(
                value, llvm::ConstantInt::get(context_, maximum)));
        }
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* validBlock =
            llvm::BasicBlock::Create(context_, "cast.valid", function);
        auto* panicBlock =
            llvm::BasicBlock::Create(context_, "cast.panic", function);
        builder_.CreateCondBr(valid, validBlock, panicBlock);
        builder_.SetInsertPoint(panicBlock);
        constexpr std::string_view message{"integer cast out of range"};
        auto* text = builder_.CreateGlobalString(message);
        auto panic = result_.module->getOrInsertFunction(
            "k_boot_panic",
            llvm::FunctionType::get(
                llvm::Type::getVoidTy(context_),
                {builder_.getPtrTy(), builder_.getInt64Ty()}, false));
        builder_.CreateCall(
            panic,
            {text, llvm::ConstantInt::get(
                       builder_.getInt64Ty(), message.size())});
        builder_.CreateUnreachable();
        builder_.SetInsertPoint(validBlock);
    }

    void emitFloatCastRangeCheck(
        llvm::Value* value, const FloatCastInfo& cast) {
        const auto targetWidth = numericBitWidth(cast.targetType);
        llvm::Value* aboveMinimum = nullptr;
        if (isSignedInteger(cast.targetType)) {
            const auto limit = std::ldexp(1.0, targetWidth - 1);
            const auto precision = cast.sourceType.kind == SemanticTypeKind::F32
                ? 24u : 53u;
            if (targetWidth >= precision) {
                aboveMinimum = builder_.CreateFCmpOGE(
                    value, llvm::ConstantFP::get(value->getType(), -limit));
            } else {
                aboveMinimum = builder_.CreateFCmpOGT(
                    value, llvm::ConstantFP::get(value->getType(), -limit - 1.0));
            }
        } else {
            aboveMinimum = builder_.CreateFCmpOGT(
                value, llvm::ConstantFP::get(value->getType(), -1.0));
        }
        const auto upper = std::ldexp(
            1.0, isSignedInteger(cast.targetType)
                ? targetWidth - 1 : targetWidth);
        auto* belowMaximum = builder_.CreateFCmpOLT(
            value, llvm::ConstantFP::get(value->getType(), upper));
        auto* valid = builder_.CreateAnd(aboveMinimum, belowMaximum);
        auto* function = builder_.GetInsertBlock()->getParent();
        auto* validBlock =
            llvm::BasicBlock::Create(context_, "float.cast.valid", function);
        auto* panicBlock =
            llvm::BasicBlock::Create(context_, "float.cast.panic", function);
        builder_.CreateCondBr(valid, validBlock, panicBlock);
        builder_.SetInsertPoint(panicBlock);
        constexpr std::string_view message{"float cast out of range"};
        auto* text = builder_.CreateGlobalString(message);
        auto panic = result_.module->getOrInsertFunction(
            "k_boot_panic",
            llvm::FunctionType::get(
                llvm::Type::getVoidTy(context_),
                {builder_.getPtrTy(), builder_.getInt64Ty()}, false));
        builder_.CreateCall(
            panic,
            {text, llvm::ConstantInt::get(
                       builder_.getInt64Ty(), message.size())});
        builder_.CreateUnreachable();
        builder_.SetInsertPoint(validBlock);
    }

    void verify() {
        std::string message;
        llvm::raw_string_ostream output{message};
        if (llvm::verifyModule(*result_.module, &output))
            diagnose("LLVM verification failed: " + output.str(), current_->program->span);
    }

    void diagnose(std::string message, SourceSpan span) {
        result_.diagnostics.push_back({std::move(message), span});
    }

    std::vector<ParsedModule> modules_;
    ParsedModule* current_ = nullptr;
    llvm::LLVMContext& context_;
    llvm::IRBuilder<> builder_;
    CodegenResult result_;
    std::unordered_map<const FunctionDecl*, llvm::Function*> functions_;
    std::unordered_map<std::string, llvm::Function*> functionsByName_;
    std::unordered_map<std::string, llvm::Function*>
        specializedFunctions_;
    std::vector<PendingSpecialization> pendingSpecializations_;
    std::vector<SemanticType> activeTypeArguments_;
    std::unordered_map<std::string, llvm::StructType*> structs_;
    std::unordered_map<std::string, llvm::StructType*> specializedStructs_;
    std::unordered_map<std::string, LocalSlot> locals_;
    std::vector<std::pair<llvm::BasicBlock*, llvm::BasicBlock*>> loopTargets_;
};

}

LlvmCodegen::LlvmCodegen(
    std::vector<ParsedModule> modules,
    llvm::LLVMContext& context)
    : modules_{std::move(modules)}, context_{context} {}

CodegenResult LlvmCodegen::generate() {
    if (modules_.empty()) return {};
    return Generator{std::move(modules_), context_}.run();
}

}
