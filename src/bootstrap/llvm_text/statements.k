module bootstrap.llvm_text.statements;

import bootstrap.*;
import bootstrap.token.TokenKind;

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
        buffer, source, IrValue(IrValueKind.Temporary, 0, 0, live, TypeKind.Bool.value, 0, 0),
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
                IrValueKind.Temporary, 0, 0, shifted, start.typeKind, start.typeName, start.typePointee);
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
        appendIrValue(buffer, source, IrValue(IrValueKind.Temporary, 0, 0, current, start.typeKind, start.typeName, start.typePointee));
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
        appendIrValue(buffer, source, IrValue(IrValueKind.Temporary, 0, 0, current, start.typeKind, start.typeName, start.typePointee));
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
        var conditionValue = IrValue(IrValueKind.Temporary, 0, 0, compared, TypeKind.Bool.value, 0, 0);
        if (collectionNode.aux != TokenKind.Range.value) {
            val nonempty = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, nonempty); appendEquals(buffer);
            buffer.append("and i1 %");
            appendDecimal(buffer, compared); buffer.append(",");
            buffer.append(" %");
            appendDecimal(buffer, different); appendNewline(buffer);
            conditionValue = IrValue(IrValueKind.Temporary, 0, 0, nonempty, TypeKind.Bool.value, 0, 0);
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
                buffer, source, IrValue(IrValueKind.Temporary, 0, 0, terminal, TypeKind.Bool.value, 0, 0),
                endBlock, advanceBlock);
            appendBlockLabel(buffer, counter, advanceBlock);
        }
        val advanced = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, advanced); appendEquals(buffer);
        appendOperator(buffer, 60, start.typeKind); buffer.append(" ");
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]); buffer.append(" ");
        appendIrValue(buffer, source, IrValue(IrValueKind.Temporary, 0, 0, loaded, start.typeKind, start.typeName, start.typePointee));
        buffer.append(", ");
        buffer.append("%"); appendDecimal(buffer, step);
        appendNewline(buffer);
        appendStore(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        buffer.append(" ");
        appendIrValue(buffer, source, IrValue(IrValueKind.Temporary, 0, 0, advanced, start.typeKind, start.typeName, start.typePointee));
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
        var initializer = IrValue(IrValueKind.Invalid, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
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
                        IrValueKind.Temporary, 0, 0, tagged,
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
                            IrValueKind.Temporary, 0, 0, withPayload,
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

