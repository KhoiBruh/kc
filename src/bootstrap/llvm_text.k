module bootstrap.llvm_text;

import bootstrap.*;
import bootstrap.token.TokenKind;

fn appendDecimal(var buffer: StringBuilder, value: u64) {
    val digits = k_boot_alloc(20) as u8*;
    var remaining = value;
    var length: u64 = 0;
    if (remaining == 0) {
        buffer.append("0");
    } else {
        while (remaining > 0) {
            digits[length] = (remaining % 10) as u8 + 48;
            remaining /= 10;
            length++;
        }
        for (index in length>..0) buffer.add(digits[index]);
    }
    k_boot_free(digits as unit*);
}

fn appendSource(
    var buffer: StringBuilder, source: Source, start: u64, end: u64) {
    for (offset in start..<end) {
        buffer.add(source.data[offset]);
    }
}

fn appendDefine(var buffer: StringBuilder) {
    buffer.append("define ");
}

fn appendI32(var buffer: StringBuilder) => buffer.append("i32");

fn appendFunctionOpen(var buffer: StringBuilder) => buffer.append(" @");

fn appendEmptyParameters(var buffer: StringBuilder) => buffer.append("() {\n");

fn appendEntry(var buffer: StringBuilder) => buffer.append("entry:\n  ");

fn appendReturnI32(var buffer: StringBuilder) {
    buffer.append("ret ");
    appendI32(buffer);
    buffer.append(" ");
}

fn appendFunctionClose(var buffer: StringBuilder) => buffer.append("\n}\n");

fn appendValuePrefix(var buffer: StringBuilder) => buffer.append("  %");

fn appendEquals(var buffer: StringBuilder) => buffer.append(" = ");

fn appendLoad(var buffer: StringBuilder) => buffer.append("load ");

fn appendStore(var buffer: StringBuilder) {
    buffer.append("  store ");
}

fn appendPtr(var buffer: StringBuilder) {
    buffer.append(", ptr %");
}

fn appendAlloca(var buffer: StringBuilder) => buffer.append("alloca ");

fn appendCall(var buffer: StringBuilder) => buffer.append("call ");

fn appendPrintDeclaration(var buffer: StringBuilder) {
    buffer.append("declare void @k_std_print_i32(i32)\n\n");
    appendPrintBytesDeclaration(buffer);
}
fn appendPrintBytesDeclaration(var buffer: StringBuilder) {
    buffer.append("declare void @k_std_print_bytes(ptr, i64)\n\n");
}

fn appendPrivateStringPrefix(var buffer: StringBuilder) {
    buffer.append(" = private unnamed_addr constant [");
}

fn appendStringArrayPrefix(var buffer: StringBuilder) {
    buffer.append(" x i8] c\"");
}

fn appendStringTerminator(var buffer: StringBuilder) {
    buffer.append("\\00\"\n");
}

fn appendStringType(var buffer: StringBuilder) {
    buffer.append("{ ptr, i64, i64 }");
}

fn appendStringInsertPointer(var buffer: StringBuilder) {
    buffer.append(" { ptr, i64, i64 } undef, ptr @.ks");
}

fn appendIndexZero(var buffer: StringBuilder) {
    buffer.append(", 0\n");
}

fn appendSpacedStringType(var buffer: StringBuilder) {
    buffer.append(" { ptr, i64, i64 } ");
}

fn appendI64Prefix(var buffer: StringBuilder) {
    buffer.append(", i64 ");
}

fn appendIndexOne(var buffer: StringBuilder) {
    buffer.append(", 1\n");
}

fn appendStringCapacity(var buffer: StringBuilder) {
    buffer.append(", i64 0, 2\n");
}

fn appendExtractLengthAndPrint(var buffer: StringBuilder) {
    buffer.append(", 1\n  call void @k_std_print_bytes(ptr ");
}

fn appendCloseLine(var buffer: StringBuilder) {
    buffer.append(")\n");
}



fn hexDigit(value: u8): u8 {
    if (value < 10) return 48 + value;
    return 55 + value;
}

fn appendEscapedByte(var buffer: StringBuilder, value: u8) {
    if (value >= 32 && value <= 126 && value != 34 && value != 92) {
        buffer.add(value);
        return;
    }
    buffer.append("\\");
    buffer.add(hexDigit(value / 16));
    buffer.add(hexDigit(value % 16));
}

fn appendUtf8(var buffer: StringBuilder, codepoint: u32) {
    if (codepoint <= 127) { buffer.add(codepoint as u8); return; }
    if (codepoint <= 2047) {
        buffer.add((192 + codepoint / 64) as u8);
        buffer.add((128 + codepoint % 64) as u8);
        return;
    }
    if (codepoint <= 65535) {
        buffer.add((224 + codepoint / 4096) as u8);
        buffer.add((128 + (codepoint / 64) % 64) as u8);
        buffer.add((128 + codepoint % 64) as u8);
        return;
    }
    buffer.add((240 + codepoint / 262144) as u8);
    buffer.add((128 + (codepoint / 4096) % 64) as u8);
    buffer.add((128 + (codepoint / 64) % 64) as u8);
    buffer.add((128 + codepoint % 64) as u8);
}

fn decodeStringLiteral(source: Source, node: AstNode): StringBuilder {
    var result = StringBuilder.new();
    var offset = node.start + 1;
    while (offset + 1 < node.end) {
        var value = source.data[offset];
        if (value != 92) { result.add(value); offset++; continue; }
        offset++;
        value = source.data[offset];
        if (value == 110) result.add(10);
        else if (value == 114) result.add(13);
        else if (value == 116) result.add(9);
        else if (value == 48) result.add(0);
        else if (value == 117) {
            offset += 2;
            var codepoint: u32 = 0;
            while (source.data[offset] != 125) {
                val digit = source.data[offset];
                var numeric = (digit - 48) as u32;
                if (digit >= 65) numeric = (digit - 55) as u32;
                if (digit >= 97) numeric = (digit - 87) as u32;
                codepoint = codepoint * 16 + numeric;
                offset++;
            }
            appendUtf8(result, codepoint);
        } else result.add(value);
        offset++;
    }
    return result;
}

fn appendStringGlobal(var buffer: StringBuilder, source: Source, node: AstNode, root: u64) {
    var decoded = decodeStringLiteral(source, node);
    defer decoded.free();
    buffer.append("@.k");
    buffer.append("s"); appendDecimal(buffer, root);
    appendPrivateStringPrefix(buffer);
    appendDecimal(buffer, decoded.length + 1);
    appendStringArrayPrefix(buffer);
    for (index in 0..<decoded.length) appendEscapedByte(buffer, decoded.data[index]);
    appendStringTerminator(buffer);
}

fn appendPanicDeclaration(var buffer: StringBuilder) {
    buffer.append("declare void @k_boot_panic(ptr, i64)\n\n");
}

fn appendModuleHeader(var buffer: StringBuilder) {
    buffer.append("target datalayout = \"e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128\"\ntarget triple = \"x86_64-pc-windows-msvc\"\n\n");
}

fn sourceNodeIsPrint(source: Source, node: AstNode): bool {
    if (node.end - node.start != 5) return false;
    if (source.data[node.start] != 112) return false;
    if (source.data[node.start + 1] != 114) return false;
    if (source.data[node.start + 2] != 105) return false;
    if (source.data[node.start + 3] != 110) return false;
    return source.data[node.start + 4] == 116;
}

fn appendOperator(var buffer: StringBuilder, kind: u32, typeKind: u32) {
    var floating = typeKind == TypeKind.F32.value;
    if (typeKind == TypeKind.F64.value) floating = true;
    if (floating) buffer.append("f");
    if (kind == TokenKind.Plus.value) {
        buffer.append("add");
    }
    if (kind == TokenKind.Minus.value) {
        buffer.append("sub");
    }
    if (kind == TokenKind.Star.value) {
        buffer.append("mul");
    }
    if (kind == TokenKind.Slash.value) {
        if (floating) {
            buffer.append("di");
            buffer.append("v"); return;
        }
        var unsigned = typeKind == TypeKind.U8.value;
        if (typeKind == TypeKind.U32.value) unsigned = true;
        if (typeKind == TypeKind.U64.value) unsigned = true;
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("div");
    }
    if (kind == TokenKind.Percent.value) {
        if (floating) {
            buffer.append("re");
            buffer.append("m"); return;
        }
        var unsigned = typeKind == TypeKind.U8.value;
        if (typeKind == TypeKind.U32.value) unsigned = true;
        if (typeKind == TypeKind.U64.value) unsigned = true;
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("rem");
    }
}

fn appendNewline(var buffer: StringBuilder) => buffer.append("\n");

fn appendCastOpcode(var buffer: StringBuilder, kind: u32) {
    when (kind) {
        1 -> buffer.append("s");
        2 -> buffer.append("z");
        else -> {
            buffer.append("trunc");
            return;
        }
    }
    buffer.append("ext");
}

fn appendFloatCastOpcode(var buffer: StringBuilder, kind: u32) {
    if (kind == 1) {
        buffer.append("fpex");
        buffer.append("t"); return;
    }
    if (kind == 2) {
        buffer.append("fptrun");
        buffer.append("c"); return;
    }
    if (kind == 3) buffer.append("s");
    if (kind == 4) buffer.append("u");
    var integerToFloat = kind == 3;
    if (kind == 4) integerToFloat = true;
    if (integerToFloat) {
        buffer.append("itof");
        buffer.append("p"); return;
    }
    buffer.append("fpto");
    if (kind == 5) {
        buffer.append("si");
    } else {
        buffer.append("ui");
    }
}

fn appendFloatIntegerConstant(
    var buffer: StringBuilder, negative: bool, magnitude: u64,
    appendSix: bool
) {
    if (negative) buffer.append("-");
    appendDecimal(buffer, magnitude);
    if (appendSix) buffer.append("6");
    buffer.append(".0");
}

fn appendFloatCastBound(
    var buffer: StringBuilder, sourceKind: u32, targetKind: u32,
    lower: bool
) {
    if (lower) {
        if (targetKind == TypeKind.I32.value) {
            var magnitude: u64 = 2147483649;
            if (sourceKind == TypeKind.F32.value) magnitude = 2147483648;
            appendFloatIntegerConstant(buffer, true, magnitude, false);
            return;
        }
        if (targetKind == TypeKind.I64.value) {
            appendFloatIntegerConstant(
                buffer, true, 9223372036854775808, false);
            return;
        }
        appendFloatIntegerConstant(buffer, true, 1, false);
        return;
    }
    if (targetKind == TypeKind.I32.value) {
        appendFloatIntegerConstant(buffer, false, 2147483648, false);
    } else {
        if (targetKind == TypeKind.I64.value) {
            appendFloatIntegerConstant(
                buffer, false, 9223372036854775808, false);
        } else {
            if (targetKind == TypeKind.U8.value) {
                appendFloatIntegerConstant(buffer, false, 256, false);
            }
            if (targetKind == TypeKind.U32.value) {
                appendFloatIntegerConstant(buffer, false, 4294967296, false);
            }
            if (targetKind == TypeKind.U64.value) {
                appendFloatIntegerConstant(
                    buffer, false, 1844674407370955161, true);
            }
        }
    }
}

fn appendCastPanic(var buffer: StringBuilder) {
    buffer.append("  call void @k_boot_panic(ptr null, i64 0)");
    appendNewline(buffer);
    buffer.append("  unreachabl");
    buffer.append("e"); appendNewline(buffer);
}

struct IrValue(
    kind: u32, start: u64, end: u64, temporary: u64,
    typeKind: u32, typeName: u64, typePointee: u32)
