module bootstrap.llvm_text.types;

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

fn appendStructSpecializationSuffix(
    var buffer: StringBuilder, val arguments: List<TypeValue>,
    start: u64, count: u32) {
    buffer.append("__s");
    appendDecimal(buffer, count as u64);
    for (index in 0..<count) {
        val type = arguments.data[start + index as u64];
        buffer.append("_");
        appendDecimal(buffer, type.kind.value as u64);
        buffer.append("_");
        appendDecimal(buffer, type.name);
        buffer.append("_");
        appendDecimal(buffer, type.pointee as u64);
    }
}

fn appendType(
    var buffer: StringBuilder, var genericArguments: List<TypeValue>,
    kind: u32, name: u64, pointee: u32) {
    if (kind == TypeKind.UNIT.value) {
        buffer.append("void");
    }
    if (kind == TypeKind.BOOL.value) {
        buffer.append("i1");
    }
    if (kind == TypeKind.I32.value) appendI32(buffer);
    if (kind == TypeKind.I64.value) {
        buffer.append("i64");
    }
    if (kind == TypeKind.U8.value) {
        buffer.append("i8");
    }
    if (kind == TypeKind.U32.value) appendI32(buffer);
    if (kind == TypeKind.U64.value) {
        buffer.append("i64");
    }
    if (kind == TypeKind.STRUCT.value) {
        buffer.append("%s");
        appendDecimal(buffer, name);
        val start = pointee % 65536;
        val count = pointee / 65536;
        if (count > 0) {
            appendStructSpecializationSuffix(buffer, genericArguments, start as u64, count);
        }
    }
    if (kind == TypeKind.POINTER.value) {
        buffer.append("ptr");
    }
    if (kind == TypeKind.STR.value) {
        appendStringType(buffer);
    }
    if (kind == TypeKind.F32.value) {
        buffer.append("float");
    }
    if (kind == TypeKind.F64.value) {
        buffer.append("double");
    }
    if (kind == TypeKind.INTEGER_LITERAL.value) appendI32(buffer);
    if (kind == TypeKind.ENUM.value)
        appendType(buffer, genericArguments, pointee, 0, 0);
    if (kind == TypeKind.SLICE.value) {
        buffer.append("{ ptr, i64 }");
    }
    if (kind == TypeKind.NULLABLE.value) {
        buffer.append("{ i1, ");
        appendType(buffer, genericArguments, pointee, name, 0);
        buffer.append(" }");
    }
    if (kind == TypeKind.ARRAY.value) {
        buffer.append("[");
        appendDecimal(buffer, (pointee / 256) as u64);
        buffer.append(" x ");
        appendType(buffer, genericArguments, pointee % 256, name, 0);
        buffer.append("]");
    }
}

fn appendNodeType(var buffer: StringBuilder, var genericArguments: List<TypeValue>, node: AstNode) {
    appendType(
        buffer, genericArguments, node.typeKind, node.typeName, node.typePointee);
}

fn appendSpecializationSuffix(
    var buffer: StringBuilder, val arguments: List<TypeValue>,
    start: u64, count: u32) {
    buffer.append("__g");
    appendDecimal(buffer, count as u64);
    for (index in 0..<count) {
        val type = arguments.data[start + index as u64];
        buffer.append("_");
        appendDecimal(buffer, type.kind.value as u64);
        buffer.append("_");
        appendDecimal(buffer, type.name);
        buffer.append("_");
        appendDecimal(buffer, type.pointee as u64);
    }
}

fn emitterStructTypeParameterCount(structure: AstNode) => structure.structTypeParameterCount();

fn emitterStructFieldCount(structure: AstNode) => structure.fieldCount();

fn emitterStructMethodCount(structure: AstNode) => structure.methodCount();

