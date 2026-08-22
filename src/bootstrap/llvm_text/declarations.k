module bootstrap.llvm_text.declarations;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;
import bootstrap.containers.StringBuilder;
import bootstrap.lexer.lex;
import bootstrap.ast.AstNode;
import bootstrap.ast.AstKind;
import bootstrap.parser.mod.parse;
import bootstrap.types.TypeValue;
import bootstrap.types.TypeKind;
import bootstrap.types.typeKindFromValue;
import bootstrap.diagnostic.SemanticResult;
import bootstrap.semantic.mod.analyze;
import bootstrap.llvm_text.mod.emitModule;
import bootstrap.token.TokenKind;

fn declarationRoots(val nodes: List<AstNode>): u64* {
    val programRoot = nodes.length - 1;
    val program = nodes.data[programRoot];
    val roots =
        k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
    var root = programRoot - 1;
    for (index in program.aux>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    return roots;
}

fn structRootByName(
    source: Source, val nodes: List<AstNode>, name: u64): u64 {
    val program = nodes.data[nodes.length - 1];
    val roots = declarationRoots(nodes);
    var found = nodes.length;
    for (index in 0..<program.aux) {
        val root = roots[index as u64];
        val node = nodes.data[root];
        if (node.kind == AstKind.STRUCT_DECLARATION) {
            val nameNode = nodes.data[node.subtreeStart];
            if (source.hash(nameNode.start, nameNode.end) == name) {
                found = root;
            }
        }
    }
    k_boot_free(roots as unit*);
    return found;
}

fn functionRootByName(
    source: Source, val nodes: List<AstNode>, name: u64): u64 {
    val program = nodes.data[nodes.length - 1];
    val roots = declarationRoots(nodes);
    var found = nodes.length;
    for (index in 0..<program.aux) {
        val root = roots[index as u64];
        val node = nodes.data[root];
        if (node.kind == AstKind.FUNCTION_OR_DEFER) {
            val nameNode = nodes.data[node.subtreeStart];
            if (source.hash(nameNode.start, nameNode.end) == name) {
                found = root;
            }
        }
    }
    k_boot_free(roots as unit*);
    return found;
}

fn emitterDropFunctionRoot(
    source: Source, val nodes: List<AstNode>, typeName: u64): u64 {
    val structureRoot = structRootByName(source, nodes, typeName);
    if (structureRoot == nodes.length) return nodes.length;
    var methodRoot = structureRoot - 1;
    for (index in 0..<emitterStructMethodCount(nodes.data[structureRoot])) {
        val method = nodes.data[methodRoot];
        val name = nodes.data[method.subtreeStart];
        if (source.hash(name.start, name.end) == 6385234055)
            return methodRoot;
        methodRoot = method.subtreeStart - 1;
    }
    return nodes.length;
}

fn emitterVariableRootByStorage(
    val nodes: List<AstNode>, storage: u64): u64 {
    for (root in 0..<nodes.length) {
        val node = nodes.data[root];
        if (node.kind == AstKind.VARIABLE_DECLARATION) {
            val name = nodes.data[node.subtreeStart];
            if (name.start == storage) return root;
        }
    }
    return nodes.length;
}

fn emitterRootBeforeStructMethods(val nodes: List<AstNode>, structureRoot: u64): u64 {
    var root = structureRoot - 1;
    val remaining = emitterStructMethodCount(nodes.data[structureRoot]);
    for (method in 0..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn emitterAssociatedOwnerStructRoot(
    val nodes: List<AstNode>, functionRoot: u64): u64 {
    if (nodes.data[functionRoot].conversionKind != 2) return nodes.length;
    val program = nodes.data[nodes.length - 1];
    val roots = declarationRoots(nodes);
    var owner = nodes.length;
    for (index in 0..<program.aux) {
        val structureRoot = roots[index as u64];
        if (nodes.data[structureRoot].kind == AstKind.STRUCT_DECLARATION) {
            var methodRoot = structureRoot - 1;
            val methodCount = emitterStructMethodCount(
                nodes.data[structureRoot]);
            for (methodIndex in 0..<methodCount) {
                if (methodRoot == functionRoot) owner = structureRoot;
                methodRoot = nodes.data[methodRoot].subtreeStart - 1;
            }
        }
    }
    k_boot_free(roots as unit*);
    return owner;
}

fn emitterFieldRootAt(
    val nodes: List<AstNode>, structureRoot: u64, wanted: u32): u64 {
    val structure = nodes.data[structureRoot];
    var roots =
        k_boot_alloc((emitterStructFieldCount(structure) as u64) * sizeof(u64)) as u64*;
    var root = emitterRootBeforeStructMethods(nodes, structureRoot);
    val remaining = emitterStructFieldCount(structure);
    for (index in remaining>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    val result = roots[wanted as u64];
    k_boot_free(roots as unit*);
    return result;
}

fn fieldIndexByName(
    source: Source, val nodes: List<AstNode>, structureRoot: u64,
    nameNode: AstNode): u32 {
    val wanted = source.hash(nameNode.start, nameNode.end);
    val structure = nodes.data[structureRoot];
    val fieldCount = emitterStructFieldCount(structure);
    for (index in 0..<fieldCount) {
        val field = nodes.data[emitterFieldRootAt(nodes, structureRoot, index)];
        val fieldName = nodes.data[field.subtreeStart];
        if (source.hash(fieldName.start, fieldName.end) == wanted) {
            return index;
        }
    }
    return fieldCount;
}

fn parameterRoot(
    val nodes: List<AstNode>, functionRoot: u64, position: u32): u64 {
    val function = nodes.data[functionRoot];
    var root = functionRoot - 1;
    if (!function.isExtern()) {
        root = nodes.data[root].subtreeStart - 1;
    }
    val remaining = function.parameterCount();
    for (index in position - 1..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn returnTypeRoot(val nodes: List<AstNode>, functionRoot: u64): u64 {
    if (nodes.data[functionRoot].isExtern()) {
        return functionRoot - 1;
    }
    return nodes.data[functionRoot - 1].subtreeStart - 1;
}

fn emitVariableAlloca(
    var buffer: StringBuilder, var genericArguments: List<TypeValue>, val nodes: List<AstNode>, root: u64) {
    val statement = nodes.data[root];
    val initializerRoot = root - 1;
    val initializer = nodes.data[initializerRoot];
    var storageKind = initializer.typeKind;
    var storageName = initializer.typeName;
    var storagePointee = initializer.typePointee;
    val afterName = statement.subtreeStart + 1;
    if (afterName < initializer.subtreeStart) {
        val declaredType =
            nodes.data[initializer.subtreeStart - 1];
        storageKind = declaredType.typeKind;
        storageName = declaredType.typeName;
        storagePointee = declaredType.typePointee;
    }
    val name = nodes.data[statement.subtreeStart];
    appendValuePrefix(buffer);
    appendLocalPrefix(buffer);
    appendDecimal(buffer, name.start);
    appendEquals(buffer);
    appendAlloca(buffer);
    appendType(
        buffer, genericArguments, storageKind, storageName, storagePointee);
    appendNewline(buffer);
    if ((statement.ownership / 2) % 2 == 1) {
        appendValuePrefix(buffer); appendDropFlagName(buffer, name.start);
        appendEquals(buffer); appendAlloca(buffer);
        buffer.append("i1"); appendNewline(buffer);
    }
}

fn emitBlockAllocas(
    var buffer: StringBuilder, var genericArguments: List<TypeValue>, val nodes: List<AstNode>, blockRoot: u64) {
    val roots = blockStatementRoots(nodes, blockRoot);
    for (index in 0..<nodes.data[blockRoot].aux) {
        val root = roots[index as u64];
        val statement = nodes.data[root];
        if (statement.kind == AstKind.VARIABLE_DECLARATION) {
            emitVariableAlloca(buffer, genericArguments, nodes, root);
        }
        if (statement.kind == AstKind.BLOCK) {
            emitBlockAllocas(buffer, genericArguments, nodes, root);
        }
        if (statement.kind == AstKind.IF_STATEMENT) {
            var branchRoot = root - 1;
            if (statement.aux == 1) {
                emitBlockAllocas(buffer, genericArguments, nodes, branchRoot);
                branchRoot = expressionChildBefore(nodes, branchRoot);
            }
            emitBlockAllocas(buffer, genericArguments, nodes, branchRoot);
        }
        if (statement.kind == AstKind.WHILE_STATEMENT) {
            emitBlockAllocas(buffer, genericArguments, nodes, root - 1);
        }
        if (statement.kind == AstKind.FOR_STATEMENT) {
            val bodyRoot = root - 1;
            val collectionRoot = expressionChildBefore(nodes, bodyRoot);
            val name = nodes.data[statement.subtreeStart];
            val collection = nodes.data[collectionRoot];
            var range = collection.kind == AstKind.BINARY;
            if (range) {
                range = collection.aux == TokenKind.RANGE.value;
                if (collection.aux == TokenKind.RANGE_EXCLUSIVE.value) range = true;
                if (collection.aux == TokenKind.RANGE_EXCLUSIVE_START.value) range = true;
                if (collection.aux == TokenKind.RANGE_EXCLUSIVE_BOTH.value) range = true;
            }
            appendValuePrefix(buffer); appendLocalPrefix(buffer);
            appendDecimal(buffer, name.start); appendEquals(buffer);
            appendAlloca(buffer);
            if (range) {
                appendNodeType(buffer, genericArguments, collection);
            } else {
                var elementKind = collection.typePointee;
                if (collection.typeKind == TypeKind.ARRAY.value) {
                    elementKind = collection.typePointee % 256;
                }
                appendType(
                    buffer, genericArguments,
                    elementKind, collection.typeName, 0);
            }
            appendNewline(buffer);
            if (!range) {
                var indexStorage = statement.start;
                if (statement.aux == 1) {
                    indexStorage = nodes.data[statement.subtreeStart + 1].start;
                }
                appendValuePrefix(buffer); appendLocalPrefix(buffer);
                appendDecimal(buffer, indexStorage); appendEquals(buffer);
                appendAlloca(buffer); appendI64(buffer); appendNewline(buffer);
            }
            emitBlockAllocas(buffer, genericArguments, nodes, bodyRoot);
        }
        if (statement.kind == AstKind.WHEN_STATEMENT) {
            val branchCount = statement.aux % 65536;
            var branchRoot = root - 1;
            for (branchIndex in 0..<branchCount) {
                emitBlockAllocas(
                    buffer, genericArguments, nodes, branchRoot - 1);
                branchRoot = nodes.data[branchRoot].subtreeStart - 1;
            }
        }
    }
    k_boot_free(roots as unit*);
}

fn emitFunction(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    functionRoot: u64,
    specializationArgumentStart: u64,
    specializationCount: u32): bool {
    val function = nodes.data[functionRoot];
    val name = nodes.data[function.subtreeStart];
    val returnType = nodes.data[returnTypeRoot(nodes, functionRoot)];
    val parameterCount = function.parameterCount();
    if (function.isExtern()) {
        buffer.append("declare ");
    } else {
        appendDefine(buffer);
    }
    if (function.infersReturn()) {
        var inferred = TypeValue(
            typeKindFromValue(function.typeKind), function.typeName, function.typePointee);
        if (specializationCount > 0) {
            inferred = substituteEmitterType(
                source, nodes, functionRoot, inferred,
                genericArguments,
                specializationArgumentStart, specializationCount);
        }
        appendType(
            buffer, genericArguments,
            inferred.kind.value, inferred.name, inferred.pointee);
    } else appendNodeType(buffer, genericArguments, returnType);
    appendFunctionOpen(buffer);
    if (function.conversionKind == 1) {
        val receiverType = nodes.data[
            parameterRoot(nodes, functionRoot, 1) - 1];
        val ownerRoot = structRootByName(source, nodes, receiverType.typeName);
        val ownerName = nodes.data[nodes.data[ownerRoot].subtreeStart];
        appendSource(buffer, source, ownerName.start, ownerName.end);
        buffer.append(".");
    } else if (function.conversionKind == 2) {
        val ownerRoot = emitterAssociatedOwnerStructRoot(
            nodes, functionRoot);
        val ownerName = nodes.data[nodes.data[ownerRoot].subtreeStart];
        appendSource(buffer, source, ownerName.start, ownerName.end);
        buffer.append(".");
    }
    appendSource(buffer, source, name.start, name.end);
    if (specializationCount > 0) {
        appendSpecializationSuffix(
            buffer, genericArguments,
            specializationArgumentStart, specializationCount);
    }
    buffer.append("(");
    for (parameterIndex in 0..<parameterCount) {
        val parameterPosition = parameterIndex + 1;
        if (parameterIndex > 0) {
            buffer.append(", ");
        }
        val parameter = nodes.data[
            parameterRoot(nodes, functionRoot, parameterPosition)];
        val parameterName = nodes.data[parameter.subtreeStart];
        val parameterType = nodes.data[
            parameterRoot(nodes, functionRoot, parameterPosition) - 1];
        if (parameter.mode() == ParameterMode.MUTABLE_BORROW) {
            appendType(buffer, genericArguments, 9, 0, parameterType.typeKind);
        } else {
            appendNodeType(buffer, genericArguments, parameterType);
        }
        buffer.append(" %");
        if (parameter.mode() != ParameterMode.MUTABLE_BORROW) {
            buffer.append("arg.");
        } else {
            appendLocalPrefix(buffer);
        }
        if (parameter.mode() == ParameterMode.MUTABLE_BORROW) {
            appendDecimal(buffer, parameterName.start);
        } else {
            appendSource(
                buffer, source, parameterName.start, parameterName.end);
        }
    }
    buffer.append(")");
    if (function.isExtern()) {
        appendNewline(buffer);
        return true;
    }
    buffer.append(" {");
    appendNewline(buffer);
    appendEntry(buffer);
    appendNewline(buffer);

    var counter = IrCounter(
        0, 0, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 0);
    var defers = List<u64>.new();
    defer defers.free();
    for (parameterIndex in 0..<parameterCount) {
        val parameterPosition = parameterIndex + 1;
        val parameter = nodes.data[
            parameterRoot(nodes, functionRoot, parameterPosition)];
        val parameterName = nodes.data[parameter.subtreeStart];
        if (parameter.mode() != ParameterMode.MUTABLE_BORROW) {
        val parameterType = nodes.data[
            parameterRoot(nodes, functionRoot, parameterPosition) - 1];
        appendValuePrefix(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, parameterName.start);
        appendEquals(buffer);
        appendAlloca(buffer);
        appendNodeType(buffer, genericArguments, parameterType);
        appendNewline(buffer);
        appendStore(buffer);
        appendNodeType(buffer, genericArguments, parameterType);
        buffer.append(" %arg.");
        appendSource(
            buffer, source, parameterName.start, parameterName.end);
        appendPtr(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, parameterName.start);
        appendNewline(buffer);
        if ((parameter.ownership / 2) % 2 == 1) {
            appendValuePrefix(buffer); appendDropFlagName(buffer, parameterName.start);
            appendEquals(buffer); appendAlloca(buffer);
            buffer.append("i1"); appendNewline(buffer);
            appendStore(buffer); buffer.append("i1 ");
            buffer.append("true");
            appendPtr(buffer); appendDropFlagName(buffer, parameterName.start);
            appendNewline(buffer);
            defers.add(
                parameterRoot(nodes, functionRoot, parameterPosition) +
                9223372036854775808);
        }
        }
    }

    val blockRoot = functionRoot - 1;
    emitBlockAllocas(buffer, genericArguments, nodes, blockRoot);
    val terminated =
        emitBlock(
            buffer, source, nodes, genericArguments,
            blockRoot, counter, defers);
    if (!terminated) {
        var returnsUnit = returnType.typeKind == TypeKind.UNIT.value;
        if (returnType.kind == AstKind.NAMED_TYPE &&
            returnType.aux == TokenKind.UNIT.value) returnsUnit = true;
        if (function.infersReturn() && function.typeKind == TypeKind.UNIT.value)
            returnsUnit = true;
        if (returnsUnit) {
            buffer.append("  ret void");
            appendNewline(buffer);
        }
    }
    appendFunctionClose(buffer);
    return true;
}

fn emitSpecializedFunction(
    var buffer: StringBuilder, source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    functionRoot: u64,
    argumentStart: u64,
    argumentCount: u32) {
    val start = nodes.data[functionRoot].subtreeStart;
    val count = functionRoot - start + 1;
    val saved =
        k_boot_alloc(count * sizeof(AstNode)) as AstNode*;
    for (offset in 0..<count) {
        saved[offset] = nodes.data[start + offset];
        var node = nodes.data[start + offset];
        if (node.typeKind == TypeKind.TYPE_PARAMETER.value || node.typeKind == TypeKind.STRUCT.value ||
                node.typeKind == TypeKind.POINTER.value || node.typeKind == TypeKind.SLICE.value ||
                node.typeKind == TypeKind.NULLABLE.value) {
            val concrete = substituteEmitterType(
                source, nodes, functionRoot,
                TypeValue(
                    typeKindFromValue(node.typeKind), node.typeName, node.typePointee),
                genericArguments, argumentStart, argumentCount);
            node.typeKind = concrete.kind.value;
            node.typeName = concrete.name;
            node.typePointee = concrete.pointee;
        }
        if (node.kind == AstKind.CALL) {
            val genericCount = node.genericArgumentCount;
            if (genericCount > 0) {
                val substituted =
                    k_boot_alloc((genericCount as u64) * sizeof(TypeValue)) as TypeValue*;
                for (genericIndex in 0..<genericCount) {
                    val pattern = genericArguments.data[
                        node.genericArgumentStart + genericIndex as u64];
                    substituted[genericIndex as u64] = substituteEmitterType(
                        source, nodes, functionRoot,
                        pattern, genericArguments,
                        argumentStart, argumentCount);
                }
                val concreteStart = genericArguments.length;
                for (genericIndex in 0..<genericCount) {
                    genericArguments.add(substituted[genericIndex as u64]);
                }
                k_boot_free(substituted as unit*);
                node.genericArgumentStart = concreteStart;
            }
        }
        nodes.data[start + offset] = node;
    }
    emitFunction(
        buffer, source, nodes, genericArguments,
        functionRoot, argumentStart, argumentCount);
    for (offset in 0..<count) {
        nodes.data[start + offset] = saved[offset];
    }
    k_boot_free(saved as unit*);
}

fn callCalleeRoot(val nodes: List<AstNode>, callRoot: u64): u64 {
    val call = nodes.data[callRoot];
    var cursor = callRoot - 1;
    val argumentCount = call.callArgumentCount();
    for (argument in 0..<argumentCount) {
        cursor = expressionChildBefore(nodes, cursor);
    }
    val explicitTypeCount = call.callTypeArgumentCount();
    for (explicitType in 0..<explicitTypeCount) {
        cursor = expressionChildBefore(nodes, cursor);
    }
    return cursor;
}

fn firstStatementRoot(val nodes: List<AstNode>, blockRoot: u64): u64 {
    val block = nodes.data[blockRoot];
    var roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var root = blockRoot - 1;
    for (index in block.aux>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    val result = roots[0];
    k_boot_free(roots as unit*);
    return result;
}

fn emitSimpleFunction(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    functionRoot: u64): bool {
    val function = nodes.data[functionRoot];
    if (function.parameterCount() != 0) return false;
    if (function.typeParameterCount() != 0) return false;
    val returnTypeRoot = nodes.data[functionRoot - 1].subtreeStart - 1;
    if (nodes.data[returnTypeRoot].aux != TokenKind.I32.value) return false;
    val name = nodes.data[function.subtreeStart];
    val blockRoot = functionRoot - 1;
    if (nodes.data[blockRoot].aux != 1) return false;
    val statementRoot = firstStatementRoot(nodes, blockRoot);
    val statement = nodes.data[statementRoot];
    if (statement.kind != AstKind.RETURN_STATEMENT) return false;
    if (statement.aux != 1) return false;
    val literal = nodes.data[statementRoot - 1];
    if (literal.kind != AstKind.LITERAL) return false;
    if (literal.aux != TokenKind.INTEGER_LITERAL.value) return false;

    appendDefine(buffer);
    appendI32(buffer);
    appendFunctionOpen(buffer);
    appendSource(buffer, source, name.start, name.end);
    appendEmptyParameters(buffer);
    appendEntry(buffer);
    appendReturnI32(buffer);
    appendSource(buffer, source, literal.start, literal.end);
    appendFunctionClose(buffer);
    return true;
}

fn emitStruct(
    var buffer: StringBuilder, source: Source,
    val nodes: List<AstNode>, var genericArguments: List<TypeValue>, structureRoot: u64) {
    val structure = nodes.data[structureRoot];
    val name = nodes.data[structure.subtreeStart];
    buffer.append("%s");
    appendDecimal(
        buffer, source.hash(name.start, name.end));
    appendEquals(buffer);
    buffer.append("type {");
    val fieldCount = structure.fieldCount();
    for (index in 0..<fieldCount) {
        if (index > 0) {
            buffer.append(",");
        }
        buffer.append(" ");
        val fieldRoot =
            fieldRootAt(nodes, structureRoot, index);
        appendNodeType(buffer, genericArguments, nodes.data[fieldRoot - 1]);
    }
    if (fieldCount > 0) buffer.append(" ");
    buffer.append("}");
    appendNewline(buffer);
}

struct StructSpecializationRequest(
    structureRoot: u64, argumentStart: u64, argumentCount: u32)

fn structSpecializationRequestExists(
    val requests: List<StructSpecializationRequest>,
    val arguments: List<TypeValue>,
    structureRoot: u64,
    argumentStart: u64,
    argumentCount: u32): bool {
    for (index in 0..<requests.length) {
        val request = requests.data[index];
        if (request.structureRoot == structureRoot) {
            if (specializationArgumentsEqual(
                    arguments,
                    request.argumentStart, request.argumentCount,
                    argumentStart, argumentCount)) {
                return true;
            }
        }
    }
    return false;
}

fn structArgumentsAreConcrete(
    val arguments: List<TypeValue>, start: u64, count: u32): bool {
    for (index in 0..<count) {
        if (arguments.data[start + index as u64].kind == TypeKind.TYPE_PARAMETER) {
            return false;
        }
    }
    return true;
}

fn emitSpecializedStruct(
    var buffer: StringBuilder, source: Source,
    val nodes: List<AstNode>, var genericArguments: List<TypeValue>,
    structureRoot: u64, argumentStart: u64, argumentCount: u32) {
    val structure = nodes.data[structureRoot];
    val name = nodes.data[structure.subtreeStart];
    buffer.append("%s");
    appendDecimal(
        buffer, source.hash(name.start, name.end));
    appendStructSpecializationSuffix(buffer, genericArguments, argumentStart, argumentCount);
    appendEquals(buffer);
    buffer.append("type {");
    val fieldCount = structure.fieldCount();
    for (index in 0..<fieldCount) {
        if (index > 0) {
            buffer.append(",");
        }
        buffer.append(" ");
        val fieldRoot =
            fieldRootAt(nodes, structureRoot, index);
        val fieldTypeNode = nodes.data[fieldRoot - 1];
        var fieldType = TypeValue(typeKindFromValue(fieldTypeNode.typeKind), fieldTypeNode.typeName, fieldTypeNode.typePointee);
        fieldType = substituteStructEmitterType(
            source, nodes, structureRoot, fieldType,
            genericArguments, argumentStart, argumentCount);
        appendType(
            buffer, genericArguments,
            fieldType.kind.value, fieldType.name, fieldType.pointee);
    }
    if (fieldCount > 0) buffer.append(" ");
    buffer.append("}");
    appendNewline(buffer);
}

struct SpecializationRequest(
    functionRoot: u64, argumentStart: u64, argumentCount: u32)

fn specializationArgumentsEqual(
    val arguments: List<TypeValue>,
    leftStart: u64, leftCount: u32,
    rightStart: u64, rightCount: u32): bool {
    if (leftCount != rightCount) return false;
    for (index in 0..<leftCount) {
        if (
            !arguments.data[leftStart + index as u64].equals(
                arguments.data[rightStart + index as u64], arguments
            )
        ) {
            return false;
        }
    }
    return true;
}

fn specializationRequestExists(
    val requests: List<SpecializationRequest>,
    val arguments: List<TypeValue>,
    functionRoot: u64,
    argumentStart: u64,
    argumentCount: u32): bool {
    for (index in 0..<requests.length) {
        val request = requests.data[index];
        if (request.functionRoot == functionRoot) {
            if (specializationArgumentsEqual(
                    arguments,
                    request.argumentStart, request.argumentCount,
                    argumentStart, argumentCount)) {
                return true;
            }
        }
    }
    return false;
}

fn callArgumentsAreConcrete(
    call: AstNode, val arguments: List<TypeValue>): bool {
    if (call.genericArgumentCount == 0) return false;
    for (index in 0..<call.genericArgumentCount) {
        if (arguments.data[
                call.genericArgumentStart + index as u64].kind == TypeKind.TYPE_PARAMETER) {
            return false;
        }
    }
    return true;
}

fn emitModule(
    source: Source, val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>): StringBuilder {
    var buffer = StringBuilder.new();
    appendModuleHeader(buffer);
    appendPrintDeclaration(buffer);
    appendPanicDeclaration(buffer);
    appendOwnedStringDeclarations(buffer);
    for (literalIndex in 0..<nodes.length) {
        val literal = nodes.data[literalIndex];
        if (literal.kind == AstKind.LITERAL &&
            literal.aux == TokenKind.STRING_LITERAL.value &&
            (literal.typeKind == TypeKind.STR.value || literal.typeKind == TypeKind.SLICE.value))
            appendStringGlobal(buffer, source, literal, literalIndex);
    }
    appendNewline(buffer);
    val programRoot = nodes.length - 1;
    val program = nodes.data[programRoot];
    val roots =
        k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
    var root = programRoot - 1;
    for (index in program.aux>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    for (index in 0..<program.aux) {
        root = roots[index as u64];
        if (nodes.data[root].kind == AstKind.STRUCT_DECLARATION) {
            if (nodes.data[root].structTypeParameterCount() == 0) {
                emitStruct(buffer, source, nodes, genericArguments, root);
            }
        }
    }
    
    var structRequests = List<StructSpecializationRequest>.new();
    defer structRequests.free();
    for (nodeIndex in 0..<nodes.length) {
        val node = nodes.data[nodeIndex];
        if (node.typeKind == TypeKind.STRUCT.value) {
            val start = node.typePointee % 65536;
            val count = node.typePointee / 65536;
            if (count > 0) {
                if (structArgumentsAreConcrete(genericArguments, start as u64, count)) {
                    val structureRoot = structRootByName(source, nodes, node.typeName);
                    if (structureRoot != nodes.length) {
                        if (
                            !structSpecializationRequestExists(
                                structRequests, genericArguments,
                                structureRoot, start as u64, count
                            )
                        ) {
							structRequests.add(StructSpecializationRequest(structureRoot, start as u64, count));
                        }
                    }
                }
            }
        }
    }
    
    for (structReqIndex in 0..<structRequests.length) {
        val request = structRequests.data[structReqIndex];
        emitSpecializedStruct(
            buffer, source, nodes, genericArguments,
            request.structureRoot, request.argumentStart, request.argumentCount);
    }
    
    appendNewline(buffer);
    for (index in 0..<program.aux) {
        root = roots[index as u64];
        if (nodes.data[root].kind == AstKind.FUNCTION_OR_DEFER) {
            if (nodes.data[root].typeParameterCount() == 0) {
                emitFunction(
                    buffer, source, nodes, genericArguments,
                    root, 0, 0);
            }
        } else {
            if (nodes.data[root].kind == AstKind.STRUCT_DECLARATION) {
                var methodRoot = root - 1;
                val methods = nodes.data[root].methodCount();
                for (method in 0..<methods) {
                    if (nodes.data[root].structTypeParameterCount() == 0) {
                        emitFunction(
                            buffer, source, nodes, genericArguments,
                            methodRoot, 0, 0);
                    }
                    methodRoot = nodes.data[methodRoot].subtreeStart - 1;
                }
            }
        }
    }
    var requests = List<SpecializationRequest>.new();
    defer requests.free();
    for (callIndex in 0..<nodes.length) {
        val call = nodes.data[callIndex];
        if (call.kind == AstKind.CALL) {
            if (callArgumentsAreConcrete(call, genericArguments)) {
                val calleeRoot = callCalleeRoot(nodes, callIndex);
                val callee = nodes.data[calleeRoot];
                var functionRoot =
                    functionRootByName(
                        source, nodes,
                        source.hash(callee.start, callee.end));
                if (callee.kind == AstKind.MEMBER) functionRoot = call.storage;
                if (functionRoot != nodes.length) {
                    if (
                        !specializationRequestExists(
                            requests, genericArguments,
                            functionRoot,
                            call.genericArgumentStart,
                            call.genericArgumentCount
                        )
                    ) {
						requests.add(
						    SpecializationRequest(
						        functionRoot,
						        call.genericArgumentStart,
						        call.genericArgumentCount
						    )
						);
                    }
                }
            }
        }
    }
    var requestIndex: u64 = 0;
    while (requestIndex < requests.length) {
        val request = requests.data[requestIndex];
        val functionStart =
            nodes.data[request.functionRoot].subtreeStart;
        for (nestedIndex in functionStart..<request.functionRoot) {
            val nestedCall = nodes.data[nestedIndex];
            if (nestedCall.kind == AstKind.CALL) {
            if (nestedCall.genericArgumentCount > 0) {
                val calleeRoot =
                    callCalleeRoot(nodes, nestedIndex);
                val callee = nodes.data[calleeRoot];
                var nestedFunctionRoot =
                    functionRootByName(
                        source, nodes,
                        source.hash(callee.start, callee.end));
                if (callee.kind == AstKind.MEMBER)
                    nestedFunctionRoot = nestedCall.storage;
                if (nestedFunctionRoot != nodes.length) {
                    val nestedCount = nestedCall.genericArgumentCount;
                    val substituted =
                        k_boot_alloc((nestedCount as u64) * sizeof(TypeValue)) as TypeValue*;
                    for (nestedArgument in 0..<nestedCount) {
                        val pattern = genericArguments.data[
                            nestedCall.genericArgumentStart +
                            nestedArgument as u64];
                        substituted[nestedArgument as u64] = substituteEmitterType(
                            source, nodes, request.functionRoot,
                            pattern, genericArguments,
                            request.argumentStart,
                            request.argumentCount);
                    }
                    val concreteStart = genericArguments.length;
                    for (nestedArgument in 0..<nestedCount) {
                        genericArguments.add(substituted[nestedArgument as u64]);
                    }
                    k_boot_free(substituted as unit*);
                    if (
                        !specializationRequestExists(
                            requests, genericArguments,
                            nestedFunctionRoot, concreteStart,
                            nestedCount
                        )
                    ) {
						requests.add(
							SpecializationRequest(
								nestedFunctionRoot, concreteStart,
								nestedCount
							)
						);
                    }
                }
            }
            }
        }
        requestIndex++;
    }
    for (requestIndex in 0..<requests.length) {
        val request = requests.data[requestIndex];
        emitSpecializedFunction(
            buffer, source, nodes, genericArguments,
            request.functionRoot, request.argumentStart,
            request.argumentCount);
    }
    k_boot_free(roots as unit*);
    return buffer;
}