struct IrCounter(
    value: u64,
    block: u64,
    currentBlock: u64,
    continueBlock: u64,
    breakBlock: u64,
    loopDeferDepth: u64)

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
    if (kind == TypeKind.Unit.value) {
        buffer.append("void");
    }
    if (kind == TypeKind.Bool.value) {
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
    if (kind == TypeKind.Struct.value) {
        buffer.append("%s");
        appendDecimal(buffer, name);
        val start = pointee % 65536;
        val count = pointee / 65536;
        if (count > 0) {
            appendStructSpecializationSuffix(buffer, genericArguments, start as u64, count);
        }
    }
    if (kind == TypeKind.Pointer.value) {
        buffer.append("ptr");
    }
    if (kind == TypeKind.String.value) {
        appendStringType(buffer);
    }
    if (kind == TypeKind.F32.value) {
        buffer.append("float");
    }
    if (kind == TypeKind.F64.value) {
        buffer.append("double");
    }
    if (kind == TypeKind.IntegerLiteral.value) appendI32(buffer);
    if (kind == TypeKind.Enum.value)
        appendType(buffer, genericArguments, pointee, 0, 0);
    if (kind == TypeKind.Slice.value) {
        buffer.append("{ ptr, i64 }");
    }
    if (kind == TypeKind.Nullable.value) {
        buffer.append("{ i1, ");
        appendType(buffer, genericArguments, pointee, name, 0);
        buffer.append(" }");
    }
    if (kind == TypeKind.Array.value) {
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

fn appendLocalPrefix(var buffer: StringBuilder) {
    buffer.append("local.");
}

fn appendOwnedStringDeclarations(var buffer: StringBuilder) {
    buffer.append("declare ptr @k_std_alloc(i64)\ndeclare void @k_std_free(ptr)\n\n");
}

fn appendDropFlagName(var buffer: StringBuilder, storage: u64) {
    appendLocalPrefix(buffer);
    appendDecimal(buffer, storage);
    buffer.append(".drop");
}

fn appendI64(var buffer: StringBuilder) {
    buffer.append("i64");
}

fn appendGetElementPtr(var buffer: StringBuilder) {
    buffer.append("getelementptr");
}

fn appendInsertValue(var buffer: StringBuilder) {
    buffer.append("insertvalue");
}

fn appendExtractValue(var buffer: StringBuilder) {
    buffer.append("extractvalue");
}

fn appendUndef(var buffer: StringBuilder) {
    buffer.append("undef");
}

fn appendUnreachable(var buffer: StringBuilder) {
    buffer.append("unreachable");
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
        if (node.kind == AstKind.StructDeclaration) {
            val nameNode = nodes.data[node.subtreeStart];
            if (sourceHash(source, nameNode.start, nameNode.end) == name) {
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
        if (node.kind == AstKind.FunctionOrDefer) {
            val nameNode = nodes.data[node.subtreeStart];
            if (sourceHash(source, nameNode.start, nameNode.end) == name) {
                found = root;
            }
        }
    }
    k_boot_free(roots as unit*);
    return found;
}

fn emitterStructTypeParameterCount(structure: AstNode) => structure.aux / 65536;

fn emitterStructFieldCount(structure: AstNode) => structure.aux % 65536;

fn emitterStructMethodCount(structure: AstNode) => structure.storage;

fn emitterDropFunctionRoot(
    source: Source, val nodes: List<AstNode>, typeName: u64): u64 {
    val structureRoot = structRootByName(source, nodes, typeName);
    if (structureRoot == nodes.length) return nodes.length;
    var methodRoot = structureRoot - 1;
    for (index in 0..<emitterStructMethodCount(nodes.data[structureRoot])) {
        val method = nodes.data[methodRoot];
        val name = nodes.data[method.subtreeStart];
        if (sourceHash(source, name.start, name.end) == 6385234055)
            return methodRoot;
        methodRoot = method.subtreeStart - 1;
    }
    return nodes.length;
}

fn emitterVariableRootByStorage(
    val nodes: List<AstNode>, storage: u64): u64 {
    for (root in 0..<nodes.length) {
        val node = nodes.data[root];
        if (node.kind == AstKind.VariableDeclaration) {
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
        if (nodes.data[structureRoot].kind == AstKind.StructDeclaration) {
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
        if (sourceHash(source, nameNode.start, nameNode.end) == name) {
            return position;
        }
    }
    return count;
}

fn substituteStructEmitterType(
    source: Source, val nodes: List<AstNode>, structureRoot: u64,
    pattern: TypeValue, val arguments: List<TypeValue>,
    argumentStart: u64, count: u32): TypeValue {
    if (pattern.kind == TypeKind.TypeParameter) {
        val position = emitterStructTypeParameterPosition(
            source, nodes, structureRoot, pattern.name);
        if (position >= count) return invalidType();
        return arguments.data[argumentStart + position as u64];
    }
    if (pattern.kind == TypeKind.Nullable) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.Nullable, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.Pointer) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.Pointer, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.Slice) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.Slice, inner.name, inner.kind.value);
    }
    return pattern;
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
    val wanted = sourceHash(source, nameNode.start, nameNode.end);
    val structure = nodes.data[structureRoot];
    val fieldCount = emitterStructFieldCount(structure);
    for (index in 0..<fieldCount) {
        val field = nodes.data[emitterFieldRootAt(nodes, structureRoot, index)];
        val fieldName = nodes.data[field.subtreeStart];
        if (sourceHash(source, fieldName.start, fieldName.end) == wanted) {
            return index;
        }
    }
    return fieldCount;
}

fn alignUp(value: u64, alignment: u64) =>
    ((value + alignment - 1) / alignment) * alignment;

fn typeAlignment(
    source: Source, val nodes: List<AstNode>, var genericArguments: List<TypeValue>,
    kind: u32, name: u64, pointee: u32): u64 {
    if (kind == TypeKind.Bool.value) return 1;
    if (kind == TypeKind.U8.value) return 1;
    if (kind == TypeKind.I32.value) return 4;
    if (kind == TypeKind.U32.value) return 4;
    if (kind == TypeKind.IntegerLiteral.value) return 4;
    if (kind == TypeKind.Enum.value)
        return typeAlignment(source, nodes, genericArguments, pointee, 0, 0);
    if (kind == TypeKind.F32.value) return 4;
    if (kind == TypeKind.I64.value) return 8;
    if (kind == TypeKind.U64.value) return 8;
    if (kind == TypeKind.Pointer.value) return 8;
    if (kind == TypeKind.String.value) return 24;
    if (kind == TypeKind.F64.value) return 8;
    if (kind == TypeKind.Slice.value) return 8;
    if (kind == TypeKind.Array.value) {
        return typeAlignment(
            source, nodes, genericArguments,
            pointee % 256, name, 0);
    }
    if (kind == TypeKind.Struct.value) {
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
    if (kind == TypeKind.Unit.value) return 0;
    if (kind == TypeKind.Bool.value) return 1;
    if (kind == TypeKind.U8.value) return 1;
    if (kind == TypeKind.I32.value) return 4;
    if (kind == TypeKind.U32.value) return 4;
    if (kind == TypeKind.IntegerLiteral.value) return 4;
    if (kind == TypeKind.Enum.value)
        return typeSize(source, nodes, genericArguments, pointee, 0, 0);
    if (kind == TypeKind.F32.value) return 4;
    if (kind == TypeKind.I64.value) return 8;
    if (kind == TypeKind.U64.value) return 8;
    if (kind == TypeKind.Pointer.value) return 8;
    if (kind == TypeKind.String.value) return 8;
    if (kind == TypeKind.F64.value) return 8;
    if (kind == TypeKind.Slice.value) return 16;
    if (kind == TypeKind.Array.value) {
        val elementSize = typeSize(
            source, nodes, genericArguments,
            pointee % 256, name, 0);
        val count = (pointee / 256) as u64;
        return count * elementSize;
    }
    if (kind == TypeKind.Struct.value) {
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

fn appendIrValue(
    var buffer: StringBuilder, source: Source, value: IrValue) {
    if (value.kind == 1) {
        appendSource(buffer, source, value.start, value.end);
    } else {
        if (value.kind == 4) {
            buffer.append("%");
            appendLocalPrefix(buffer);
            appendDecimal(buffer, value.temporary);
            return;
        }
        if (value.kind == 3) {
            appendDecimal(buffer, value.temporary);
            return;
        }
        if (value.kind == 5) {
            buffer.append("zeroinitializer");
            return;
        }
        buffer.append("%");
        appendDecimal(buffer, value.temporary);
    }
}

fn appendPointerValue(
    var buffer: StringBuilder, source: Source, value: IrValue) {
    buffer.append(", ptr ");
    if (value.kind == 1) {
        buffer.append("%");
        appendSource(buffer, source, value.start, value.end);
    } else {
        appendIrValue(buffer, source, value);
    }
}

fn nextTemporary(var counter: IrCounter): u64 {
    val value = counter.value;
    counter.value++;
    return value;
}

fn emitImplicitIntegerWiden(
    var buffer: StringBuilder, source: Source,
    var genericArguments: List<TypeValue>, value: IrValue,
    targetKind: u32, targetName: u64, targetPointee: u32,
    var counter: IrCounter): IrValue {
    val sourceType = TypeValue(typeKindFromValue(value.typeKind), value.typeName, value.typePointee);
    val targetType = TypeValue(typeKindFromValue(targetKind), targetName, targetPointee);
    if (!integerImplicitlyWidens(sourceType, targetType)) return value;
    val temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    var opcode: u32 = 2;
    if (sourceType.isSigned()) opcode = 1;
    appendCastOpcode(buffer, opcode); buffer.append(" ");
    appendType(
        buffer, genericArguments,
        value.typeKind, value.typeName, value.typePointee);
    buffer.append(" "); appendIrValue(buffer, source, value);
    buffer.append(" to ");
    appendType(buffer, genericArguments, targetKind, targetName, targetPointee);
    appendNewline(buffer);
    return IrValue(
        2, 0, 0, temporary, targetKind, targetName, targetPointee);
}

fn nextBlock(var counter: IrCounter): u64 {
    val value = counter.block;
    counter.block = value + 1;
    return value;
}

fn appendBlockName(var buffer: StringBuilder, block: u64) {
    buffer.append("b");
    appendDecimal(buffer, block);
}

fn appendBlockLabel(
    var buffer: StringBuilder, var counter: IrCounter, block: u64) {
    appendBlockName(buffer, block);
    buffer.append(":");
    appendNewline(buffer);
    counter.currentBlock = block;
}

fn appendBlockReference(var buffer: StringBuilder, block: u64) {
    buffer.append("%");
    if (block == 18446744073709551615) {
        buffer.append("entry");
    } else {
        appendBlockName(buffer, block);
    }
}

fn appendBranch(var buffer: StringBuilder, block: u64) {
    buffer.append("  br label %");
    appendBlockName(buffer, block);
    appendNewline(buffer);
}

fn appendConditionalBranch(
    var buffer: StringBuilder, source: Source, condition: IrValue,
    trueBlock: u64, falseBlock: u64) {
    buffer.append("  br i1 ");
    appendIrValue(buffer, source, condition);
    buffer.append(", label %");
    appendBlockName(buffer, trueBlock);
    buffer.append(", label %");
    appendBlockName(buffer, falseBlock);
    appendNewline(buffer);
}

fn appendComparison(
    var buffer: StringBuilder, kind: u32, typeKind: u32) {
    buffer.append("icmp ");
    if (kind == TokenKind.EqualEqual.value) {
        buffer.append("eq");
    }
    if (kind == TokenKind.BangEqual.value) {
        buffer.append("ne");
    }
    var unsigned = typeKind == TypeKind.U8.value;
    if (typeKind == TypeKind.U32.value) unsigned = true;
    if (typeKind == TypeKind.U64.value) unsigned = true;
    if (typeKind == TypeKind.Enum.value) unsigned = true;
    if (kind == TokenKind.Less.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("lt");
    }
    if (kind == TokenKind.LessEqual.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("le");
    }
    if (kind == TokenKind.Greater.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("gt");
    }
    if (kind == TokenKind.GreaterEqual.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("ge");
    }
}

fn expressionChildBefore(val nodes: List<AstNode>, root: u64) =>
    nodes.data[root].subtreeStart - 1;

fn emitClearAutomaticDrop(
    var buffer: StringBuilder, val nodes: List<AstNode>, root: u64) {
    if (nodes.data[root].typeKind != TypeKind.Struct.value) return;
    var ownerRoot = root;
    var owner = nodes.data[ownerRoot];
    while (owner.kind == AstKind.Member || owner.kind == AstKind.Postfix) {
        ownerRoot--;
        owner = nodes.data[ownerRoot];
    }
    if (owner.kind == AstKind.Index) {
        val indexRoot = ownerRoot - 1;
        ownerRoot = nodes.data[indexRoot].subtreeStart - 1;
        owner = nodes.data[ownerRoot];
    }
    if (owner.kind != AstKind.Identifier ||
        (owner.ownership / 2) % 2 == 0) return;
    appendStore(buffer);
    buffer.append("i1 false");
    appendPtr(buffer); appendDropFlagName(buffer, owner.storage);
    appendNewline(buffer);
}

fn emitAddress(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    root: u64,
    var counter: IrCounter): IrValue {
    val node = nodes.data[root];
    if (node.kind == AstKind.Identifier) {
        return IrValue(
            4, node.start, node.end, node.storage,
            TypeKind.Pointer.value, node.typeName, node.typeKind);
    }
    if (node.kind == AstKind.Unary) {
        if (node.aux == TokenKind.Star.value) {
            return emitExpression(
                buffer, source, nodes, genericArguments,
                root - 1, counter);
        }
    }
    if (node.kind == AstKind.Member) {
        val objectRoot = root - 1;
        val objectNode = nodes.data[objectRoot];
        val objectAddress = emitAddress(
            buffer, source, nodes, genericArguments,
            objectRoot, counter);
        val structureRoot =
            structRootByName(source, nodes, objectNode.typeName);
        val fieldIndex = fieldIndexByName(
            source, nodes, structureRoot, node);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendGetElementPtr(buffer);
        buffer.append(" ");
        appendType(buffer, genericArguments, 8, objectNode.typeName, objectNode.typePointee);
        appendPointerValue(buffer, source, objectAddress);
        buffer.append(", ");
        appendI32(buffer);
        buffer.append(" 0, ");
        appendI32(buffer);
        buffer.append(" ");
        appendDecimal(buffer, fieldIndex as u64);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary, TypeKind.Pointer.value,
            node.typeName, node.typeKind);
    }
    if (node.kind == AstKind.Index) {
        val indexRoot = root - 1;
        val objectRoot = expressionChildBefore(nodes, indexRoot);
        val object = emitExpression(
            buffer, source, nodes, genericArguments,
            objectRoot, counter);
        var data = object;
        if (object.typeKind == TypeKind.Slice.value) {
            val extracted = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, extracted);
            appendEquals(buffer); appendExtractValue(buffer);
            appendType(
                buffer, genericArguments,
                object.typeKind, object.typeName, object.typePointee);
            buffer.append(" "); appendIrValue(buffer, source, object);
            buffer.append(", 0"); appendNewline(buffer);
            data = IrValue(2, 0, 0, extracted, TypeKind.Pointer.value, 0, TypeKind.U8.value);
        }
        val index = emitExpression(
            buffer, source, nodes, genericArguments,
            indexRoot, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendGetElementPtr(buffer);
        buffer.append(" ");
        appendNodeType(buffer, genericArguments, node);
        appendPointerValue(buffer, source, data);
        buffer.append(", ");
        appendType(
            buffer, genericArguments, index.typeKind, index.typeName, index.typePointee);
        buffer.append(" ");
        appendIrValue(buffer, source, index);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary, TypeKind.Pointer.value,
            node.typeName, node.typeKind);
    }
    return IrValue(0, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
}

fn appendFloatRangeComparison(
    var buffer: StringBuilder, source: Source,
    var genericArguments: List<TypeValue>, value: IrValue,
    targetKind: u32, temporary: u64, lower: bool) {
    appendValuePrefix(buffer); appendDecimal(buffer, temporary);
    appendEquals(buffer);
    buffer.append("fcmp o");
    if (lower) {
        var inclusive = targetKind == TypeKind.I64.value;
        if (targetKind == TypeKind.I32.value) {
            if (value.typeKind == TypeKind.F32.value) inclusive = true;
        }
        buffer.append("g");
        if (inclusive) buffer.append("e");
        else buffer.append("t");
    } else {
        buffer.append("lt");
    }
    buffer.append(" ");
    appendType(
        buffer, genericArguments,
        value.typeKind, value.typeName, value.typePointee);
    buffer.append(" "); appendIrValue(buffer, source, value);
    buffer.append(", ");
    appendFloatCastBound(
        buffer, value.typeKind, targetKind, lower);
    appendNewline(buffer);
}

fn emitOwnedStringLiteral(
    var buffer: StringBuilder,
    source: Source,
    node: AstNode,
    var counter: IrCounter): IrValue {
    var decoded = decodeStringLiteral(source, node);
    defer decoded.free();
    var capacity = decoded.length;
    if (capacity == 0) capacity = 1;
    val data = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, data); appendEquals(buffer);
    appendCall(buffer); buffer.append("ptr");
    appendFunctionOpen(buffer);
    buffer.append("k_std_alloc(");
    appendI64(buffer); buffer.append(" "); appendDecimal(buffer, capacity);
    buffer.append(")"); appendNewline(buffer);
    for (index in 0..<decoded.length) {
        val address = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, address); appendEquals(buffer);
        appendGetElementPtr(buffer); buffer.append(" ");
        buffer.append("i8, ptr ");
        buffer.append("%"); appendDecimal(buffer, data); buffer.append(", ");
        appendI64(buffer); buffer.append(" "); appendDecimal(buffer, index);
        appendNewline(buffer);
        appendStore(buffer); buffer.append("i8 ");
        appendDecimal(buffer, decoded.data[index]);
        appendPtr(buffer); appendDecimal(buffer, address);
        appendNewline(buffer);
    }
    var temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    appendInsertValue(buffer); appendSpacedStringType(buffer);
    buffer.append("undef, ptr ");
    buffer.append("%"); appendDecimal(buffer, data); appendIndexZero(buffer);
    temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    appendInsertValue(buffer); appendSpacedStringType(buffer);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
    appendI64Prefix(buffer); appendDecimal(buffer, decoded.length);
    appendIndexOne(buffer);
    temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    appendInsertValue(buffer); appendSpacedStringType(buffer);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
    appendI64Prefix(buffer); appendDecimal(buffer, capacity);
    buffer.append(", 2"); appendNewline(buffer);
    return IrValue(2, 0, 0, temporary, TypeKind.String.value, 0, 0);
}

fn emitExpression(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    root: u64,
    var counter: IrCounter): IrValue {
    val node = nodes.data[root];
    if (node.kind == AstKind.Literal) {
        if (node.typeKind == TypeKind.NullLiteral.value) {
            return IrValue(3, 0, 0, 0, TypeKind.NullLiteral.value, 0, 0);
        }
        if (node.typeKind == TypeKind.Slice.value && node.typePointee == TypeKind.U8.value) {
            var decoded = decodeStringLiteral(source, node);
            defer decoded.free();
            var temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
            appendInsertValue(buffer); appendType(buffer, genericArguments, 13, 0, 5);
            buffer.append(" undef, ptr @.ks"); appendDecimal(buffer, root);
            buffer.append(", 0"); appendNewline(buffer);
            temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
            appendInsertValue(buffer); appendType(buffer, genericArguments, 13, 0, 5);
            buffer.append(" "); appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
            buffer.append(", i64 "); appendDecimal(buffer, decoded.length);
            buffer.append(", 1"); appendNewline(buffer);
            return IrValue(2, 0, 0, temporary, TypeKind.Slice.value, 0, TypeKind.U8.value);
        }
        if (node.typeKind == TypeKind.String.value) {
            var decoded = decodeStringLiteral(source, node);
            defer decoded.free();
            var temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer); appendInsertValue(buffer);
            appendStringInsertPointer(buffer);
            appendDecimal(buffer, root); appendIndexZero(buffer);
            temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer); appendInsertValue(buffer);
            appendSpacedStringType(buffer);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
            appendI64Prefix(buffer); appendDecimal(buffer, decoded.length);
            appendIndexOne(buffer);
            temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer); appendInsertValue(buffer);
            appendSpacedStringType(buffer);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
            appendStringCapacity(buffer);
            return IrValue(2, 0, 0, temporary, TypeKind.String.value, 0, 0);
        }
        return IrValue(
            1, node.start, node.end, 0,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.IfExpression) {
        val thenCount = node.aux % 65536;
        val elseCount = node.aux / 65536;
        val elseValueRoot = root - 1;
        val elseRoots =
            k_boot_alloc((elseCount as u64) * sizeof(u64)) as u64*;
        var childRoot = nodes.data[elseValueRoot].subtreeStart - 1;
        for (index in elseCount>..0) {
            elseRoots[index as u64] = childRoot;
            childRoot = nodes.data[childRoot].subtreeStart - 1;
        }
        val thenValueRoot = childRoot;
        val thenRoots =
            k_boot_alloc((thenCount as u64) * sizeof(u64)) as u64*;
        childRoot = nodes.data[thenValueRoot].subtreeStart - 1;
        for (index in thenCount>..0) {
            thenRoots[index as u64] = childRoot;
            childRoot = nodes.data[childRoot].subtreeStart - 1;
        }
        val condition = emitExpression(
            buffer, source, nodes, genericArguments, childRoot, counter);
        val thenBlock = nextBlock(counter);
        val elseBlock = nextBlock(counter);
        val mergeBlock = nextBlock(counter);
        appendConditionalBranch(
            buffer, source, condition, thenBlock, elseBlock);
        appendBlockLabel(buffer, counter, thenBlock);
        for (index in 0..<thenCount) {
            val statement = nodes.data[thenRoots[index as u64]];
            if (statement.kind == AstKind.VariableDeclaration) {
                emitVariableAlloca(
                    buffer, genericArguments, nodes,
                    thenRoots[index as u64]);
            }
        }
        var thenDefers = List<u64>.new();
        defer thenDefers.free();
        for (index in 0..<thenCount) {
            emitStatement(
                buffer, source, nodes, genericArguments,
                thenRoots[index as u64], counter, thenDefers);
        }
        val thenValue = emitExpression(
            buffer, source, nodes, genericArguments, thenValueRoot, counter);
        emitDeferRange(
            buffer, source, nodes, genericArguments,
            counter, thenDefers, thenDefers.length, 0);
        val thenValueBlock = counter.currentBlock;
        appendBranch(buffer, mergeBlock);
        appendBlockLabel(buffer, counter, elseBlock);
        for (index in 0..<elseCount) {
            val statement = nodes.data[elseRoots[index as u64]];
            if (statement.kind == AstKind.VariableDeclaration) {
                emitVariableAlloca(
                    buffer, genericArguments, nodes,
                    elseRoots[index as u64]);
            }
        }
        var elseDefers = List<u64>.new();
        defer elseDefers.free();
        for (index in 0..<elseCount) {
            emitStatement(
                buffer, source, nodes, genericArguments,
                elseRoots[index as u64], counter, elseDefers);
        }
        val elseValue = emitExpression(
            buffer, source, nodes, genericArguments, elseValueRoot, counter);
        emitDeferRange(
            buffer, source, nodes, genericArguments,
            counter, elseDefers, elseDefers.length, 0);
        val elseValueBlock = counter.currentBlock;
        appendBranch(buffer, mergeBlock);
        appendBlockLabel(buffer, counter, mergeBlock);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, temporary);
        appendEquals(buffer);
        buffer.append("phi ");
        appendNodeType(buffer, genericArguments, node);
        buffer.append(" [");
        buffer.append(" "); appendIrValue(buffer, source, thenValue);
        buffer.append(", ");
        appendBlockReference(buffer, thenValueBlock);
        buffer.append(" ], [ ");
        appendIrValue(buffer, source, elseValue);
        buffer.append(", ");
        appendBlockReference(buffer, elseValueBlock);
        buffer.append(" ]");
        appendNewline(buffer);
        k_boot_free(thenRoots as unit*);
        k_boot_free(elseRoots as unit*);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.WhenExpression) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        val roots = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        val values =
            k_boot_alloc((branchCount as u64) * sizeof(IrValue)) as IrValue*;
        val blocks = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        for (index in branchCount>..0) {
            roots[index as u64] = branchRoot;
            branchRoot = nodes.data[branchRoot].subtreeStart - 1;
        }
        var subject = IrValue(0, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
        if (hasSubject == 1) {
            subject = emitExpression(
                buffer, source, nodes, genericArguments, branchRoot, counter);
        }
        val mergeBlock = nextBlock(counter);
        var hasElse = false;
        for (index in 0..<branchCount) {
            val branch = nodes.data[roots[index as u64]];
            val valueRoot = roots[index as u64] - 1;
            val statementCount = (branch.aux % 65536) / 2;
            val statementRoots =
                k_boot_alloc((statementCount as u64) * sizeof(u64)) as u64*;
            var beforeValue = nodes.data[valueRoot].subtreeStart - 1;
            for (statementIndex in statementCount>..0) {
                statementRoots[statementIndex as u64] = beforeValue;
                beforeValue = nodes.data[beforeValue].subtreeStart - 1;
            }
            for (statementIndex in 0..<statementCount) {
                val statement = nodes.data[statementRoots[statementIndex as u64]];
                if (statement.kind == AstKind.VariableDeclaration) {
                    emitVariableAlloca(
                        buffer, genericArguments, nodes,
                        statementRoots[statementIndex as u64]);
                }
            }
            val bodyBlock = nextBlock(counter);
            var nextBlockValue = mergeBlock;
            if (branch.aux % 2 == 0) {
                nextBlockValue = nextBlock(counter);
                val patternCount = branch.aux / 65536;
                val patternRoots =
                    k_boot_alloc((patternCount as u64) * sizeof(u64)) as u64*;
                var patternRoot = beforeValue;
                for (patternIndex in patternCount>..0) {
                    patternRoots[patternIndex as u64] = patternRoot;
                    patternRoot = nodes.data[patternRoot].subtreeStart - 1;
                }
                for (patternIndex in 0..<patternCount) {
                    var condition = emitExpression(
                        buffer, source, nodes, genericArguments,
                        patternRoots[patternIndex as u64], counter);
                    if (hasSubject == 1) {
                        val compared = nextTemporary(counter);
                        appendValuePrefix(buffer); appendDecimal(buffer, compared);
                        appendEquals(buffer); appendComparison(buffer, 79, subject.typeKind);
                        buffer.append(" ");
                        appendType(
                            buffer, genericArguments,
                            subject.typeKind, subject.typeName, subject.typePointee);
                        buffer.append(" "); appendIrValue(buffer, source, subject);
                        buffer.append(", ");
                        appendIrValue(buffer, source, condition); appendNewline(buffer);
                        condition = IrValue(2, 0, 0, compared, TypeKind.Bool.value, 0, 0);
                    }
                    var missBlock = nextBlockValue;
                    val hasNextPattern = patternIndex + 1 < patternCount;
                    if (hasNextPattern) missBlock = nextBlock(counter);
                    appendConditionalBranch(
                        buffer, source, condition, bodyBlock, missBlock);
                    if (hasNextPattern) {
                        appendBlockLabel(buffer, counter, missBlock);
                    }
                }
                k_boot_free(patternRoots as unit*);
            } else {
                hasElse = true;
                appendBranch(buffer, bodyBlock);
            }
            appendBlockLabel(buffer, counter, bodyBlock);
            var branchDefers = List<u64>.new();
            defer branchDefers.free();
            for (statementIndex in 0..<statementCount) {
                emitStatement(
                    buffer, source, nodes, genericArguments,
                    statementRoots[statementIndex as u64], counter, branchDefers);
            }
            values[index as u64] = emitExpression(
                buffer, source, nodes, genericArguments, valueRoot, counter);
            emitDeferRange(
                buffer, source, nodes, genericArguments,
                counter, branchDefers, branchDefers.length, 0);
            blocks[index as u64] = counter.currentBlock;
            appendBranch(buffer, mergeBlock);
            if (branch.aux % 2 == 0) {
                appendBlockLabel(buffer, counter, nextBlockValue);
            }
            k_boot_free(statementRoots as unit*);
        }
        if (!hasElse) {
            appendUnreachable(buffer); 
            appendNewline(buffer); 
        }
        appendBlockLabel(buffer, counter, mergeBlock);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, temporary);
        appendEquals(buffer);
        buffer.append("phi ");
        appendNodeType(buffer, genericArguments, node);
        buffer.append(" ");
        for (index in 0..<branchCount) {
            if (index > 0) {
                buffer.append(", ");
            }
            buffer.append("[ ");
            appendIrValue(buffer, source, values[index as u64]);
            buffer.append(", ");
            appendBlockReference(buffer, blocks[index as u64]);
            buffer.append(" ]");
        }
        appendNewline(buffer);
        k_boot_free(blocks as unit*);
        k_boot_free(values as unit*);
        k_boot_free(roots as unit*);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.ArrayLiteral) {
        if (node.aux == 0) {
            return IrValue(
                5, 0, 0, 0,
                node.typeKind, node.typeName, node.typePointee);
        }
        val roots =
            k_boot_alloc((node.aux as u64) * sizeof(u64)) as u64*;
        var childRoot = root - 1;
        for (index in node.aux>..0) {
            roots[index as u64] = childRoot;
            childRoot = nodes.data[childRoot].subtreeStart - 1;
        }
        var aggregate = IrValue(
            3, 0, 0, 0, node.typeKind, node.typeName, node.typePointee);
        for (index in 0..<node.aux) {
            val element = emitExpression(
                buffer, source, nodes, genericArguments,
                roots[index as u64], counter);
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer); appendInsertValue(buffer);
            appendNodeType(buffer, genericArguments, node);
            buffer.append(" ");
            if (index == 0) {
                buffer.append("undef");
            } else {
                appendIrValue(buffer, source, aggregate);
            }
            buffer.append(", ");
            appendType(
                buffer, genericArguments,
                node.typePointee % 256, node.typeName, 0);
            buffer.append(" "); appendIrValue(buffer, source, element);
            buffer.append(", ");
            appendDecimal(buffer, index as u64); appendNewline(buffer);
            aggregate = IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        k_boot_free(roots as unit*);
        return aggregate;
    }
    if (node.kind == AstKind.Unary) {
        val operandRoot = root - 1;
        if (node.aux == TokenKind.Ampersand.value) {
            return emitAddress(
                buffer, source, nodes, genericArguments,
                operandRoot, counter);
        }
        val operand = emitExpression(
            buffer, source, nodes, genericArguments,
            operandRoot, counter);
        if (node.aux == TokenKind.Star.value) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            appendLoad(buffer);
            appendNodeType(buffer, genericArguments, node);
            appendPointerValue(buffer, source, operand);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.aux == TokenKind.Minus.value) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            if (TypeValue(typeKindFromValue(node.typeKind), node.typeName, node.typePointee).isFloat()) {
                buffer.append("fneg ");
                appendNodeType(buffer, genericArguments, node);
                buffer.append(" ");
            } else {
                buffer.append("sub ");
                appendNodeType(buffer, genericArguments, node);
                buffer.append(" 0, ");
            }
            appendIrValue(buffer, source, operand);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.aux == TokenKind.Bang.value) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            buffer.append("xor ");
            appendNodeType(buffer, genericArguments, node);
            buffer.append(" ");
            appendIrValue(buffer, source, operand);
            buffer.append(", true");
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        return operand;
    }
    if (node.kind == AstKind.Identifier) {
        var isConstant = node.aux == 1;
        if (node.storage < nodes.length) {
            if (nodes.data[node.storage].kind == AstKind.ConstantDeclaration)
                isConstant = true;
        }
        if (isConstant) {
            return emitExpression(
                buffer, source, nodes, genericArguments,
                node.storage - 1, counter);
        }
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendLoad(buffer);
        appendNodeType(buffer, genericArguments, node);
        appendPtr(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, node.storage);
        appendNewline(buffer);
        if (node.ownership % 2 == 1)
            emitClearAutomaticDrop(buffer, nodes, root);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Binary) {
        val rightRoot = root - 1;
        val leftRoot = expressionChildBefore(nodes, rightRoot);
        if (node.aux == TokenKind.KwIn.value) {
            val range = nodes.data[rightRoot];
            val upperRoot = rightRoot - 1;
            val lowerRoot = expressionChildBefore(nodes, upperRoot);
            val subject = emitExpression(
                buffer, source, nodes, genericArguments, leftRoot, counter);
            val lower = emitExpression(
                buffer, source, nodes, genericArguments, lowerRoot, counter);
            val upper = emitExpression(
                buffer, source, nodes, genericArguments, upperRoot, counter);
            var lowerOperator: u32 = 82;
            if (range.aux == TokenKind.RangeExclusiveStart.value ||
                range.aux == TokenKind.RangeExclusiveBoth.value)
                lowerOperator = TokenKind.Greater.value;
            var upperOperator: u32 = 81;
            if (range.aux == TokenKind.RangeExclusive.value ||
                range.aux == TokenKind.RangeExclusiveBoth.value)
                upperOperator = TokenKind.Less.value;
            val lowerCheck = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, lowerCheck); appendEquals(buffer);
            appendComparison(buffer, lowerOperator, subject.typeKind);
            buffer.append(" ");
            appendType(
                buffer, genericArguments,
                subject.typeKind, subject.typeName, subject.typePointee);
            buffer.append(" "); appendIrValue(buffer, source, subject);
            buffer.append(", ");
            appendIrValue(buffer, source, lower); appendNewline(buffer);
            val upperCheck = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, upperCheck); appendEquals(buffer);
            appendComparison(buffer, upperOperator, subject.typeKind);
            buffer.append(" ");
            appendType(
                buffer, genericArguments,
                subject.typeKind, subject.typeName, subject.typePointee);
            buffer.append(" "); appendIrValue(buffer, source, subject);
            buffer.append(", ");
            appendIrValue(buffer, source, upper); appendNewline(buffer);
            val result = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, result); appendEquals(buffer);
            buffer.append("and i1 %");
            appendDecimal(buffer, lowerCheck); buffer.append(",");
            buffer.append(" %");
            appendDecimal(buffer, upperCheck); appendNewline(buffer);
            return IrValue(2, 0, 0, result, TypeKind.Bool.value, 0, 0);
        }
        var left = emitExpression(
            buffer, source, nodes, genericArguments,
            leftRoot, counter);
        var logical = node.aux == TokenKind.AndAnd.value;
        if (node.aux == TokenKind.OrOr.value) logical = true;
        if (logical) {
            val leftBlock = counter.currentBlock;
            val rhsBlock = nextBlock(counter);
            val mergeBlock = nextBlock(counter);
            if (node.aux == TokenKind.AndAnd.value) {
                appendConditionalBranch(
                    buffer, source, left, rhsBlock, mergeBlock);
            } else {
                appendConditionalBranch(
                    buffer, source, left, mergeBlock, rhsBlock);
            }
            appendBlockLabel(buffer, counter, rhsBlock);
            val right = emitExpression(
                buffer, source, nodes, genericArguments,
                rightRoot, counter);
            val rightBlock = counter.currentBlock;
            appendBranch(buffer, mergeBlock);
            appendBlockLabel(buffer, counter, mergeBlock);
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer);
            buffer.append("phi i1 [");
            if (node.aux == TokenKind.AndAnd.value) buffer.append("0");
            else buffer.append("1");
            buffer.append(", ");
            appendBlockReference(buffer, leftBlock);
            buffer.append(" ], [");
            appendIrValue(buffer, source, right);
            buffer.append(", ");
            appendBlockReference(buffer, rightBlock);
            buffer.append(" ]");
            appendNewline(buffer);
            return IrValue(2, 0, 0, temporary, TypeKind.Bool.value, 0, 0);
        }
        var right = emitExpression(
            buffer, source, nodes, genericArguments,
            rightRoot, counter);
        var comparison = false;
        if (node.aux == TokenKind.Less.value) comparison = true;
        if (node.aux == TokenKind.Greater.value) comparison = true;
        if (node.aux == TokenKind.EqualEqual.value) comparison = true;
        if (node.aux == TokenKind.BangEqual.value) comparison = true;
        if (node.aux == TokenKind.LessEqual.value) comparison = true;
        if (node.aux == TokenKind.GreaterEqual.value) comparison = true;
        if (comparison) {
            val leftType = TypeValue(typeKindFromValue(left.typeKind), left.typeName, left.typePointee);
            val rightType = TypeValue(typeKindFromValue(right.typeKind), right.typeName, right.typePointee);
            if (integerImplicitlyWidens(leftType, rightType)) {
                left = emitImplicitIntegerWiden(
                    buffer, source, genericArguments, left,
                    right.typeKind, right.typeName, right.typePointee, counter);
            } else {
                if (integerImplicitlyWidens(rightType, leftType)) {
                    right = emitImplicitIntegerWiden(
                        buffer, source, genericArguments, right,
                        left.typeKind, left.typeName, left.typePointee, counter);
                }
            }
        } else {
            left = emitImplicitIntegerWiden(
                buffer, source, genericArguments, left,
                node.typeKind, node.typeName, node.typePointee, counter);
            right = emitImplicitIntegerWiden(
                buffer, source, genericArguments, right,
                node.typeKind, node.typeName, node.typePointee, counter);
        }
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        if (comparison) appendComparison(buffer, node.aux, left.typeKind);
        else appendOperator(buffer, node.aux, node.typeKind);
        buffer.append(" ");
        if (comparison) {
            appendType(
                buffer, genericArguments, left.typeKind, left.typeName, left.typePointee);
        } else {
            appendNodeType(buffer, genericArguments, node);
        }
        buffer.append(" ");
        appendIrValue(buffer, source, left);
        buffer.append(", ");
        appendIrValue(buffer, source, right);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Assignment) {
        val rightRoot = root - 1;
        val leftRoot = expressionChildBefore(nodes, rightRoot);
        var right = emitExpression(
            buffer, source, nodes, genericArguments,
            rightRoot, counter);
        val target = emitAddress(
            buffer, source, nodes, genericArguments,
            leftRoot, counter);
        val targetNode = nodes.data[leftRoot];
        right = emitImplicitIntegerWiden(
            buffer, source, genericArguments, right,
            targetNode.typeKind, targetNode.typeName,
            targetNode.typePointee, counter);
        if (node.aux != TokenKind.Equal.value) {
            val loaded = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
            appendLoad(buffer);
            appendType(
                buffer, genericArguments, targetNode.typeKind,
                targetNode.typeName, targetNode.typePointee);
            appendPointerValue(buffer, source, target); appendNewline(buffer);
            val updated = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, updated); appendEquals(buffer);
            appendOperator(buffer, node.aux - 14, targetNode.typeKind);
            buffer.append(" ");
            appendType(
                buffer, genericArguments, targetNode.typeKind,
                targetNode.typeName, targetNode.typePointee);
            buffer.append(" %");
            appendDecimal(buffer, loaded); buffer.append(",");
            buffer.append(" "); appendIrValue(buffer, source, right);
            appendNewline(buffer);
            right = IrValue(
                2, 0, 0, updated, targetNode.typeKind,
                targetNode.typeName, targetNode.typePointee);
        }
        if (node.aux == TokenKind.Equal.value &&
            (targetNode.ownership / 2) % 2 == 1) {
            val declarationRoot = emitterVariableRootByStorage(
                nodes, targetNode.storage);
            if (declarationRoot != nodes.length)
                emitAutomaticDrop(
                    buffer, source, nodes, genericArguments,
                    declarationRoot, counter);
        }
        appendStore(buffer);
        appendType(
            buffer, genericArguments, targetNode.typeKind,
            targetNode.typeName, targetNode.typePointee);
        buffer.append(" ");
        appendIrValue(buffer, source, right);
        appendPointerValue(buffer, source, target);
        appendNewline(buffer);
        if (node.aux == TokenKind.Equal.value &&
            (targetNode.ownership / 2) % 2 == 1) {
            appendStore(buffer); buffer.append("i1 ");
            buffer.append("true");
            appendPtr(buffer); appendDropFlagName(buffer, targetNode.storage);
            appendNewline(buffer);
        }
        return right;
    }
    if (node.kind == AstKind.Cast) {
        val typeRoot = root - 1;
        val valueRoot = expressionChildBefore(nodes, typeRoot);
        val value = emitExpression(
            buffer, source, nodes, genericArguments,
            valueRoot, counter);
        if (node.typeKind == value.typeKind) return value;
        if (node.typeKind == TypeKind.Pointer.value) return value;
        if (value.typeKind == TypeKind.Pointer.value) return value;
        val sourceType = TypeValue(typeKindFromValue(value.typeKind), value.typeName, value.typePointee);
        val targetType = TypeValue(typeKindFromValue(node.typeKind), node.typeName, node.typePointee);
        if (node.conversionKind >= 5) {
            if (node.conversionKind == 6) {
                val lower = nextTemporary(counter);
                val upper = nextTemporary(counter);
                val check = nextTemporary(counter);
                appendFloatRangeComparison(
                    buffer, source, genericArguments, value,
                    targetType.kind.value, lower, true);
                appendFloatRangeComparison(
                    buffer, source, genericArguments, value,
                    targetType.kind.value, upper, false);
                appendValuePrefix(buffer); appendDecimal(buffer, check);
                appendEquals(buffer);
                buffer.append("and i1 %");
                appendDecimal(buffer, lower); buffer.append(",");
                buffer.append(" %");
                appendDecimal(buffer, upper); appendNewline(buffer);
                val validBlock = nextBlock(counter);
                val panicBlock = nextBlock(counter);
                appendConditionalBranch(
                    buffer, source, IrValue(2, 0, 0, check, TypeKind.Bool.value, 0, 0),
                    validBlock, panicBlock);
                appendBlockLabel(buffer, counter, panicBlock);
                appendCastPanic(buffer);
                appendBlockLabel(buffer, counter, validBlock);
            }
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer);
            var opcode: u32 = 1;
            if (sourceType.isInteger()) {
                opcode = 4;
                if (sourceType.isSigned()) opcode = 3;
            } else {
                if (targetType.isInteger()) {
                    opcode = 6;
                    if (targetType.isSigned()) opcode = 5;
                } else {
                    if (node.typeKind == TypeKind.F32.value) opcode = 2;
                }
            }
            appendFloatCastOpcode(buffer, opcode);
            buffer.append(" ");
            appendType(
                buffer, genericArguments,
                value.typeKind, value.typeName, value.typePointee);
            buffer.append(" "); appendIrValue(buffer, source, value);
            buffer.append(" to ");
            appendNodeType(buffer, genericArguments, node);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        val sourceWidth = sourceType.intWidth();
        val targetWidth = targetType.intWidth();
        var converted = IrValue(
            value.kind, value.start, value.end, value.temporary,
            node.typeKind, node.typeName, node.typePointee);
        if (sourceWidth != targetWidth) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            var opcode: u32 = 3;
            if (targetWidth > sourceWidth) {
                opcode = 2;
                if (sourceType.isSigned()) opcode = 1;
            }
            appendCastOpcode(buffer, opcode);
            buffer.append(" ");
            appendType(
                buffer, genericArguments, value.typeKind,
                value.typeName, value.typePointee);
            buffer.append(" ");
            appendIrValue(buffer, source, value);
            buffer.append(" to ");
            appendNodeType(buffer, genericArguments, node);
            appendNewline(buffer);
            converted = IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.conversionKind == 4) {
            var check: u64 = 0;
            if (sourceWidth != targetWidth) {
                val roundTrip = nextTemporary(counter);
                check = nextTemporary(counter);
                appendValuePrefix(buffer); appendDecimal(buffer, roundTrip);
                appendEquals(buffer);
                var reverseOpcode: u32 = 2;
                if (targetType.isSigned()) reverseOpcode = 1;
                appendCastOpcode(buffer, reverseOpcode);
                buffer.append(" ");
                appendNodeType(buffer, genericArguments, node);
                buffer.append(" ");
                appendIrValue(buffer, source, converted);
                buffer.append(" to ");
                appendType(
                    buffer, genericArguments, value.typeKind,
                    value.typeName, value.typePointee);
                appendNewline(buffer);
                appendValuePrefix(buffer); appendDecimal(buffer, check);
                appendEquals(buffer);
                buffer.append("icmp eq ");
                appendType(
                    buffer, genericArguments, value.typeKind,
                    value.typeName, value.typePointee);
                buffer.append(" "); appendIrValue(buffer, source, value);
                buffer.append(", ");
                buffer.append("%"); appendDecimal(buffer, roundTrip);
                appendNewline(buffer);
            } else {
                check = nextTemporary(counter);
                appendValuePrefix(buffer); appendDecimal(buffer, check);
                appendEquals(buffer);
                buffer.append("icmp ");
                var sourceSigned = sourceType.isSigned();
                if (sourceSigned) {
                    buffer.append("sge");
                } else {
                    buffer.append("ule");
                }
                buffer.append(" ");
                appendType(
                    buffer, genericArguments, value.typeKind,
                    value.typeName, value.typePointee);
                buffer.append(" "); appendIrValue(buffer, source, value);
                buffer.append(", ");
                if (sourceSigned) {
                    buffer.append("0");
                } else {
                    if (sourceWidth == 32) appendDecimal(buffer, 2147483647);
                    else appendDecimal(buffer, 9223372036854775807);
                }
                appendNewline(buffer);
            }
            val validBlock = nextBlock(counter);
            val panicBlock = nextBlock(counter);
            appendConditionalBranch(
                buffer, source, IrValue(2, 0, 0, check, TypeKind.Bool.value, 0, 0),
                validBlock, panicBlock);
            appendBlockLabel(buffer, counter, panicBlock);
            appendCastPanic(buffer);
            appendBlockLabel(buffer, counter, validBlock);
        }
        return converted;
    }
    if (node.kind == AstKind.Member) {
        val objectRoot = root - 1;
        val objectNode = nodes.data[objectRoot];
        if (objectNode.typeKind == TypeKind.Enum.value) {
            if (node.typeKind == TypeKind.Enum.value) {
                return IrValue(
                    3, 0, 0, node.storage, TypeKind.Enum.value,
                    node.typeName, node.typePointee);
            }
            return emitExpression(
                buffer, source, nodes, genericArguments,
                objectRoot, counter);
        }
        if (objectNode.typeKind == TypeKind.String.value) {
            val object = emitExpression(
                buffer, source, nodes, genericArguments,
                objectRoot, counter);
            val data = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, data); appendEquals(buffer);
            appendExtractValue(buffer); appendSpacedStringType(buffer);
            appendIrValue(buffer, source, object); buffer.append(", ");
            buffer.append("0"); appendNewline(buffer);
            val length = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, length); appendEquals(buffer);
            appendExtractValue(buffer); appendSpacedStringType(buffer);
            appendIrValue(buffer, source, object); buffer.append(", ");
            buffer.append("1"); appendNewline(buffer);
            val withData = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, withData); appendEquals(buffer);
            appendInsertValue(buffer); appendType(buffer, genericArguments, 13, 0, 5);
            buffer.append(" "); appendUndef(buffer); buffer.append(", ");
            buffer.append("ptr ");
            appendValuePrefix(buffer); appendDecimal(buffer, data);
            buffer.append(", 0"); appendNewline(buffer);
            val slice = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, slice); appendEquals(buffer);
            appendInsertValue(buffer); appendType(buffer, genericArguments, 13, 0, 5);
            buffer.append(" "); appendValuePrefix(buffer); appendDecimal(buffer, withData);
            buffer.append(", "); appendI64(buffer); buffer.append(" ");
            appendValuePrefix(buffer); appendDecimal(buffer, length);
            buffer.append(", 1"); appendNewline(buffer);
            return IrValue(2, 0, 0, slice, TypeKind.Slice.value, 0, TypeKind.U8.value);
        }
        val structureRoot =
            structRootByName(
                source, nodes, objectNode.typeName);
        val structure = nodes.data[structureRoot];
        val start = objectNode.typePointee % 65536;
        val count = objectNode.typePointee / 65536;
        
        var addressable = objectNode.kind == AstKind.Identifier;
        if (objectNode.kind == AstKind.Member) addressable = true;
        if (objectNode.kind == AstKind.Index) addressable = true;
        if (objectNode.kind == AstKind.Unary) {
            if (objectNode.aux == TokenKind.Star.value) addressable = true;
        }
        if (!addressable) {
            val object = emitExpression(
                buffer, source, nodes, genericArguments,
                objectRoot, counter);
            val fieldIndex = fieldIndexByName(
                source, nodes, structureRoot, node);
            val extracted = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, extracted);
            appendEquals(buffer);
            appendExtractValue(buffer);
            buffer.append(" ");
            appendType(buffer, genericArguments, 8, objectNode.typeName, objectNode.typePointee);
            buffer.append(" ");
            appendIrValue(buffer, source, object);
            buffer.append(", ");
            appendDecimal(buffer, fieldIndex as u64);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, extracted,
                node.typeKind, node.typeName, node.typePointee);
        }
        val address = emitAddress(
            buffer, source, nodes, genericArguments, root, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendLoad(buffer);
        appendNodeType(buffer, genericArguments, node);
        appendPointerValue(buffer, source, address);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Index) {
        val indexRoot = root - 1;
        val objectRoot = expressionChildBefore(nodes, indexRoot);
        val objectNode = nodes.data[objectRoot];
        var constantArray = false;
        if (objectNode.kind == AstKind.Identifier && objectNode.typeKind == TypeKind.Array.value) {
            if (objectNode.storage < nodes.length) {
                if (nodes.data[objectNode.storage].kind ==
                    AstKind.ConstantDeclaration) constantArray = true;
            }
        }
        var constantIndex = constantArray;
        if (nodes.data[indexRoot].kind != AstKind.Literal)
            constantIndex = false;
        if (constantIndex) {
            val object = emitExpression(
                buffer, source, nodes, genericArguments,
                objectRoot, counter);
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer); appendExtractValue(buffer);
            appendType(
                buffer, genericArguments,
                object.typeKind, object.typeName, object.typePointee);
            buffer.append(" "); appendIrValue(buffer, source, object);
            buffer.append(", ");
            appendSource(
                buffer, source,
                nodes.data[indexRoot].start, nodes.data[indexRoot].end);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        val address = emitAddress(
            buffer, source, nodes, genericArguments, root, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendLoad(buffer);
        appendNodeType(buffer, genericArguments, node);
        appendPointerValue(buffer, source, address);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Postfix) {
        if (node.aux == TokenKind.PlusPlus.value ||
            node.aux == TokenKind.MinusMinus.value) {
            val valueRoot = root - 1;
            val address = emitAddress(
                buffer, source, nodes, genericArguments, valueRoot, counter);
            val loaded = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
            appendLoad(buffer); appendNodeType(buffer, genericArguments, node);
            appendPointerValue(buffer, source, address); appendNewline(buffer);
            val updated = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, updated); appendEquals(buffer);
            var operatorKind: u32 = 60;
            if (node.aux == TokenKind.MinusMinus.value)
                operatorKind = TokenKind.Minus.value;
            appendOperator(buffer, operatorKind, node.typeKind);
            buffer.append(" "); appendNodeType(buffer, genericArguments, node);
            buffer.append(" %");
            appendDecimal(buffer, loaded); buffer.append(",");
            buffer.append(" 1");
            if (TypeValue(typeKindFromValue(node.typeKind), node.typeName, node.typePointee).isFloat()) {
                buffer.append(".000000e+00");
            }
            appendNewline(buffer);
            appendStore(buffer); appendNodeType(buffer, genericArguments, node);
            buffer.append(" %");
            appendDecimal(buffer, updated); appendPointerValue(buffer, source, address);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, updated,
                node.typeKind, node.typeName, node.typePointee);
        }
        val operand = emitExpression(
            buffer, source, nodes, genericArguments,
            root - 1, counter);
        val hasValue = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, hasValue);
        appendEquals(buffer);
        buffer.append("extractvalue ");
        appendType(
            buffer, genericArguments, operand.typeKind, operand.typeName, operand.typePointee);
        buffer.append(" ");
        appendIrValue(buffer, source, operand);
        buffer.append(", 0");
        appendNewline(buffer);
        val validBlock = nextBlock(counter);
        val panicBlock = nextBlock(counter);
        appendConditionalBranch(
            buffer, source,
            IrValue(2, 0, 0, hasValue, TypeKind.Bool.value, 0, 0),
            validBlock, panicBlock);
        appendBlockLabel(buffer, counter, panicBlock);
        buffer.append("  call void @k_boot_panic(ptr null, i64 0)");
        appendNewline(buffer);
        buffer.append("  unreachable");
        appendNewline(buffer);
        appendBlockLabel(buffer, counter, validBlock);
        val value = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, value);
        appendEquals(buffer);
        buffer.append("extractvalue ");
        appendType(
            buffer, genericArguments, operand.typeKind, operand.typeName, operand.typePointee);
        buffer.append(" ");
        appendIrValue(buffer, source, operand);
        buffer.append(", 1");
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, value,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Sizeof) {
        val typeNode = nodes.data[root - 1];
        return IrValue(
            3, 0, 0,
            typeSize(
                source, nodes, genericArguments, typeNode.typeKind,
                typeNode.typeName, typeNode.typePointee),
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Call) {
        var argumentCount = node.aux % 65536;
        val explicitTypeCount = node.aux / 65536;
        val arguments =
            k_boot_alloc(
                ((argumentCount + 1) as u64) * sizeof(u64)) as u64*;
        var cursor = root - 1;
        for (argument in argumentCount>..0) {
            arguments[argument as u64] = cursor;
            cursor = expressionChildBefore(nodes, cursor);
        }
        for (explicitType in 0..<explicitTypeCount) {
            cursor = expressionChildBefore(nodes, cursor);
        }
        val callee = nodes.data[cursor];
        val isMember = callee.kind == AstKind.Member;
        val calleeHash =
            sourceHash(source, callee.start, callee.end);
        var functionRoot = functionRootByName(source, nodes, calleeHash);
        if (isMember) functionRoot = node.storage;
        var isInstanceMethod = false;
        if (isMember && functionRoot != nodes.length) {
            isInstanceMethod =
                nodes.data[functionRoot].conversionKind == 1;
        }
        if (isInstanceMethod) {
            for (argument in argumentCount>..0) {
                arguments[argument as u64 + 1] = arguments[argument as u64];
            }
            arguments[0] = cursor - 1;
            argumentCount++;
        }
        val values =
            k_boot_alloc(
                (argumentCount as u64) * sizeof(IrValue)) as IrValue*;
        for (index in 0..<argumentCount) {
            var byReference = false;
            if (functionRoot != nodes.length) {
                val parameter = nodes.data[
                    parameterRoot(
                        nodes, functionRoot, index + 1)];
                if (parameter.aux == 2) byReference = true;
            }
            if (byReference) {
                values[index as u64] = emitAddress(
                    buffer, source, nodes, genericArguments,
                    arguments[index as u64], counter);
            } else {
                values[index as u64] = emitExpression(
                    buffer, source, nodes, genericArguments,
                    arguments[index as u64], counter);
                if (functionRoot != nodes.length) {
                    val parameterType = nodes.data[
                        parameterRoot(nodes, functionRoot, index + 1) - 1];
                    val concreteParameter = substituteEmitterType(
                        source, nodes, functionRoot,
                        TypeValue(
                            typeKindFromValue(parameterType.typeKind),
                            parameterType.typeName,
                            parameterType.typePointee),
                        genericArguments,
                        node.genericArgumentStart,
                        node.genericArgumentCount);
                    values[index as u64] = emitImplicitIntegerWiden(
                        buffer, source, genericArguments,
                        values[index as u64], concreteParameter.kind.value,
                        concreteParameter.name, concreteParameter.pointee,
                        counter);
                }
                if (functionRoot != nodes.length) {
                    val ownedParameter = nodes.data[
                        parameterRoot(nodes, functionRoot, index + 1)];
                    if (ownedParameter.aux == 0)
                        emitClearAutomaticDrop(
                            buffer, nodes, arguments[index as u64]);
                }
            }
        }
        val isSlice = functionRoot == nodes.length && !isMember &&
            calleeHash == 210727929557;
        if (isSlice) {
            values[1] = emitImplicitIntegerWiden(
                buffer, source, genericArguments, values[1], 7, 0, 0,
                counter);
            val dataTemporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, dataTemporary);
            appendEquals(buffer);
            appendInsertValue(buffer);
            buffer.append(" ");
            appendNodeType(buffer, genericArguments, node);
            buffer.append(" ");
            appendUndef(buffer);
            buffer.append(", ptr ");
            appendIrValue(buffer, source, values[0]);
            buffer.append(", 0");
            appendNewline(buffer);
            val lengthTemporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, lengthTemporary);
            appendEquals(buffer);
            appendInsertValue(buffer);
            buffer.append(" ");
            appendNodeType(buffer, genericArguments, node);
            buffer.append(" ");
            appendValuePrefix(buffer);
            appendDecimal(buffer, dataTemporary);
            buffer.append(", i64 ");
            appendIrValue(buffer, source, values[1]);
            buffer.append(", 1");
            appendNewline(buffer);
            k_boot_free(values as unit*);
            k_boot_free(arguments as unit*);
            return IrValue(
                2, 0, 0, lengthTemporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.typeKind == TypeKind.Struct.value) {
        if (functionRoot == nodes.length) {
            val structureRoot =
                structRootByName(source, nodes, node.typeName);
            val structure = nodes.data[structureRoot];
            val start = node.typePointee % 65536;
            val count = node.typePointee / 65536;
            var aggregateTemporary: u64 = 0;
            for (index in 0..<argumentCount) {
                aggregateTemporary = nextTemporary(counter);
                appendValuePrefix(buffer);
                appendDecimal(buffer, aggregateTemporary);
                appendEquals(buffer);
                appendInsertValue(buffer);
                buffer.append(" ");
                appendNodeType(buffer, genericArguments, node);
                buffer.append(" ");
                if (index == 0) {
                    appendUndef(buffer);
                } else {
                    buffer.append("%");
                    appendDecimal(buffer, aggregateTemporary - 1);
                }
                buffer.append(", ");
                
                val fieldRoot = fieldRootAt(nodes, structureRoot, index);
                val fieldTypeNode = nodes.data[fieldRoot - 1];
                var fieldType = TypeValue(typeKindFromValue(fieldTypeNode.typeKind), fieldTypeNode.typeName, fieldTypeNode.typePointee);
                if (count > 0) {
                    fieldType = substituteStructEmitterType(
                        source, nodes, structureRoot, fieldType,
                        genericArguments, start as u64, count);
                }
                appendType(
                    buffer, genericArguments,
                    fieldType.kind.value, fieldType.name, fieldType.pointee);
                
                buffer.append(" ");
                appendIrValue(
                    buffer, source, values[index as u64]);
                buffer.append(", ");
                appendDecimal(buffer, index as u64);
                appendNewline(buffer);
            }
            k_boot_free(values as unit*);
            k_boot_free(arguments as unit*);
            return IrValue(
                2, 0, 0, aggregateTemporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        }
        val isPrint = sourceNodeIsPrint(source, callee);
        if (isPrint && values[0].typeKind == TypeKind.String.value) {
            val dataTemporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary); appendEquals(buffer); appendExtractValue(buffer);
            appendSpacedStringType(buffer); appendIrValue(buffer, source, values[0]);
            appendIndexZero(buffer);
            val lengthTemporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary); appendEquals(buffer); appendExtractValue(buffer);
            appendSpacedStringType(buffer); appendIrValue(buffer, source, values[0]);
            appendExtractLengthAndPrint(buffer);
            appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary);
            appendI64Prefix(buffer); appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary);
            appendCloseLine(buffer);
            k_boot_free(values as unit*); k_boot_free(arguments as unit*);
            return IrValue(3, 0, 0, 0, TypeKind.Unit.value, 0, 0);
        }
        var temporary: u64 = 0;
        if (isPrint) {
            buffer.append("  ");
            appendCall(buffer);
            buffer.append("void @k_std_print_i32");
        } else {
            if (node.typeKind != TypeKind.Unit.value) {
                temporary = nextTemporary(counter);
                appendValuePrefix(buffer);
                appendDecimal(buffer, temporary);
                appendEquals(buffer);
            } else {
                buffer.append("  ");
            }
            appendCall(buffer);
            appendNodeType(buffer, genericArguments, node);
            appendFunctionOpen(buffer);
            if (isMember) {
                if (isInstanceMethod) {
                    val ownerType = nodes.data[arguments[0]].typeName;
                    val ownerRoot = structRootByName(source, nodes, ownerType);
                    val ownerName = nodes.data[nodes.data[ownerRoot].subtreeStart];
                    appendSource(buffer, source, ownerName.start, ownerName.end);
                    buffer.append(".");
                } else {
                    val ownerRoot = emitterAssociatedOwnerStructRoot(
                        nodes, functionRoot);
                    val ownerName = nodes.data[nodes.data[ownerRoot].subtreeStart];
                    appendSource(buffer, source, ownerName.start, ownerName.end);
                    buffer.append(".");
                }
            }
            appendSource(buffer, source, callee.start, callee.end);
            if (functionRoot != nodes.length) {
                if (node.genericArgumentCount > 0) {
                    appendSpecializationSuffix(
                        buffer, genericArguments,
                        node.genericArgumentStart,
                        node.genericArgumentCount);
                }
            }
        }
        buffer.append("(");
        for (index in 0..<argumentCount) {
            if (index > 0) {
                buffer.append(", ");
            }
            if (functionRoot != nodes.length) {
                val callParameter = nodes.data[
                    parameterRoot(
                        nodes, functionRoot, index + 1)];
                if (callParameter.aux == 2) {
                    appendType(buffer, genericArguments, 9, 0, 0);
                } else {
                    val parameterType =
                        nodes.data[
                            parameterRoot(
                                nodes, functionRoot,
                                index + 1) - 1];
                    val concreteParameter = substituteEmitterType(
                        source, nodes, functionRoot,
                        TypeValue(
                            typeKindFromValue(parameterType.typeKind),
                            parameterType.typeName,
                            parameterType.typePointee),
                        genericArguments,
                        node.genericArgumentStart,
                        node.genericArgumentCount);
                    appendType(
                        buffer, genericArguments, concreteParameter.kind.value,
                        concreteParameter.name,
                        concreteParameter.pointee);
                }
            } else {
                appendType(
                    buffer, genericArguments,
                    values[index as u64].typeKind,
                    values[index as u64].typeName,
                    values[index as u64].typePointee);
            }
            buffer.append(" ");
            appendIrValue(buffer, source, values[index as u64]);
        }
        buffer.append(")");
        appendNewline(buffer);
        k_boot_free(values as unit*);
        k_boot_free(arguments as unit*);
        if (isPrint) return IrValue(3, 0, 0, 0, TypeKind.Unit.value, 0, 0);
        if (node.typeKind == TypeKind.Unit.value) {
            return IrValue(3, 0, 0, 0, TypeKind.Unit.value, 0, 0);
        }
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    return IrValue(0, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
}