fn emitterStructTypeParameterRoot(
    source: Source, val nodes: List<AstNode>, structureRoot: u64, position: u32): u64 {
    val structure = nodes.data[structureRoot];
    var root = emitterRootBeforeStructMethods(nodes, structureRoot);
    val fields = emitterStructFieldCount(structure);
    for (field in 0..<fields) {
        root = nodes.data[root].subtreeStart - 1;
    }
    val remaining = emitterStructTypeParameterCount(structure);
    for (index in position..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn emitterStructTypeParameterPosition(
    source: Source, val nodes: List<AstNode>, structureRoot: u64, name: u64): u32 {
    val count = emitterStructTypeParameterCount(
        nodes.data[structureRoot]);
    for (position in 0..<count) {
        val root = emitterStructTypeParameterRoot(
            source, nodes, structureRoot, position + 1);
        val parameter = nodes.data[root];
        val nameNode = nodes.data[parameter.subtreeStart];
        if (source.hash(nameNode.start, nameNode.end) == name) {
            return position;
        }
    }
    return count;
}

fn substituteStructEmitterType(
    source: Source, val nodes: List<AstNode>, structureRoot: u64,
    pattern: TypeValue, val arguments: List<TypeValue>,
    argumentStart: u64, count: u32): TypeValue {
    if (pattern.kind == TypeKind.TYPE_PARAMETER) {
        val position = emitterStructTypeParameterPosition(
            source, nodes, structureRoot, pattern.name);
        if (position >= count) return invalidType();
        return arguments.data[argumentStart + position as u64];
    }
    if (pattern.kind == TypeKind.NULLABLE) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.NULLABLE, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.POINTER) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.POINTER, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.SLICE) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.SLICE, inner.name, inner.kind.value);
    }
    return pattern;
}

fn alignUp(value: u64, alignment: u64) =>
    ((value + alignment - 1) / alignment) * alignment;

fn typeAlignment(
    source: Source, val nodes: List<AstNode>, var genericArguments: List<TypeValue>,
    kind: u32, name: u64, pointee: u32): u64 {
    if (kind == TypeKind.BOOL.value) return 1;
    if (kind == TypeKind.U8.value) return 1;
    if (kind == TypeKind.I32.value) return 4;
    if (kind == TypeKind.U32.value) return 4;
    if (kind == TypeKind.INTEGER_LITERAL.value) return 4;
    if (kind == TypeKind.ENUM.value)
        return typeAlignment(source, nodes, genericArguments, pointee, 0, 0);
    if (kind == TypeKind.F32.value) return 4;
    if (kind == TypeKind.I64.value) return 8;
    if (kind == TypeKind.U64.value) return 8;
    if (kind == TypeKind.POINTER.value) return 8;
    if (kind == TypeKind.STR.value) return 24;
    if (kind == TypeKind.F64.value) return 8;
    if (kind == TypeKind.SLICE.value) return 8;
    if (kind == TypeKind.ARRAY.value) {
        return typeAlignment(
            source, nodes, genericArguments,
            pointee % 256, name, 0);
    }
    if (kind == TypeKind.STRUCT.value) {
        val structureRoot = structRootByName(source, nodes, name);
        val structure = nodes.data[structureRoot];
        val fieldCount = emitterStructFieldCount(structure);
        val start = pointee % 65536;
        val count = pointee / 65536;
        var alignment: u64 = 1;
        for (index in 0..<fieldCount) {
            val typeNode = nodes.data[
                emitterFieldRootAt(nodes, structureRoot, index) - 1];
            var fieldType = TypeValue(typeKindFromValue(typeNode.typeKind), typeNode.typeName, typeNode.typePointee);
            if (count > 0) {
                fieldType = substituteStructEmitterType(
                    source, nodes, structureRoot, fieldType,
                    genericArguments, start as u64, count);
            }
            val fieldAlignment = typeAlignment(
                source, nodes, genericArguments, fieldType.kind.value,
                fieldType.name, fieldType.pointee);
            if (fieldAlignment > alignment) {
                alignment = fieldAlignment;
            }
        }
        return alignment;
    }
    return 1;
}

fn typeSize(
    source: Source, val nodes: List<AstNode>, var genericArguments: List<TypeValue>,
    kind: u32, name: u64, pointee: u32): u64 {
    if (kind == TypeKind.UNIT.value) return 0;
    if (kind == TypeKind.BOOL.value) return 1;
    if (kind == TypeKind.U8.value) return 1;
    if (kind == TypeKind.I32.value) return 4;
    if (kind == TypeKind.U32.value) return 4;
    if (kind == TypeKind.INTEGER_LITERAL.value) return 4;
    if (kind == TypeKind.ENUM.value)
        return typeSize(source, nodes, genericArguments, pointee, 0, 0);
    if (kind == TypeKind.F32.value) return 4;
    if (kind == TypeKind.I64.value) return 8;
    if (kind == TypeKind.U64.value) return 8;
    if (kind == TypeKind.POINTER.value) return 8;
    if (kind == TypeKind.STR.value) return 8;
    if (kind == TypeKind.F64.value) return 8;
    if (kind == TypeKind.SLICE.value) return 16;
    if (kind == TypeKind.ARRAY.value) {
        val elementSize = typeSize(
            source, nodes, genericArguments,
            pointee % 256, name, 0);
        val count = (pointee / 256) as u64;
        return count * elementSize;
    }
    if (kind == TypeKind.STRUCT.value) {
        val structureRoot = structRootByName(source, nodes, name);
        val structure = nodes.data[structureRoot];
        val fieldCount = emitterStructFieldCount(structure);
        val start = pointee % 65536;
        val count = pointee / 65536;
        var size: u64 = 0;
        for (index in 0..<fieldCount) {
            val typeNode = nodes.data[
                emitterFieldRootAt(nodes, structureRoot, index) - 1];
            var fieldType = TypeValue(typeKindFromValue(typeNode.typeKind), typeNode.typeName, typeNode.typePointee);
            if (count > 0) {
                fieldType = substituteStructEmitterType(
                    source, nodes, structureRoot, fieldType,
                    genericArguments, start as u64, count);
            }
            val alignment = typeAlignment(
                source, nodes, genericArguments, fieldType.kind.value,
                fieldType.name, fieldType.pointee);
            size = alignUp(size, alignment);
            size += typeSize(
                source, nodes, genericArguments, fieldType.kind.value,
                fieldType.name, fieldType.pointee);
        }
        return alignUp(
            size, typeAlignment(source, nodes, genericArguments, kind, name, pointee));
    }
    return 0;
}

