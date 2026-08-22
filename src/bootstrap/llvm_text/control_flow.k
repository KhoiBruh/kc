module bootstrap.llvm_text.control_flow;

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
    var data = IrValue(IrValueKind.INVALID, 0, 0, 0, TypeKind.POINTER.value, elementName, elementKind);
    var length = IrValue(IrValueKind.IMMEDIATE_CONSTANT, 0, 0, 0, TypeKind.U64.value, 0, 0);
    if (collectionNode.typeKind == TypeKind.ARRAY.value) {
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
        data = IrValue(IrValueKind.TEMPORARY, 0, 0, pointer, TypeKind.POINTER.value, elementName, elementKind);
        length = IrValue(
            IrValueKind.IMMEDIATE_CONSTANT, 0, 0, (collectionNode.typePointee / 256) as u64,
            7, 0, 0);
    } else {
        val dataTemporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary);
        appendEquals(buffer); appendExtractValue(buffer);
        appendNodeType(buffer, genericArguments, collectionNode);
        buffer.append(" "); appendIrValue(buffer, source, collectionValue);
        buffer.append(", 0");
        appendNewline(buffer);
        data = IrValue(IrValueKind.TEMPORARY, 0, 0, dataTemporary, TypeKind.POINTER.value, elementName, elementKind);
        val lengthTemporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary);
        appendEquals(buffer); appendExtractValue(buffer);
        appendNodeType(buffer, genericArguments, collectionNode);
        buffer.append(" "); appendIrValue(buffer, source, collectionValue);
        buffer.append(", 1");
        appendNewline(buffer);
        length = IrValue(IrValueKind.TEMPORARY, 0, 0, lengthTemporary, TypeKind.U64.value, 0, 0);
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
    appendIrValue(buffer, source, IrValue(IrValueKind.TEMPORARY, 0, 0, index, TypeKind.U64.value, 0, 0));
    buffer.append(", ");
    appendIrValue(buffer, source, length); appendNewline(buffer);
    appendConditionalBranch(
        buffer, source, IrValue(IrValueKind.TEMPORARY, 0, 0, compared, TypeKind.BOOL.value, 0, 0),
        bodyBlock, endBlock);
    appendBlockLabel(buffer, counter, bodyBlock);
    val elementPointer = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, elementPointer); appendEquals(buffer);
    appendGetElementPtr(buffer); buffer.append(" ");
    appendType(buffer, genericArguments, elementKind, elementName, 0);
    appendPointerValue(buffer, source, data);
    buffer.append(", "); appendI64(buffer);
    buffer.append(" ");
    appendIrValue(buffer, source, IrValue(IrValueKind.TEMPORARY, 0, 0, index, TypeKind.U64.value, 0, 0));
    appendNewline(buffer);
    val element = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, element); appendEquals(buffer);
    appendLoad(buffer); appendType(buffer, genericArguments, elementKind, elementName, 0);
    appendPointerValue(
        buffer, source,
        IrValue(IrValueKind.TEMPORARY, 0, 0, elementPointer, TypeKind.POINTER.value, elementName, elementKind));
    appendNewline(buffer);
    appendStore(buffer); appendType(buffer, genericArguments, elementKind, elementName, 0);
    buffer.append(" ");
    appendIrValue(buffer, source, IrValue(IrValueKind.TEMPORARY, 0, 0, element, elementKind, elementName, 0));
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
    appendIrValue(buffer, source, IrValue(IrValueKind.TEMPORARY, 0, 0, loaded, TypeKind.U64.value, 0, 0));
    buffer.append(", 1");
    appendNewline(buffer);
    appendStore(buffer); appendI64(buffer); buffer.append(" ");
    appendIrValue(buffer, source, IrValue(IrValueKind.TEMPORARY, 0, 0, advanced, TypeKind.U64.value, 0, 0));
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
    val branchCount = statement.whenBranchCount();
    val hasSubject = if (statement.whenHasSubject()) 1 else 0;
    val roots =
        k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
    var branchRoot = root - 1;
    for (index in branchCount>..0) {
        roots[index as u64] = branchRoot;
        branchRoot = nodes.data[branchRoot].subtreeStart - 1;
    }
    var subject = IrValue(IrValueKind.INVALID, 0, 0, 0, TypeKind.INVALID.value, 0, 0);
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
        if (!branch.whenBranchIsElse()) {
            var nextBlockValue = mergeBlock;
            if (index + 1 < branchCount) {
                nextBlockValue = nextBlock(counter);
            }
            val patternCount = branch.whenBranchPatternCount();
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
                    condition = IrValue(IrValueKind.TEMPORARY, 0, 0, compared, TypeKind.BOOL.value, 0, 0);
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
    if (!hasElse && allTerminate && subject.typeKind == TypeKind.ENUM.value) {
        appendUnreachable(buffer); appendNewline(buffer);
        return true;
    }
    return false;
}