fn blockStatementRoots(val nodes: List<AstNode>, blockRoot: u64): u64* {
    val block = nodes.data[blockRoot];
    val roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var root = blockRoot - 1;
    for (index in block.aux>..0) {
        roots[index as u64] = root;
        root = nodes.data[root].subtreeStart - 1;
    }
    return roots;
}

fn emitAutomaticDrop(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    root: u64,
    var counter: IrCounter) {
    val statement = nodes.data[root];
    if ((statement.ownership / 2) % 2 == 0) return;
    val name = nodes.data[statement.subtreeStart];
    var valueType = TypeValue(TypeKind.Invalid, 0, 0);
    if (statement.kind == AstKind.VariableDeclaration) {
        val initializerRoot = root - 1;
        valueType = TypeValue(
            typeKindFromValue(nodes.data[initializerRoot].typeKind),
            nodes.data[initializerRoot].typeName,
            nodes.data[initializerRoot].typePointee);
        val afterName = statement.subtreeStart + 1;
        if (afterName < nodes.data[initializerRoot].subtreeStart) {
            val declared = nodes.data[nodes.data[initializerRoot].subtreeStart - 1];
            valueType = TypeValue(
                typeKindFromValue(declared.typeKind), declared.typeName, declared.typePointee);
        }
    } else {
        val declared = nodes.data[root - 1];
        valueType = TypeValue(
            typeKindFromValue(declared.typeKind), declared.typeName, declared.typePointee);
    }
    var freeRoot = nodes.length;
    if (valueType.kind != TypeKind.String) {
        freeRoot = emitterDropFunctionRoot(source, nodes, valueType.name);
        if (freeRoot == nodes.length) return;
    }
    val live = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, live); appendEquals(buffer);
    appendLoad(buffer); buffer.append("i1");
    appendPtr(buffer); appendDropFlagName(buffer, name.start); appendNewline(buffer);
    val runBlock = nextBlock(counter);
    val endBlock = nextBlock(counter);
    appendConditionalBranch(
        buffer, source, IrValue(2, 0, 0, live, TypeKind.Bool.value, 0, 0),
        runBlock, endBlock);
    appendBlockLabel(buffer, counter, runBlock);
    appendStore(buffer); buffer.append("i1 ");
    buffer.append("false");
    appendPtr(buffer); appendDropFlagName(buffer, name.start); appendNewline(buffer);
    val loaded = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
    appendLoad(buffer);
    appendType(
        buffer, genericArguments,
        valueType.kind.value, valueType.name, valueType.pointee);
    appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
    appendNewline(buffer);
    if (valueType.kind == TypeKind.String) {
        val pointer = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, pointer); appendEquals(buffer);
        buffer.append("extractvalue");
        appendSpacedStringType(buffer); buffer.append("%"); appendDecimal(buffer, loaded);
        buffer.append(", 0"); appendNewline(buffer);
        buffer.append("  "); appendCall(buffer);
        buffer.append("void");
        appendFunctionOpen(buffer);
        buffer.append("k_std_free(ptr ");
        buffer.append("%"); appendDecimal(buffer, pointer);
        buffer.append(")"); appendNewline(buffer);
    } else {
        buffer.append("  "); appendCall(buffer);
        buffer.append("void");
        appendFunctionOpen(buffer);
        val structureRoot = structRootByName(source, nodes, valueType.name);
        val structureName = nodes.data[nodes.data[structureRoot].subtreeStart];
        appendSource(buffer, source, structureName.start, structureName.end);
        buffer.append(".");
        val freeName = nodes.data[nodes.data[freeRoot].subtreeStart];
        appendSource(buffer, source, freeName.start, freeName.end);
        val argumentCount = valueType.pointee / 65536;
        if (argumentCount > 0) {
            appendSpecializationSuffix(
                buffer, genericArguments,
                (valueType.pointee % 65536) as u64, argumentCount);
        }
        buffer.append("(");
        appendType(
            buffer, genericArguments,
            valueType.kind.value, valueType.name, valueType.pointee);
        buffer.append(" %"); appendDecimal(buffer, loaded);
        buffer.append(")"); appendNewline(buffer);
    }
    appendBranch(buffer, endBlock);
    appendBlockLabel(buffer, counter, endBlock);
}