fn emitterTypeParameterRoot(
    val nodes: List<AstNode>, functionRoot: u64, position: u32): u64 {
    var root = returnTypeRoot(nodes, functionRoot);
    val parameters =
        nodes.data[functionRoot].parameterCount();
    for (parameter in 0..<parameters) {
        root = nodes.data[root].subtreeStart - 1;
    }
    val remaining =
        nodes.data[functionRoot].typeParameterCount();
    for (index in position - 1..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn emitterTypeParameterPosition(
    source: Source, val nodes: List<AstNode>,
    functionRoot: u64, name: u64): u32 {
    val count =
        nodes.data[functionRoot].typeParameterCount();
    for (position in 0..<count) {
        val root =
            emitterTypeParameterRoot(nodes, functionRoot, position + 1);
        val parameter = nodes.data[root];
        val nameNode = nodes.data[parameter.subtreeStart];
        if (source.hash(nameNode.start, nameNode.end) == name) {
            return position;
        }
    }
    val function = nodes.data[functionRoot];
    if (function.conversionKind == 1) {
        if (function.parameterCount() > 0) {
            val receiverType = nodes.data[
                parameterRoot(nodes, functionRoot, 1) - 1];
            val ownerRoot = structRootByName(
                source, nodes,
                source.hash(receiverType.start, receiverType.end));
            if (ownerRoot != nodes.length) {
                return emitterStructTypeParameterPosition(
                    source, nodes, ownerRoot, name);
            }
        }
    } else if (function.conversionKind == 2) {
        val ownerRoot = emitterAssociatedOwnerStructRoot(
            nodes, functionRoot);
        if (ownerRoot != nodes.length) {
            return emitterStructTypeParameterPosition(
                source, nodes, ownerRoot, name);
        }
    }
    return count;
}

fn substituteEmitterType(
    source: Source, val nodes: List<AstNode>, functionRoot: u64,
    pattern: TypeValue, var arguments: List<TypeValue>,
    argumentStart: u64, count: u32): TypeValue {
    if (pattern.kind == TypeKind.STRUCT) {
        val start = pattern.pointee % 65536;
        val argumentCount = pattern.pointee / 65536;
        if (argumentCount == 0) return pattern;
        val substituted =
            k_boot_alloc((argumentCount as u64) * sizeof(TypeValue)) as TypeValue*;
        for (index in 0..<argumentCount) {
            val argument =
                arguments.data[start as u64 + index as u64];
            substituted[index as u64] = substituteEmitterType(
                source, nodes, functionRoot,
                argument, arguments, argumentStart, count);
        }
        val newStart = arguments.length;
        for (index in 0..<argumentCount) {
            arguments.add(substituted[index as u64]);
        }
        k_boot_free(substituted as unit*);
        return TypeValue(
            TypeKind.STRUCT, pattern.name,
            newStart as u32 + argumentCount * 65536);
    }
    if (pattern.kind == TypeKind.NULLABLE) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.NULLABLE, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.POINTER) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.POINTER, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.SLICE) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.SLICE, inner.name, inner.kind.value);
    }
    if (pattern.kind != TypeKind.TYPE_PARAMETER) return pattern;
    val position = emitterTypeParameterPosition(
        source, nodes, functionRoot, pattern.name);
    if (position >= count) return invalidType();
    return arguments.data[argumentStart + position as u64];
}

