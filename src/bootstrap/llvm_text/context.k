module bootstrap.llvm_text.context;

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

enum IrValueKind: u32 {
    Invalid = 0,
    SourceLiteral = 1,
    Temporary = 2,
    ImmediateConstant = 3,
    LocalAddress = 4,
    ZeroInitializer = 5
}

struct IrValue(
    kind: IrValueKind, start: u64, end: u64, temporary: u64,
    typeKind: u32, typeName: u64, typePointee: u32)
struct IrCounter(
    value: u64,
    block: u64,
    currentBlock: u64,
    continueBlock: u64,
    breakBlock: u64,
    loopDeferDepth: u64)

fn appendIrValue(
    var buffer: StringBuilder, source: Source, value: IrValue) {
    if (value.kind == IrValueKind.SourceLiteral) {
        appendSource(buffer, source, value.start, value.end);
    } else {
        if (value.kind == IrValueKind.LocalAddress) {
            buffer.append("%");
            appendLocalPrefix(buffer);
            appendDecimal(buffer, value.temporary);
            return;
        }
        if (value.kind == IrValueKind.ImmediateConstant) {
            appendDecimal(buffer, value.temporary);
            return;
        }
        if (value.kind == IrValueKind.ZeroInitializer) {
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
    if (value.kind == IrValueKind.SourceLiteral) {
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
        IrValueKind.Temporary, 0, 0, temporary, targetKind, targetName, targetPointee);
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


fn expressionChildBefore(val nodes: List<AstNode>, root: u64) =>
    nodes.data[root].subtreeStart - 1;