fn emitDeferRange(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    var counter: IrCounter,
    var defers: List<u64>,
    fromLen: u64,
    toLen: u64) {
    if (fromLen > toLen) {
        val count = fromLen - toLen;
        val saved = k_boot_alloc(count * sizeof(u64)) as u64*;
        for (idx in 0..<count) {
            saved[idx] = defers.data[fromLen - 1 - idx];
        }
        for (idx in 0..<count) {
            if (saved[idx] >= 9223372036854775808) {
                emitAutomaticDrop(
                    buffer, source, nodes, genericArguments,
                    saved[idx] - 9223372036854775808, counter);
            } else {
                emitStatement(
                    buffer, source, nodes, genericArguments,
                    saved[idx], counter, defers);
            }
        }
        k_boot_free(saved as unit*);
    }
}

fn emitBlock(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    root: u64,
    var counter: IrCounter,
    var defers: List<u64>): bool {
    if (nodes.data[root].kind != AstKind.Block) {
        return emitStatement(
            buffer, source, nodes, genericArguments,
            root, counter, defers);
    }
    val baseDepth = defers.length;
    val roots = blockStatementRoots(nodes, root);
    var terminated = false;
    for (index in 0..<nodes.data[root].aux) {
        if (!terminated) {
            terminated = emitStatement(
                buffer, source, nodes, genericArguments,
                roots[index as u64], counter, defers);
        }
    }
    k_boot_free(roots as unit*);
    if (!terminated) {
        emitDeferRange(
            buffer, source, nodes, genericArguments,
            counter, defers, defers.length, baseDepth);
    }
    defers.length = baseDepth;
    return terminated;
}

