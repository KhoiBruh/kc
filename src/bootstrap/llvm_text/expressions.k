module bootstrap.llvm_text.expressions;

import bootstrap.*;
import bootstrap.token.TokenKind;

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
            IrValueKind.LocalAddress, node.start, node.end, node.storage,
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
            IrValueKind.Temporary, 0, 0, temporary, TypeKind.Pointer.value,
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
            data = IrValue(IrValueKind.Temporary, 0, 0, extracted, TypeKind.Pointer.value, 0, TypeKind.U8.value);
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
            IrValueKind.Temporary, 0, 0, temporary, TypeKind.Pointer.value,
            node.typeName, node.typeKind);
    }
    return IrValue(IrValueKind.Invalid, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
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
            return IrValue(IrValueKind.ImmediateConstant, 0, 0, 0, TypeKind.NullLiteral.value, 0, 0);
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
            return IrValue(IrValueKind.Temporary, 0, 0, temporary, TypeKind.Slice.value, 0, TypeKind.U8.value);
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
            return IrValue(IrValueKind.Temporary, 0, 0, temporary, TypeKind.String.value, 0, 0);
        }
        return IrValue(
            IrValueKind.SourceLiteral, node.start, node.end, 0,
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
            IrValueKind.Temporary, 0, 0, temporary,
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
        var subject = IrValue(IrValueKind.Invalid, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
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
                        condition = IrValue(IrValueKind.Temporary, 0, 0, compared, TypeKind.Bool.value, 0, 0);
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
            IrValueKind.Temporary, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.ArrayLiteral) {
        if (node.aux == 0) {
            return IrValue(
                IrValueKind.ZeroInitializer, 0, 0, 0,
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
            IrValueKind.ImmediateConstant, 0, 0, 0, node.typeKind, node.typeName, node.typePointee);
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
                IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, temporary,
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
            IrValueKind.Temporary, 0, 0, temporary,
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
            return IrValue(IrValueKind.Temporary, 0, 0, result, TypeKind.Bool.value, 0, 0);
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
            return IrValue(IrValueKind.Temporary, 0, 0, temporary, TypeKind.Bool.value, 0, 0);
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
            IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, updated, targetNode.typeKind,
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
                    buffer, source, IrValue(IrValueKind.Temporary, 0, 0, check, TypeKind.Bool.value, 0, 0),
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
                IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, temporary,
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
                buffer, source, IrValue(IrValueKind.Temporary, 0, 0, check, TypeKind.Bool.value, 0, 0),
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
                    IrValueKind.ImmediateConstant, 0, 0, node.storage, TypeKind.Enum.value,
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
            return IrValue(IrValueKind.Temporary, 0, 0, slice, TypeKind.Slice.value, 0, TypeKind.U8.value);
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
                IrValueKind.Temporary, 0, 0, extracted,
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
            IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, temporary,
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
            IrValueKind.Temporary, 0, 0, temporary,
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
                IrValueKind.Temporary, 0, 0, updated,
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
            IrValue(IrValueKind.Temporary, 0, 0, hasValue, TypeKind.Bool.value, 0, 0),
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
            IrValueKind.Temporary, 0, 0, value,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == AstKind.Sizeof) {
        val typeNode = nodes.data[root - 1];
        return IrValue(
            IrValueKind.ImmediateConstant, 0, 0,
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
                if (parameterMode(parameter) == ParameterMode.MutableBorrow)
                    byReference = true;
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
                    if (parameterMode(ownedParameter) == ParameterMode.Owned)
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
                IrValueKind.Temporary, 0, 0, lengthTemporary,
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
                IrValueKind.Temporary, 0, 0, aggregateTemporary,
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
            return IrValue(IrValueKind.ImmediateConstant, 0, 0, 0, TypeKind.Unit.value, 0, 0);
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
                if (parameterMode(callParameter) == ParameterMode.MutableBorrow) {
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
        if (isPrint) return IrValue(IrValueKind.ImmediateConstant, 0, 0, 0, TypeKind.Unit.value, 0, 0);
        if (node.typeKind == TypeKind.Unit.value) {
            return IrValue(IrValueKind.ImmediateConstant, 0, 0, 0, TypeKind.Unit.value, 0, 0);
        }
        return IrValue(
            IrValueKind.Temporary, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    return IrValue(IrValueKind.Invalid, 0, 0, 0, TypeKind.Invalid.value, 0, 0);
}

