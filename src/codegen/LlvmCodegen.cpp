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

class Generator {
public:
    Generator(
        const Source& source,
        const Program& program,
        const SemanticResult& semantic,
        llvm::LLVMContext& context)
        : source_{source},
          program_{program},
          semantic_{semantic},
          context_{context},
          builder_{context} {
        result_.module = std::make_unique<llvm::Module>(
            std::string{source.path()}, context);
    }

    CodegenResult run() {
        declareStructs();
        declareFunctions();
        for (const auto& specialization :
             semantic_.requestedSpecializations)
            getOrDeclareSpecialization(specialization);
        if (result_.diagnostics.empty()) {
            for (const auto& function : program_.functions)
                emitFunction(function);
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
        case SemanticTypeKind::U32: return llvm::Type::getInt32Ty(context_);
        case SemanticTypeKind::I64:
        case SemanticTypeKind::U64: return llvm::Type::getInt64Ty(context_);
        case SemanticTypeKind::I128:
        case SemanticTypeKind::U128: return llvm::Type::getInt128Ty(context_);
        case SemanticTypeKind::F32: return llvm::Type::getFloatTy(context_);
        case SemanticTypeKind::F64: return llvm::Type::getDoubleTy(context_);
        case SemanticTypeKind::Pointer:
            return llvm::PointerType::getUnqual(context_);
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
        for (const auto& structure : program_.structs) {
            if (!structure.typeParameters.empty()) continue;
            const auto name = spelling(source_, structure.name);
            structs_.emplace(
                name, llvm::StructType::create(context_, name));
        }
        for (const auto& [name, symbol] : semantic_.structs) {
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
        const auto symbol = semantic_.structs.find(type.name);
        if (symbol == semantic_.structs.end()) {
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
        for (const auto& function : program_.functions) {
            if (!function.typeParameters.empty()) continue;
            const auto name = spelling(source_, function.name);
            const auto symbol = semantic_.functions.find(name);
            if (symbol == semantic_.functions.end()) continue;
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
        return spelling(source_, declaration.name) +
            "__g" + std::to_string(hash);
    }

    const FunctionSymbol* functionSymbol(
        const FunctionDecl& declaration) const {
        const auto found = semantic_.functions.find(
            spelling(source_, declaration.name));
        if (found == semantic_.functions.end() ||
            found->second.declaration != &declaration)
            return nullptr;
        return &found->second;
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
        auto* entry = llvm::BasicBlock::Create(context_, "entry", function);
        builder_.SetInsertPoint(entry);
        locals_.clear();

        std::size_t parameterIndex = 0;
        for (auto& argument : function->args()) {
            const auto& parameter = declaration.parameters[parameterIndex];
            const auto name = spelling(source_, parameter.name);
            argument.setName(name);
            if (parameter.mode == ParameterMode::MutableBorrow) {
                const auto symbol = semantic_.functions.find(
                    spelling(source_, declaration.name));
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

        for (const auto& statement : declaration.body->statements) {
            emitStatement(*statement);
            if (builder_.GetInsertBlock()->getTerminator()) break;
        }
        if (!builder_.GetInsertBlock()->getTerminator() &&
            function->getReturnType()->isVoidTy()) {
            builder_.CreateRetVoid();
        }
        activeTypeArguments_ = outerTypeArguments;
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
        if (const auto* variable = std::get_if<VariableDecl>(&statement.node)) {
            llvm::Value* value = nullptr;
            const auto declared = semantic_.declarationTypes.find(variable);
            const auto initializerType =
                semantic_.expressionTypes.find(variable->initializer.get());
            if (declared != semantic_.declarationTypes.end() &&
                declared->second.kind == SemanticTypeKind::Slice &&
                initializerType != semantic_.expressionTypes.end() &&
                initializerType->second.kind == SemanticTypeKind::Array) {
                value = emitArrayToSlice(
                    *variable->initializer, declared->second);
            } else {
                value = emitExpr(*variable->initializer);
            }
            if (!value) return;
            const auto name = spelling(source_, variable->name);
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
                        semantic_.implicitConversions.find(
                            returnStatement->value.get());
                    if (conversion != semantic_.implicitConversions.end())
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
        emitScopedBlock(*statement.body);
        if (!builder_.GetInsertBlock()->getTerminator())
            builder_.CreateBr(conditionBlock);
        builder_.SetInsertPoint(exitBlock);
    }

    llvm::Value* emitExpr(const Expr& expression) {
        const auto typeFound = semantic_.expressionTypes.find(&expression);
        if (typeFound == semantic_.expressionTypes.end()) {
            diagnose("expression has no semantic type", expression.span);
            return nullptr;
        }
        const auto semanticType =
            substituteActive(typeFound->second);
        if (std::holds_alternative<SizeofExpr>(expression.node)) {
            const auto sized = semantic_.sizeofTypes.find(&expression);
            if (sized == semantic_.sizeofTypes.end()) return nullptr;
            auto* type = lowerType(sized->second, expression.span);
            if (!type) return nullptr;
            return llvm::ConstantExpr::getSizeOf(type);
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
                semantic_.expressionTypes.find(cast->value.get());
            if (sourceType != semantic_.expressionTypes.end() &&
                sourceType->second.kind == SemanticTypeKind::Pointer &&
                semanticType.kind == SemanticTypeKind::Pointer)
                return emitExpr(*cast->value);
            if (sourceType != semantic_.expressionTypes.end() &&
                isInteger(sourceType->second) && isInteger(semanticType)) {
                auto* value = emitExpr(*cast->value);
                if (!value) return nullptr;
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
            diagnose("cast is not supported by the LLVM backend yet",
                     expression.span);
            return nullptr;
        }
        if (const auto* call = std::get_if<CallExpr>(&expression.node)) {
            const auto* callee = std::get_if<IdentifierExpr>(&call->callee->node);
            if (callee && spelling(source_, callee->name) == "print" &&
                call->arguments.size() == 1) {
                const auto& argument = *call->arguments.front();
                const auto argumentType = semantic_.expressionTypes.find(&argument);
                if (argumentType != semantic_.expressionTypes.end() &&
                    argumentType->second.kind == SemanticTypeKind::String) {
                    const auto* literal = std::get_if<LiteralExpr>(&argument.node);
                    if (!literal) {
                        diagnose("print string currently requires a literal", argument.span);
                        return nullptr;
                    }
                    auto text = spelling(source_, literal->spelling);
                    text = text.substr(1, text.size() - 2);
                    auto* pointer = builder_.CreateGlobalString(text);
                    auto function = result_.module->getOrInsertFunction(
                        "k_std_print_bytes",
                        llvm::FunctionType::get(
                            llvm::Type::getVoidTy(context_),
                            {builder_.getPtrTy(), builder_.getInt64Ty()}, false));
                    return builder_.CreateCall(
                        function,
                        {pointer, llvm::ConstantInt::get(builder_.getInt64Ty(), text.size())});
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
                const auto name = spelling(source_, callee->name);
                if (const auto resolved =
                        semantic_.resolvedCalls.find(call);
                    resolved != semantic_.resolvedCalls.end() &&
                    resolved->second.function &&
                    !resolved->second.function->typeParameters.empty()) {
                    std::vector<SemanticType> concreteArguments;
                    concreteArguments.reserve(
                        resolved->second.typeArguments.size());
                    for (const auto& argument :
                         resolved->second.typeArguments)
                        concreteArguments.push_back(
                            substituteActive(argument));
                    auto* target = getOrDeclareSpecialization(
                        SpecializationKey{
                            resolved->second.function->declaration,
                            concreteArguments});
                    if (!target) return nullptr;
                    std::vector<llvm::Value*> arguments;
                    arguments.reserve(call->arguments.size());
                    for (std::size_t i = 0;
                         i < call->arguments.size(); ++i) {
                        llvm::Value* value = nullptr;
                        if (i < resolved->second.function->declaration
                                    ->parameters.size() &&
                            resolved->second.function->declaration
                                    ->parameters[i].mode ==
                                ParameterMode::MutableBorrow) {
                            const auto* identifier =
                                std::get_if<IdentifierExpr>(
                                    &call->arguments[i]->node);
                            if (identifier) {
                                const auto local = locals_.find(
                                    spelling(
                                        source_,
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
                if (const auto structure = semantic_.structs.find(name);
                    structure != semantic_.structs.end()) {
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
                const auto semanticFunction = semantic_.functions.find(name);
                for (std::size_t i = 0; i < call->arguments.size(); ++i) {
                    llvm::Value* value = nullptr;
                    if (semanticFunction != semantic_.functions.end() &&
                        i < semanticFunction->second.declaration->parameters.size() &&
                        semanticFunction->second.declaration->parameters[i].mode ==
                            ParameterMode::MutableBorrow) {
                        const auto* identifier =
                            std::get_if<IdentifierExpr>(
                                &call->arguments[i]->node);
                        if (identifier) {
                            const auto local = locals_.find(
                                spelling(source_, identifier->name));
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
            auto text = spelling(source_, literal->spelling);
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
            const auto name = spelling(source_, identifier->name);
            const auto found = locals_.find(name);
            if (found == locals_.end()) {
                diagnose("unknown local during LLVM codegen", identifier->name);
                return nullptr;
            }
            return builder_.CreateLoad(
                found->second.type, found->second.address,
                name + ".value");
        }
        if (const auto* member = std::get_if<MemberExpr>(&expression.node)) {
            const auto objectType =
                semantic_.expressionTypes.find(member->object.get());
            if (objectType == semantic_.expressionTypes.end() ||
                objectType->second.kind != SemanticTypeKind::Struct) {
                diagnose("member object has no struct type during LLVM codegen",
                         member->object->span);
                return nullptr;
            }
            const auto structure = semantic_.structs.find(objectType->second.name);
            if (structure == semantic_.structs.end()) return nullptr;
            const auto fieldName = spelling(source_, member->name);
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
                const auto localName = spelling(source_, object->name);
                const auto local = locals_.find(localName);
                if (local == locals_.end()) return nullptr;
                const auto objectType =
                    semantic_.expressionTypes.find(member->object.get());
                if (objectType == semantic_.expressionTypes.end()) return nullptr;
                const auto structure =
                    semantic_.structs.find(objectType->second.name);
                if (structure == semantic_.structs.end()) return nullptr;
                auto* llvmStructure = lowerType(
                    objectType->second, member->object->span);
                if (!llvmStructure) return nullptr;
                const auto fieldName = spelling(source_, member->name);
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
            const auto name = spelling(source_, target->name);
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
            auto* right = emitExpr(*binary->right);
            if (!left || !right) return nullptr;
            const auto operandType =
                semantic_.expressionTypes.find(binary->left.get());
            const auto operationType =
                operandType == semantic_.expressionTypes.end()
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
                    spelling(source_, identifier->name));
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
        }
        diagnose("expression is not supported by the LLVM backend yet", expression.span);
        return nullptr;
    }

    llvm::Value* emitIndexPointer(const IndexExpr& index) {
        const auto type = semantic_.expressionTypes.find(index.object.get());
        if (type == semantic_.expressionTypes.end()) {
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
        const auto name = spelling(source_, object->name);
        const auto local = locals_.find(name);
        if (local == locals_.end()) return nullptr;
        if (type->second.kind == SemanticTypeKind::Slice) {
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
        auto* indexValue = emitExpr(*index.index);
        if (!indexValue) return nullptr;
        if (!std::holds_alternative<LiteralExpr>(index.index->node)) {
            auto* length = llvm::ConstantInt::get(
                indexValue->getType(), type->second.knownArraySize);
            emitBoundsCheck(indexValue, length);
        }
        return builder_.CreateInBoundsGEP(
            arrayType, local->second.address,
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
            locals_.find(spelling(source_, identifier->name));
        const auto arraySemantic =
            semantic_.expressionTypes.find(&expression);
        if (local == locals_.end() ||
            arraySemantic == semantic_.expressionTypes.end()) return nullptr;
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

    void verify() {
        std::string message;
        llvm::raw_string_ostream output{message};
        if (llvm::verifyModule(*result_.module, &output))
            diagnose("LLVM verification failed: " + output.str(), program_.span);
    }

    void diagnose(std::string message, SourceSpan span) {
        result_.diagnostics.push_back({std::move(message), span});
    }

    const Source& source_;
    const Program& program_;
    const SemanticResult& semantic_;
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
};

}

LlvmCodegen::LlvmCodegen(
    const Source& source,
    const Program& program,
    const SemanticResult& semantic,
    llvm::LLVMContext& context)
    : source_{source}, program_{program}, semantic_{semantic}, context_{context} {}

CodegenResult LlvmCodegen::generate() {
    return Generator{source_, program_, semantic_, context_}.run();
}

}