fn emitCollectionFor(
    var buffer: StringBuilder, source: Source, val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>, root: u64,
    var counter: IrCounter, var defers: List<u64>): bool {
    val statement = nodes.data[root];
    val bodyRoot = root - 1;
    val collectionRoot = expressionChildBefore(nodes, bodyRoot);
    val collectionNode = nodes.data[collectionRoot];
    val collectionValue = emitExpression(
        buffer, source, nodes, genericArguments, collectionRoot, counter);
    val valueName = nodes.data[statement.subtreeStart];
    var indexStorage = statement.start;
    if (statement.aux == 1) {
        indexStorage = nodes.data[statement.subtreeStart + 1].start;
    }
    var elementKind = collectionNode.typePointee;
    var elementName = collectionNode.typeName;
    var data = IrValue(0, 0, 0, 0, TypeKind.Pointer.value, elementName, elementKind);
    var length = IrValue(3, 0, 0, 0, TypeKind.U64.value, 0, 0);
    if (collectionNode.typeKind == TypeKind.Array.value) {
        elementKind = collectionNode.typePointee % 256;
        val pointer = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, pointer); appendEquals(buffer);
        appendGetElementPtr(buffer); buffer.append(" ");
        appendNodeType(buffer, genericArguments, collectionNode);
        appendPtr(buffer); appendLocalPrefix(buffer);
        appendDecimal(buffer, nodes.data[collectionRoot].storage);
        buffer.append(", ");
        appendI32(buffer); buffer.append(" 0");
        buffer.append(", ");
        appendI32(buffer); buffer.append(" 0");
        appendNewline(buffer);
        data = IrValue(2, 0, 0, pointer, TypeKind.Pointer.value, elementName, elementKind);
        length = IrValue(
            3, 0, 0, (collectionNode.typePointee / 256) as u64,
            7, 0, 0);
    } else {
        val dataTemporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary);
        appendEquals(buffer); appendExtractValue(buffer);
        appendNodeType(buffer, genericArguments, collectionNode);
        buffer.append(" "); appendIrValue(buffer, source, collectionValue);
        buffer.append(", 0");
        appendNewline(buffer);
        data = IrValue(2, 0, 0, dataTemporary, TypeKind.Pointer.value, elementName, elementKind);
        val lengthTemporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary);
        appendEquals(buffer); appendExtractValue(buffer);
        appendNodeType(buffer, genericArguments, collectionNode);
        buffer.append(" "); appendIrValue(buffer, source, collectionValue);
        buffer.append(", 1");
        appendNewline(buffer);
        length = IrValue(2, 0, 0, lengthTemporary, TypeKind.U64.value, 0, 0);
    }
    appendStore(buffer); appendI64(buffer); buffer.append(" ");
    buffer.append("0"); appendPtr(buffer); appendLocalPrefix(buffer);
    appendDecimal(buffer, indexStorage); appendNewline(buffer);
    val conditionBlock = nextBlock(counter);
    val bodyBlock = nextBlock(counter);
    val incrementBlock = nextBlock(counter);
    val endBlock = nextBlock(counter);
    appendBranch(buffer, conditionBlock);
    appendBlockLabel(buffer, counter, conditionBlock);
    val index = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, index); appendEquals(buffer);
    appendLoad(buffer); appendI64(buffer); appendPtr(buffer); appendLocalPrefix(buffer);
    appendDecimal(buffer, indexStorage); appendNewline(buffer);
    val compared = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, compared); appendEquals(buffer);
    appendComparison(buffer, 66, 7); buffer.append(" ");
    appendI64(buffer); buffer.append(" ");
    appendIrValue(buffer, source, IrValue(2, 0, 0, index, TypeKind.U64.value, 0, 0));
    buffer.append(", ");
    appendIrValue(buffer, source, length); appendNewline(buffer);
    appendConditionalBranch(
        buffer, source, IrValue(2, 0, 0, compared, TypeKind.Bool.value, 0, 0),
        bodyBlock, endBlock);
    appendBlockLabel(buffer, counter, bodyBlock);
    val elementPointer = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, elementPointer); appendEquals(buffer);
    appendGetElementPtr(buffer); buffer.append(" ");
    appendType(buffer, genericArguments, elementKind, elementName, 0);
    appendPointerValue(buffer, source, data);
    buffer.append(", "); appendI64(buffer);
    buffer.append(" ");
    appendIrValue(buffer, source, IrValue(2, 0, 0, index, TypeKind.U64.value, 0, 0));
    appendNewline(buffer);
    val element = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, element); appendEquals(buffer);
    appendLoad(buffer); appendType(buffer, genericArguments, elementKind, elementName, 0);
    appendPointerValue(
        buffer, source,
        IrValue(2, 0, 0, elementPointer, TypeKind.Pointer.value, elementName, elementKind));
    appendNewline(buffer);
    appendStore(buffer); appendType(buffer, genericArguments, elementKind, elementName, 0);
    buffer.append(" ");
    appendIrValue(buffer, source, IrValue(2, 0, 0, element, elementKind, elementName, 0));
    appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, valueName.start);
    appendNewline(buffer);
    val outerContinueBlock = counter.continueBlock;
    val outerBreakBlock = counter.breakBlock;
    val outerLoopDeferDepth = counter.loopDeferDepth;
    counter.continueBlock = incrementBlock; counter.breakBlock = endBlock;
    counter.loopDeferDepth = defers.length;
    val terminated = emitBlock(
        buffer, source, nodes, genericArguments, bodyRoot, counter, defers);
    counter.continueBlock = outerContinueBlock; counter.breakBlock = outerBreakBlock;
    counter.loopDeferDepth = outerLoopDeferDepth;
    if (!terminated) appendBranch(buffer, incrementBlock);
    appendBlockLabel(buffer, counter, incrementBlock);
    val loaded = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
    appendLoad(buffer); appendI64(buffer); appendPtr(buffer); appendLocalPrefix(buffer);
    appendDecimal(buffer, indexStorage); appendNewline(buffer);
    val advanced = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, advanced); appendEquals(buffer);
    appendOperator(buffer, 60, 7); buffer.append(" "); appendI64(buffer);
    buffer.append(" ");
    appendIrValue(buffer, source, IrValue(2, 0, 0, loaded, TypeKind.U64.value, 0, 0));
    buffer.append(", 1");
    appendNewline(buffer);
    appendStore(buffer); appendI64(buffer); buffer.append(" ");
    appendIrValue(buffer, source, IrValue(2, 0, 0, advanced, TypeKind.U64.value, 0, 0));
    appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, indexStorage);
    appendNewline(buffer); appendBranch(buffer, conditionBlock);
    appendBlockLabel(buffer, counter, endBlock);
    return false;
}

fn emitWhen(
    var buffer: StringBuilder, source: Source, val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>, root: u64,
    var counter: IrCounter, var defers: List<u64>): bool {
    val statement = nodes.data[root];
    val branchCount = statement.aux % 65536;
    val hasSubject = statement.aux / 65536;
    val roots =
        k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
    var branchRoot = root - 1;
    for (index in branchCount>..0) {
        roots[index as u64] = branchRoot;
        branchRoot = nodes.data[branchRoot].subtreeStart - 1;
    }
    var subject = IrValue(0, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
    if (hasSubject == 1) {
        subject = emitExpression(
            buffer, source, nodes, genericArguments, branchRoot, counter);
    }
    val mergeBlock = nextBlock(counter);
    var hasElse = false;
    var allTerminate = branchCount > 0;
    for (index in 0..<branchCount) {
        val branch = nodes.data[roots[index as u64]];
        val bodyRoot = roots[index as u64] - 1;
        val bodyBlock = nextBlock(counter);
        if (branch.aux % 2 == 0) {
            var nextBlockValue = mergeBlock;
            if (index + 1 < branchCount) {
                nextBlockValue = nextBlock(counter);
            }
            val patternCount = branch.aux / 65536;
            val patternRoots =
                k_boot_alloc((patternCount as u64) * sizeof(u64)) as u64*;
            var patternRoot = expressionChildBefore(nodes, bodyRoot);
            for (patternIndex in patternCount>..0) {
                patternRoots[patternIndex as u64] = patternRoot;
                patternRoot = nodes.data[patternRoot].subtreeStart - 1;
            }
            for (patternIndex in 0..<patternCount) {
                var condition = emitExpression(
                    buffer, source, nodes, genericArguments,
                    patternRoots[patternIndex as u64], counter);
                if (hasSubject == 1) {
                    val compared = nextTemporary(counter);
                    appendValuePrefix(buffer); appendDecimal(buffer, compared);
                    appendEquals(buffer); appendComparison(buffer, 79, subject.typeKind);
                    buffer.append(" ");
                    appendType(
                        buffer, genericArguments,
                        subject.typeKind, subject.typeName, subject.typePointee);
                    buffer.append(" "); appendIrValue(buffer, source, subject);
                    buffer.append(", ");
                    appendIrValue(buffer, source, condition); appendNewline(buffer);
                    condition = IrValue(2, 0, 0, compared, TypeKind.Bool.value, 0, 0);
                }
                var missBlock = nextBlockValue;
                val hasNextPattern = patternIndex + 1 < patternCount;
                if (hasNextPattern) missBlock = nextBlock(counter);
                appendConditionalBranch(
                    buffer, source, condition, bodyBlock, missBlock);
                if (hasNextPattern) {
                    appendBlockLabel(buffer, counter, missBlock);
                }
            }
            k_boot_free(patternRoots as unit*);
            appendBlockLabel(buffer, counter, bodyBlock);
            val terminated = emitBlock(
                buffer, source, nodes, genericArguments, bodyRoot, counter, defers);
            if (!terminated) appendBranch(buffer, mergeBlock);
            if (!terminated) allTerminate = false;
            if (index + 1 < branchCount) {
                appendBlockLabel(buffer, counter, nextBlockValue);
            }
        } else {
            hasElse = true;
            appendBranch(buffer, bodyBlock);
            appendBlockLabel(buffer, counter, bodyBlock);
            val terminated = emitBlock(
                buffer, source, nodes, genericArguments, bodyRoot, counter, defers);
            if (!terminated) appendBranch(buffer, mergeBlock);
            if (!terminated) allTerminate = false;
        }
    }
    k_boot_free(roots as unit*);
    if (hasElse) {
        if (allTerminate) return true;
    }
    appendBlockLabel(buffer, counter, mergeBlock);
    if (!hasElse && allTerminate && subject.typeKind == TypeKind.Enum.value) {
        appendUnreachable(buffer); appendNewline(buffer);
        return true;
    }
    return false;
}

fn emitStatement(
    var buffer: StringBuilder,
    source: Source,
    val nodes: List<AstNode>,
    var genericArguments: List<TypeValue>,
    root: u64,
    var counter: IrCounter,
    var defers: List<u64>): bool {
    val statement = nodes.data[root];
    if (statement.kind == AstKind.FunctionOrDefer) {
        defers.add(root - 1);
        return false;
    }
    if (statement.kind == AstKind.BreakStatement) {
        emitDeferRange(
            buffer, source, nodes, genericArguments,
            counter, defers, defers.length, counter.loopDeferDepth);
        appendBranch(buffer, counter.breakBlock);
        return true;
    }
    if (statement.kind == AstKind.ContinueStatement) {
        emitDeferRange(
            buffer, source, nodes, genericArguments,
            counter, defers, defers.length, counter.loopDeferDepth);
        appendBranch(buffer, counter.continueBlock);
        return true;
    }
    if (statement.kind == AstKind.ForStatement) {
        val bodyRoot = root - 1;
        val collectionRoot = expressionChildBefore(nodes, bodyRoot);
        val collectionNode = nodes.data[collectionRoot];
        var range = collectionNode.kind == AstKind.Binary;
        if (range) {
            range = collectionNode.aux == TokenKind.Range.value;
            if (collectionNode.aux == TokenKind.RangeExclusive.value) range = true;
            if (collectionNode.aux == TokenKind.RangeExclusiveStart.value) range = true;
            if (collectionNode.aux == TokenKind.RangeExclusiveBoth.value) range = true;
        }
        if (!range) {
            return emitCollectionFor(
                buffer, source, nodes, genericArguments, root, counter, defers);
        }
        val rightRoot = collectionRoot - 1;
        val leftRoot = expressionChildBefore(nodes, rightRoot);
        val start = emitExpression(
            buffer, source, nodes, genericArguments, leftRoot, counter);
        val finish = emitExpression(
            buffer, source, nodes, genericArguments, rightRoot, counter);
        val ascending = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, ascending); appendEquals(buffer);
        appendComparison(buffer, 81, start.typeKind); buffer.append(" ");
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" "); appendIrValue(buffer, source, start);
        buffer.append(", ");
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val different = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, different); appendEquals(buffer);
        appendComparison(buffer, 80, start.typeKind); buffer.append(" ");
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" "); appendIrValue(buffer, source, start);
        buffer.append(", ");
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val step = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, step); appendEquals(buffer);
        buffer.append("select i1 ");
        buffer.append("%"); appendDecimal(buffer, ascending);
        buffer.append(", ");
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" 1, ");
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" -");
        buffer.append("1"); appendNewline(buffer);
        var initial = start;
        if (collectionNode.aux == TokenKind.RangeExclusiveStart.value ||
            collectionNode.aux == TokenKind.RangeExclusiveBoth.value) {
            val shifted = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, shifted); appendEquals(buffer);
            appendOperator(buffer, 60, start.typeKind); buffer.append(" ");
            appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
            buffer.append(" "); appendIrValue(buffer, source, start);
            buffer.append(", ");
            buffer.append("%"); appendDecimal(buffer, step); appendNewline(buffer);
            initial = IrValue(
                2, 0, 0, shifted, start.typeKind, start.typeName, start.typePointee);
        }
        val name = nodes.data[statement.subtreeStart];
        appendStore(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" "); appendIrValue(buffer, source, initial);
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer);
        val conditionBlock = nextBlock(counter);
        val bodyBlock = nextBlock(counter);
        val incrementBlock = nextBlock(counter);
        val endBlock = nextBlock(counter);
        appendBranch(buffer, conditionBlock);
        appendBlockLabel(buffer, counter, conditionBlock);
        val current = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, current); appendEquals(buffer);
        appendLoad(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer);
        val ascendingCompared = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, ascendingCompared); appendEquals(buffer);
        var ascendingOperator: u32 = 81;
        if (collectionNode.aux == TokenKind.RangeExclusive.value ||
            collectionNode.aux == TokenKind.RangeExclusiveBoth.value)
            ascendingOperator = 66;
        appendComparison(buffer, ascendingOperator, start.typeKind);
        buffer.append(" "); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" ");
        appendIrValue(buffer, source, IrValue(2, 0, 0, current, start.typeKind, start.typeName, start.typePointee));
        buffer.append(", ");
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val descendingCompared = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, descendingCompared); appendEquals(buffer);
        var descendingOperator: u32 = 82;
        if (collectionNode.aux == TokenKind.RangeExclusive.value ||
            collectionNode.aux == TokenKind.RangeExclusiveBoth.value)
            descendingOperator = 67;
        appendComparison(buffer, descendingOperator, start.typeKind);
        buffer.append(" "); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" ");
        appendIrValue(buffer, source, IrValue(2, 0, 0, current, start.typeKind, start.typeName, start.typePointee));
        buffer.append(", ");
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val compared = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, compared); appendEquals(buffer);
        buffer.append("select i1 ");
        buffer.append("%"); appendDecimal(buffer, ascending);
        buffer.append(", i1 %");
        appendDecimal(buffer, ascendingCompared); buffer.append(",");
        buffer.append(" i1 ");
        buffer.append("%"); appendDecimal(buffer, descendingCompared);
        appendNewline(buffer);
        var conditionValue = IrValue(2, 0, 0, compared, TypeKind.Bool.value, 0, 0);
        if (collectionNode.aux != TokenKind.Range.value) {
            val nonempty = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, nonempty); appendEquals(buffer);
            buffer.append("and i1 %");
            appendDecimal(buffer, compared); buffer.append(",");
            buffer.append(" %");
            appendDecimal(buffer, different); appendNewline(buffer);
            conditionValue = IrValue(2, 0, 0, nonempty, TypeKind.Bool.value, 0, 0);
        }
        appendConditionalBranch(
            buffer, source, conditionValue, bodyBlock, endBlock);
        appendBlockLabel(buffer, counter, bodyBlock);
        val outerContinueBlock = counter.continueBlock;
        val outerBreakBlock = counter.breakBlock;
        val outerLoopDeferDepth = counter.loopDeferDepth;
        counter.continueBlock = incrementBlock;
        counter.breakBlock = endBlock;
        counter.loopDeferDepth = defers.length;
        val terminated = emitBlock(
            buffer, source, nodes, genericArguments, bodyRoot, counter, defers);
        counter.continueBlock = outerContinueBlock;
        counter.breakBlock = outerBreakBlock;
        counter.loopDeferDepth = outerLoopDeferDepth;
        if (!terminated) appendBranch(buffer, incrementBlock);
        appendBlockLabel(buffer, counter, incrementBlock);
        val loaded = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
        appendLoad(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer);
        if (collectionNode.aux == TokenKind.Range.value ||
            collectionNode.aux == TokenKind.RangeExclusiveStart.value) {
            val terminal = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, terminal); appendEquals(buffer);
            appendComparison(buffer, 79, start.typeKind); buffer.append(" ");
            appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
            buffer.append(" %");
            appendDecimal(buffer, loaded); buffer.append(",");
            buffer.append(" "); appendIrValue(buffer, source, finish);
            appendNewline(buffer);
            val advanceBlock = nextBlock(counter);
            appendConditionalBranch(
                buffer, source, IrValue(2, 0, 0, terminal, TypeKind.Bool.value, 0, 0),
                endBlock, advanceBlock);
            appendBlockLabel(buffer, counter, advanceBlock);
        }
        val advanced = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, advanced); appendEquals(buffer);
        appendOperator(buffer, 60, start.typeKind); buffer.append(" ");
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]); buffer.append(" ");
        appendIrValue(buffer, source, IrValue(2, 0, 0, loaded, start.typeKind, start.typeName, start.typePointee));
        buffer.append(", ");
        buffer.append("%"); appendDecimal(buffer, step);
        appendNewline(buffer);
        appendStore(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" ");
        appendIrValue(buffer, source, IrValue(2, 0, 0, advanced, start.typeKind, start.typeName, start.typePointee));
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer); appendBranch(buffer, conditionBlock);
        appendBlockLabel(buffer, counter, endBlock);
        return false;
    }
    if (statement.kind == AstKind.WhenStatement) {
        return emitWhen(
            buffer, source, nodes, genericArguments, root, counter, defers);
    }
    if (statement.kind == AstKind.VariableDeclaration) {
        val initializerRoot = root - 1;
        val initializerNode = nodes.data[initializerRoot];
        var initializer = IrValue(0, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
        if (initializerNode.kind == AstKind.Literal &&
            initializerNode.typeKind == TypeKind.String.value) {
            initializer = emitOwnedStringLiteral(
                buffer, source, initializerNode, counter);
        } else {
            initializer = emitExpression(
                buffer, source, nodes, genericArguments,
                initializerRoot, counter);
        }
        val name = nodes.data[statement.subtreeStart];
        var storageKind = initializer.typeKind;
        var storageName = initializer.typeName;
        var storagePointee = initializer.typePointee;
        val afterName = statement.subtreeStart + 1;
        if (afterName < nodes.data[initializerRoot].subtreeStart) {
            val declaredType =
                nodes.data[
                    nodes.data[initializerRoot].subtreeStart - 1];
            storageKind = declaredType.typeKind;
            storageName = declaredType.typeName;
            storagePointee = declaredType.typePointee;
        }
        initializer = emitImplicitIntegerWiden(
            buffer, source, genericArguments, initializer,
            storageKind, storageName, storagePointee, counter);
        appendStore(buffer);
        appendType(
            buffer, genericArguments, storageKind, storageName, storagePointee);
        buffer.append(" ");
        appendIrValue(buffer, source, initializer);
        appendPtr(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, name.start);
        appendNewline(buffer);
        if ((statement.ownership / 2) % 2 == 1) {
            appendStore(buffer); buffer.append("i1 ");
            buffer.append("true");
            appendPtr(buffer); appendDropFlagName(buffer, name.start);
            appendNewline(buffer);
            defers.add(root + 9223372036854775808);
        }
        return false;
    } else {
        if (statement.kind == AstKind.ReturnStatement) {
            if (statement.aux == 0) {
                emitDeferRange(
                    buffer, source, nodes, genericArguments,
                    counter, defers, defers.length, 0);
                buffer.append("  ret void");
            } else {
                val value = emitExpression(
                    buffer, source, nodes, genericArguments,
                    root - 1, counter);
                var returned = emitImplicitIntegerWiden(
                    buffer, source, genericArguments, value,
                    statement.typeKind, statement.typeName,
                    statement.typePointee, counter);
                if (statement.conversionKind != 0) {
                    val tagged = nextTemporary(counter);
                    appendValuePrefix(buffer);
                    appendDecimal(buffer, tagged);
                    appendEquals(buffer);
                    buffer.append("insertvalue ");
                    appendType(
                        buffer, genericArguments, statement.typeKind,
                        statement.typeName, statement.typePointee);
                    buffer.append(" undef, i1 ");
                    if (statement.conversionKind == 1) {
                        buffer.append("true");
                    } else {
                        buffer.append("false");
                    }
                    buffer.append(", 0");
                    appendNewline(buffer);
                    returned = IrValue(
                        2, 0, 0, tagged,
                        statement.typeKind,
                        statement.typeName, statement.typePointee);
                    if (statement.conversionKind == 1) {
                        val withPayload = nextTemporary(counter);
                        appendValuePrefix(buffer);
                        appendDecimal(buffer, withPayload);
                        appendEquals(buffer);
                        buffer.append("insertvalue ");
                        appendType(
                            buffer, genericArguments, statement.typeKind,
                            statement.typeName, statement.typePointee);
                        buffer.append(" ");
                        appendIrValue(buffer, source, returned);
                        buffer.append(", ");
                        appendType(
                            buffer, genericArguments, statement.typePointee,
                            statement.typeName, 0);
                        buffer.append(" ");
                        appendIrValue(buffer, source, value);
                        buffer.append(", ");
                        appendDecimal(buffer, 1);
                        appendNewline(buffer);
                        returned = IrValue(
                            2, 0, 0, withPayload,
                            statement.typeKind,
                            statement.typeName, statement.typePointee);
                    }
                }
                emitDeferRange(
                    buffer, source, nodes, genericArguments,
                    counter, defers, defers.length, 0);
                buffer.append("  ret ");
                appendType(
                    buffer, genericArguments, returned.typeKind,
                    returned.typeName, returned.typePointee);
                buffer.append(" ");
                appendIrValue(buffer, source, returned);
            }
            appendNewline(buffer);
            return true;
        } else {
            if (statement.kind == AstKind.ExpressionStatement) {
                emitExpression(
                    buffer, source, nodes, genericArguments,
                    root - 1, counter);
                return false;
            } else {
                if (statement.kind == AstKind.Block) {
                    return emitBlock(
                        buffer, source, nodes, genericArguments,
                        root, counter, defers);
                }
                if (statement.kind == AstKind.IfStatement) {
                    var elseRoot: u64 = 0;
                    var thenRoot = root - 1;
                    if (statement.aux == 1) {
                        elseRoot = thenRoot;
                        thenRoot = expressionChildBefore(nodes, elseRoot);
                    }
                    val conditionRoot =
                        expressionChildBefore(nodes, thenRoot);
                    val condition = emitExpression(
                        buffer, source, nodes, genericArguments,
                        conditionRoot, counter);
                    val thenBlock = nextBlock(counter);
                    val elseBlock = nextBlock(counter);
                    val endBlock = nextBlock(counter);
                    if (statement.aux == 1) {
                        appendConditionalBranch(
                            buffer, source, condition, thenBlock, elseBlock);
                    } else {
                        appendConditionalBranch(
                            buffer, source, condition, thenBlock, endBlock);
                    }
                    appendBlockLabel(buffer, counter, thenBlock);
                    val thenTerminated = emitBlock(
                        buffer, source, nodes, genericArguments,
                        thenRoot, counter, defers);
                    if (!thenTerminated) {
                        appendBranch(buffer, endBlock);
                    }
                    var elseTerminated = false;
                    if (statement.aux == 1) {
                        appendBlockLabel(buffer, counter, elseBlock);
                        elseTerminated = emitBlock(
                            buffer, source, nodes, genericArguments,
                            elseRoot, counter, defers);
                        if (!elseTerminated) {
                            appendBranch(buffer, endBlock);
                        }
                    }
                    if (!thenTerminated) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    if (statement.aux == 0) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    if (!elseTerminated) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    return true;
                }
                if (statement.kind == AstKind.WhileStatement) {
                    val bodyRoot = root - 1;
                    val conditionRoot =
                        expressionChildBefore(nodes, bodyRoot);
                    val conditionBlock = nextBlock(counter);
                    val bodyBlock = nextBlock(counter);
                    val endBlock = nextBlock(counter);
                    appendBranch(buffer, conditionBlock);
                    appendBlockLabel(buffer, counter, conditionBlock);
                    val condition = emitExpression(
                        buffer, source, nodes, genericArguments,
                        conditionRoot, counter);
                    appendConditionalBranch(
                        buffer, source, condition, bodyBlock, endBlock);
                    appendBlockLabel(buffer, counter, bodyBlock);
                    val outerContinueBlock = counter.continueBlock;
                    val outerBreakBlock = counter.breakBlock;
                    val outerLoopDeferDepth = counter.loopDeferDepth;
                    counter.continueBlock = conditionBlock;
                    counter.breakBlock = endBlock;
                    counter.loopDeferDepth = defers.length;
                    val bodyTerminated = emitBlock(
                        buffer, source, nodes, genericArguments,
                        bodyRoot, counter, defers);
                    counter.continueBlock = outerContinueBlock;
                    counter.breakBlock = outerBreakBlock;
                    counter.loopDeferDepth = outerLoopDeferDepth;
                    if (!bodyTerminated) {
                        appendBranch(buffer, conditionBlock);
                    }
                    appendBlockLabel(buffer, counter, endBlock);
                    return false;
                }
            }
        }
    }
    return false;
}

fn parameterRoot(
    val nodes: List<AstNode>, functionRoot: u64, position: u32): u64 {
    val function = nodes.data[functionRoot];
    var root = functionRoot - 1;
    if (!functionIsExtern(function)) {
        root = nodes.data[root].subtreeStart - 1;
    }
    val remaining = functionParameterCount(function);
    for (index in position - 1..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn returnTypeRoot(val nodes: List<AstNode>, functionRoot: u64): u64 {
    if (functionIsExtern(nodes.data[functionRoot])) {
        return functionRoot - 1;
    }
    return nodes.data[functionRoot - 1].subtreeStart - 1;
}

fn emitterTypeParameterRoot(
    val nodes: List<AstNode>, functionRoot: u64, position: u32): u64 {
    var root = returnTypeRoot(nodes, functionRoot);
    val parameters =
        functionParameterCount(nodes.data[functionRoot]);
    for (parameter in 0..<parameters) {
        root = nodes.data[root].subtreeStart - 1;
    }
    val remaining =
        functionTypeParameterCount(nodes.data[functionRoot]);
    for (index in position - 1..<remaining) {
        root = nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn emitterTypeParameterPosition(
    source: Source, val nodes: List<AstNode>,
    functionRoot: u64, name: u64): u32 {
    val count =
        functionTypeParameterCount(nodes.data[functionRoot]);
    for (position in 0..<count) {
        val root =
            emitterTypeParameterRoot(nodes, functionRoot, position + 1);
        val parameter = nodes.data[root];
        val nameNode = nodes.data[parameter.subtreeStart];
        if (sourceHash(source, nameNode.start, nameNode.end) == name) {
            return position;
        }
    }
    val function = nodes.data[functionRoot];
    if (function.conversionKind == 1) {
        if (functionParameterCount(function) > 0) {
            val receiverType = nodes.data[
                parameterRoot(nodes, functionRoot, 1) - 1];
            val ownerRoot = structRootByName(
                source, nodes,
                sourceHash(source, receiverType.start, receiverType.end));
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
    if (pattern.kind == TypeKind.Struct) {
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
            TypeKind.Struct, pattern.name,
            newStart as u32 + argumentCount * 65536);
    }
    if (pattern.kind == TypeKind.Nullable) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.Nullable, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.Pointer) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.Pointer, inner.name, inner.kind.value);
    }
    if (pattern.kind == TypeKind.Slice) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(typeKindFromValue(pattern.pointee), pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(TypeKind.Slice, inner.name, inner.kind.value);
    }
    if (pattern.kind != TypeKind.TypeParameter) return pattern;
    val position = emitterTypeParameterPosition(
        source, nodes, functionRoot, pattern.name);
    if (position >= count) return invalidType();
    return arguments.data[argumentStart + position as u64];
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
        if (statement.kind == AstKind.VariableDeclaration) {
            emitVariableAlloca(buffer, genericArguments, nodes, root);
        }
        if (statement.kind == AstKind.Block) {
            emitBlockAllocas(buffer, genericArguments, nodes, root);
        }
        if (statement.kind == AstKind.IfStatement) {
            var branchRoot = root - 1;
            if (statement.aux == 1) {
                emitBlockAllocas(buffer, genericArguments, nodes, branchRoot);
                branchRoot = expressionChildBefore(nodes, branchRoot);
            }
            emitBlockAllocas(buffer, genericArguments, nodes, branchRoot);
        }
        if (statement.kind == AstKind.WhileStatement) {
            emitBlockAllocas(buffer, genericArguments, nodes, root - 1);
        }
        if (statement.kind == AstKind.ForStatement) {
            val bodyRoot = root - 1;
            val collectionRoot = expressionChildBefore(nodes, bodyRoot);
            val name = nodes.data[statement.subtreeStart];
            val collection = nodes.data[collectionRoot];
            var range = collection.kind == AstKind.Binary;
            if (range) {
                range = collection.aux == TokenKind.Range.value;
                if (collection.aux == TokenKind.RangeExclusive.value) range = true;
                if (collection.aux == TokenKind.RangeExclusiveStart.value) range = true;
                if (collection.aux == TokenKind.RangeExclusiveBoth.value) range = true;
            }
            appendValuePrefix(buffer); appendLocalPrefix(buffer);
            appendDecimal(buffer, name.start); appendEquals(buffer);
            appendAlloca(buffer);
            if (range) {
                appendNodeType(buffer, genericArguments, collection);
            } else {
                var elementKind = collection.typePointee;
                if (collection.typeKind == TypeKind.Array.value) {
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
        if (statement.kind == AstKind.WhenStatement) {
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
    val parameterCount = functionParameterCount(function);
    if (functionIsExtern(function)) {
        buffer.append("declare ");
    } else {
        appendDefine(buffer);
    }
    if (functionInfersReturn(function)) {
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
        if (parameter.aux == 2) {
            appendType(buffer, genericArguments, 9, 0, parameterType.typeKind);
        } else {
            appendNodeType(buffer, genericArguments, parameterType);
        }
        buffer.append(" %");
        if (parameter.aux != 2) {
            buffer.append("arg.");
        } else {
            appendLocalPrefix(buffer);
        }
        if (parameter.aux == 2) {
            appendDecimal(buffer, parameterName.start);
        } else {
            appendSource(
                buffer, source, parameterName.start, parameterName.end);
        }
    }
    buffer.append(")");
    if (functionIsExtern(function)) {
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
        if (parameter.aux != 2) {
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
        var returnsUnit = returnType.typeKind == TypeKind.Unit.value;
        if (returnType.kind == AstKind.NamedType &&
            returnType.aux == TokenKind.KwUnit.value) returnsUnit = true;
        if (functionInfersReturn(function) && function.typeKind == TypeKind.Unit.value)
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
        if (node.typeKind == TypeKind.TypeParameter.value || node.typeKind == TypeKind.Struct.value ||
                node.typeKind == TypeKind.Pointer.value || node.typeKind == TypeKind.Slice.value ||
                node.typeKind == TypeKind.Nullable.value) {
            val concrete = substituteEmitterType(
                source, nodes, functionRoot,
                TypeValue(
                    typeKindFromValue(node.typeKind), node.typeName, node.typePointee),
                genericArguments, argumentStart, argumentCount);
            node.typeKind = concrete.kind.value;
            node.typeName = concrete.name;
            node.typePointee = concrete.pointee;
        }
        if (node.kind == AstKind.Call) {
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
    val argumentCount = call.aux % 65536;
    for (argument in 0..<argumentCount) {
        cursor = expressionChildBefore(nodes, cursor);
    }
    val explicitTypeCount = call.aux / 65536;
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
    if (functionParameterCount(function) != 0) return false;
    if (functionTypeParameterCount(function) != 0) return false;
    val returnTypeRoot = nodes.data[functionRoot - 1].subtreeStart - 1;
    if (nodes.data[returnTypeRoot].aux != TokenKind.KwI32.value) return false;
    val name = nodes.data[function.subtreeStart];
    val blockRoot = functionRoot - 1;
    if (nodes.data[blockRoot].aux != 1) return false;
    val statementRoot = firstStatementRoot(nodes, blockRoot);
    val statement = nodes.data[statementRoot];
    if (statement.kind != AstKind.ReturnStatement) return false;
    if (statement.aux != 1) return false;
    val literal = nodes.data[statementRoot - 1];
    if (literal.kind != AstKind.Literal) return false;
    if (literal.aux != TokenKind.IntegerLiteral.value) return false;

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
        buffer, sourceHash(source, name.start, name.end));
    appendEquals(buffer);
    buffer.append("type {");
    val fieldCount = structFieldCount(structure);
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
        if (arguments.data[start + index as u64].kind == TypeKind.TypeParameter) {
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
        buffer, sourceHash(source, name.start, name.end));
    appendStructSpecializationSuffix(buffer, genericArguments, argumentStart, argumentCount);
    appendEquals(buffer);
    buffer.append("type {");
    val fieldCount = structFieldCount(structure);
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
            !typeEquals(
                arguments.data[leftStart + index as u64],
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
                call.genericArgumentStart + index as u64].kind == TypeKind.TypeParameter) {
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
        if (literal.kind == AstKind.Literal &&
            literal.aux == TokenKind.StringLiteral.value &&
            (literal.typeKind == TypeKind.String.value || literal.typeKind == TypeKind.Slice.value))
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
        if (nodes.data[root].kind == AstKind.StructDeclaration) {
            if (structTypeParameterCount(nodes.data[root]) == 0) {
                emitStruct(buffer, source, nodes, genericArguments, root);
            }
        }
    }
    
    var structRequests = List<StructSpecializationRequest>.new();
    defer structRequests.free();
    for (nodeIndex in 0..<nodes.length) {
        val node = nodes.data[nodeIndex];
        if (node.typeKind == TypeKind.Struct.value) {
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
        if (nodes.data[root].kind == AstKind.FunctionOrDefer) {
            if (functionTypeParameterCount(nodes.data[root]) == 0) {
                emitFunction(
                    buffer, source, nodes, genericArguments,
                    root, 0, 0);
            }
        } else {
            if (nodes.data[root].kind == AstKind.StructDeclaration) {
                var methodRoot = root - 1;
                val methods = emitterStructMethodCount(nodes.data[root]);
                for (method in 0..<methods) {
                    if (emitterStructTypeParameterCount(
                            nodes.data[root]) == 0) {
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
        if (call.kind == AstKind.Call) {
            if (callArgumentsAreConcrete(call, genericArguments)) {
                val calleeRoot = callCalleeRoot(nodes, callIndex);
                val callee = nodes.data[calleeRoot];
                var functionRoot =
                    functionRootByName(
                        source, nodes,
                        sourceHash(
                            source, callee.start, callee.end));
                if (callee.kind == AstKind.Member) functionRoot = call.storage;
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
            if (nestedCall.kind == AstKind.Call) {
            if (nestedCall.genericArgumentCount > 0) {
                val calleeRoot =
                    callCalleeRoot(nodes, nestedIndex);
                val callee = nodes.data[calleeRoot];
                var nestedFunctionRoot =
                    functionRootByName(
                        source, nodes,
                        sourceHash(
                            source, callee.start, callee.end));
                if (callee.kind == AstKind.Member)
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
