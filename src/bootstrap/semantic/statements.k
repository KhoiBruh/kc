module bootstrap.semantic.statements;

import bootstrap.*;
import bootstrap.token.TokenKind;

fn checkBlock(var semantic: Semantic, root: u64) {
    if (semantic.nodes.data[root].kind != AstKind.Block) {
        checkStatement(semantic, root);
        return;
    }
    val savedLocals = semantic.locals.length;
    val savedScopeStart = semantic.scopeStart;
    semantic.scopeStart = savedLocals;
    val block = semantic.nodes.data[root];
    val roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var statementRoot = root - 1;
    for (index in block.aux>..0) {
        roots[index as u64] = statementRoot;
        statementRoot =
            semantic.nodes.data[statementRoot].subtreeStart - 1;
    }
    for (index in 0..<block.aux) {
        checkStatement(semantic, roots[index as u64]);
    }
    k_boot_free(roots as unit*);
    semantic.locals.setLength(savedLocals);
    semantic.scopeStart = savedScopeStart;
}

fn statementTerminates(val nodes: List<AstNode>, root: u64): bool {
    val node = nodes.data[root];
    if (node.kind == AstKind.ReturnStatement ||
        node.kind == AstKind.BreakStatement ||
        node.kind == AstKind.ContinueStatement) return true;
    if (node.kind == AstKind.Block) {
        if (node.aux == 0) return false;
        return statementTerminates(nodes, root - 1);
    }
    if (node.kind == AstKind.IfStatement && node.aux == 1) {
        val elseRoot = root - 1;
        val thenRoot = nodes.data[elseRoot].subtreeStart - 1;
        return statementTerminates(nodes, thenRoot) &&
            statementTerminates(nodes, elseRoot);
    }
    return false;
}

fn checkStatement(var semantic: Semantic, root: u64) {
    if (!semantic.result.ok) return;
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.Block) {
        checkBlock(semantic, root);
        return;
    }
    if (node.kind == AstKind.IfStatement) {
        var thenRoot = root - 1;
        var elseRoot = semantic.nodes.length;
        if (node.aux == 1) {
            elseRoot = thenRoot;
            thenRoot = semantic.nodes.data[elseRoot].subtreeStart - 1;
        }
        val conditionRoot =
            semantic.nodes.data[thenRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != TypeKind.Bool) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        val count = semantic.locals.length;
        val before = captureOwnership(semantic, count);
        checkBlock(semantic, thenRoot);
        val thenTerminates = statementTerminates(semantic.nodes, thenRoot);
        val thenState = captureOwnership(semantic, count);
        restoreOwnership(semantic, before, count);
        if (elseRoot != semantic.nodes.length) checkBlock(semantic, elseRoot);
        var elseTerminates = false;
        if (elseRoot != semantic.nodes.length)
            elseTerminates = statementTerminates(semantic.nodes, elseRoot);
        val elseState = captureOwnership(semantic, count);
        if (thenTerminates && !elseTerminates)
            restoreOwnership(semantic, elseState, count);
        else if (elseTerminates && !thenTerminates)
            restoreOwnership(semantic, thenState, count);
        else
            mergeOwnership(semantic, thenState, elseState, count);
        k_boot_free(elseState as unit*);
        k_boot_free(thenState as unit*);
        k_boot_free(before as unit*);
        return;
    }
    if (node.kind == AstKind.WhileStatement) {
        val bodyRoot = root - 1;
        semantic.loopDepth++;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth--;
        val conditionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != TypeKind.Bool) {
            semanticFail(
                semantic, 6, semantic.nodes.data[conditionRoot]);
        }
        return;
    }
    if (node.kind == AstKind.ForStatement) {
        val bodyRoot = root - 1;
        val collectionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        var collectionNode = semantic.nodes.data[collectionRoot];
        var valueType = expressionType(semantic, collectionRoot);
        var range = collectionNode.kind == AstKind.Binary;
        if (range) {
            range = collectionNode.aux == TokenKind.Range.value;
            if (collectionNode.aux == TokenKind.RangeExclusive.value) range = true;
            if (collectionNode.aux == TokenKind.RangeExclusiveStart.value) range = true;
            if (collectionNode.aux == TokenKind.RangeExclusiveBoth.value) range = true;
        }
        if (range) {
            if (node.aux == 1) {
                semanticFail(
                    semantic, 4,
                    semantic.nodes.data[node.subtreeStart + 1]);
                return;
            }
        } else {
            var collection = valueType.kind == TypeKind.Slice;
            if (valueType.kind == TypeKind.Array) collection = true;
            if (!collection) {
                semanticFail(semantic, 4, collectionNode);
                return;
            }
            if (valueType.kind == TypeKind.Slice) {
                valueType = TypeValue(
                    typeKindFromValue(valueType.pointee), valueType.name, 0);
            } else {
                valueType = valueType.arrayElement();
            }
        }
        if (valueType.kind == TypeKind.IntegerLiteral) {
            valueType = TypeValue(TypeKind.I32, 0, 0);
            collectionNode.typeKind = TypeKind.I32.value;
            semantic.nodes.data[collectionRoot] = collectionNode;
            val rightRoot = collectionRoot - 1;
            val leftRoot =
                semantic.nodes.data[rightRoot].subtreeStart - 1;
            var rightNode = semantic.nodes.data[rightRoot];
            var leftNode = semantic.nodes.data[leftRoot];
            rightNode.typeKind = TypeKind.I32.value;
            leftNode.typeKind = TypeKind.I32.value;
            semantic.nodes.data[rightRoot] = rightNode;
            semantic.nodes.data[leftRoot] = leftNode;
        }
        if (range) {
            if (!valueType.isInteger()) {
                semanticFail(semantic, 4, collectionNode);
                return;
            }
        }
        val savedLocals = semantic.locals.length;
        val nameNode = semantic.nodes.data[node.subtreeStart];
        semantic.locals.add(LocalInfo(
            nodeHash(semantic, nameNode), valueType, false, nameNode.start,
            false, false));
        if (node.aux == 1) {
            val indexNode = semantic.nodes.data[node.subtreeStart + 1];
            semantic.locals.add(
                LocalInfo(
                    nodeHash(semantic, indexNode),
                    TypeValue(TypeKind.U64, 0, 0), false, indexNode.start, false, false
				)
			);
        }
        semantic.loopDepth++;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth--;
        semantic.locals.setLength(savedLocals);
        return;
    }
    if (node.kind == AstKind.WhenStatement) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        if (branchCount == 0) {
            semanticFail(semantic, 4, node);
            return;
        }
        val roots =
            k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        for (index in branchCount>..0) {
            roots[index as u64] = branchRoot;
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        var subject = invalidType();
        if (hasSubject == 1) {
            val subjectRoot = branchRoot;
            subject = expressionType(semantic, subjectRoot);
            if (subject.kind == TypeKind.IntegerLiteral) {
                subject = TypeValue(TypeKind.I32, 0, 0);
                var subjectNode = semantic.nodes.data[subjectRoot];
                subjectNode.typeKind = TypeKind.I32.value;
                semantic.nodes.data[subjectRoot] = subjectNode;
            }
            var comparable = subject.kind == TypeKind.Bool;
            if (subject.isInteger()) comparable = true;
            if (subject.kind == TypeKind.Enum) comparable = true;
            if (!comparable) {
                semanticFail(semantic, 6, semantic.nodes.data[subjectRoot]);
            }
        }
        var hasElse = false;
        val ownershipCount = semantic.locals.length;
        val ownershipBefore = captureOwnership(semantic, ownershipCount);
        val ownershipMerged = k_boot_alloc(ownershipCount) as u8*;
        for (ownershipIndex in 0..<ownershipCount) {
            ownershipMerged[ownershipIndex] = 0 as u8;
        }
        for (index in 0..<branchCount) {
            restoreOwnership(semantic, ownershipBefore, ownershipCount);
            val current = semantic.nodes.data[roots[index as u64]];
            if (current.aux % 2 == 1) hasElse = true;
            val bodyRoot = roots[index as u64] - 1;
            if (current.aux % 2 == 0) {
              val patternCount = current.aux / 65536;
              for (patternIndex in 0..<patternCount) {
                val conditionRoot = whenPatternRoot(
                    semantic, roots[index as u64], false, patternIndex);
                val condition = expressionType(semantic, conditionRoot);
                if (hasSubject == 1) {
                    if (
                        !typeAccepts(
                            subject, condition,
                            semantic.genericArguments
                        )
                    ) {
                        semanticFail(
                            semantic, 4,
                            semantic.nodes.data[conditionRoot]);
                    } else {
                        var conditionNode = semantic.nodes.data[conditionRoot];
                        conditionNode.typeKind = subject.kind.value;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != TypeKind.Bool) {
                        semanticFail(
                            semantic, 6,
                            semantic.nodes.data[conditionRoot]);
                    }
                }
              }
            }
            checkBlock(semantic, bodyRoot);
            includeCurrentOwnership(
                semantic, ownershipMerged, ownershipCount);
        }
        restoreOwnership(semantic, ownershipMerged, ownershipCount);
        k_boot_free(ownershipMerged as unit*);
        k_boot_free(ownershipBefore as unit*);
        val exhaustive = enumWhenExhaustive(
            semantic, subject, roots, branchCount, false);
        if (subject.kind == TypeKind.Enum && !hasElse && !exhaustive) {
            semanticFail(semantic, 4, node);
        }
        k_boot_free(roots as unit*);
        return;
    }
    if (node.kind == AstKind.FunctionOrDefer) {
        val savedSuppressMoves = semantic.suppressMoves;
        semantic.suppressMoves = true;
        checkStatement(semantic, root - 1);
        semantic.suppressMoves = savedSuppressMoves;
        return;
    }
    if (node.kind == AstKind.BreakStatement) {
        if (semantic.loopDepth == 0) {
            semanticFail(semantic, 4, node);
        }
        return;
    }
    if (node.kind == AstKind.ContinueStatement) {
        if (semantic.loopDepth == 0) {
            semanticFail(semantic, 4, node);
        }
        return;
    }
    if (node.kind == AstKind.VariableDeclaration) {
        val initializerRoot = root - 1;
        var initializer = expressionType(semantic, initializerRoot);
        val nameNode = semantic.nodes.data[node.subtreeStart];
        val name = nodeHash(semantic, nameNode);
        if (localFindFrom(semantic.locals, name, semantic.scopeStart) !=
                semantic.locals.length) {
            semanticFail(semantic, 1, nameNode);
            return;
        }
        var valueType = initializer;
        if (valueType.kind == TypeKind.IntegerLiteral) {
            valueType = TypeValue(TypeKind.I32, 0, 0);
            var initializerNode = semantic.nodes.data[initializerRoot];
            initializerNode.typeKind = TypeKind.I32.value;
            semantic.nodes.data[initializerRoot] = initializerNode;
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
        }
        val afterName = node.subtreeStart + 1;
        if (afterName < semantic.nodes.data[initializerRoot].subtreeStart) {
            valueType = typeFromNode(
                semantic,
                semantic.nodes.data[initializerRoot].subtreeStart - 1);
            initializer = contextualizeLiteralByteSlice(
                semantic, initializerRoot, valueType, initializer);
            if (!typeAccepts(valueType, initializer, semantic.genericArguments)) {
                semanticFail(
                    semantic, 4, semantic.nodes.data[initializerRoot]);
            }
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
            if (initializer.kind == TypeKind.Array) {
                if (initializer.arrayElement().kind == TypeKind.Invalid) {
                    var initializerNode = semantic.nodes.data[initializerRoot];
                    initializerNode.typeKind = valueType.kind.value;
                    initializerNode.typeName = valueType.name;
                    initializerNode.typePointee = valueType.pointee;
                    semantic.nodes.data[initializerRoot] = initializerNode;
                }
            }
        }
        markExpressionMoved(semantic, initializerRoot);
        val automaticDrop =
            (valueType.kind == TypeKind.Struct || valueType.kind == TypeKind.String) &&
            typeNeedsOwnership(semantic, valueType);
        var declarationNode = semantic.nodes.data[root];
        if (automaticDrop) declarationNode.ownership = 2;
        semantic.nodes.data[root] = declarationNode;
        semantic.locals.add(LocalInfo(
            name, valueType, node.aux == TokenKind.KwVar.value, nameNode.start,
            false, automaticDrop));
        return;
    }
    if (node.kind == AstKind.ReturnStatement) {
        var actual = unitType();
        if (node.aux == 1) {
            actual = expressionType(semantic, root - 1);
            actual = contextualizeLiteralByteSlice(
                semantic, root - 1, semantic.returnType, actual);
        }
        val function = semantic.nodes.data[semantic.currentFunction];
        if (function.storage % 2 == 1 && node.aux == 1) {
            var statementLike = actual.kind == TypeKind.Unit;
            if (semantic.nodes.data[root - 1].kind == AstKind.Assignment)
                statementLike = true;
            if (statementLike) {
                if (semantic.returnType.kind != TypeKind.Unit)
                    semanticFail(semantic, 5, semantic.nodes.data[root - 1]);
                else {
                    var expressionStatement = node;
                    expressionStatement.kind = AstKind.ExpressionStatement;
                    semantic.nodes.data[root] = expressionStatement;
                }
                return;
            }
        }
        if (!typeAccepts(semantic.returnType, actual, semantic.genericArguments)) {
            if (node.aux == 1) {
                semanticFail(
                    semantic, 5, semantic.nodes.data[root - 1]);
            } else {
                semanticFail(semantic, 5, node);
            }
        } else {
            if (node.aux == 1) {
                var returnNode = semantic.nodes.data[root];
                returnNode.typeKind = semantic.returnType.kind.value;
                returnNode.typeName = semantic.returnType.name;
                returnNode.typePointee = semantic.returnType.pointee;
                if (semantic.returnType.kind == TypeKind.Nullable) {
                    if (actual.kind == TypeKind.NullLiteral) {
                        returnNode.conversionKind = 2;
                    } else {
                        if (actual.kind != TypeKind.Nullable) {
                            returnNode.conversionKind = 1;
                        }
                    }
                }
                semantic.nodes.data[root] = returnNode;
                var valueNode = semantic.nodes.data[root - 1];
                if (valueNode.typeKind == TypeKind.IntegerLiteral.value) {
                    valueNode.typeKind = semantic.returnType.kind.value;
                    valueNode.typeName = semantic.returnType.name;
                    valueNode.typePointee = semantic.returnType.pointee;
                    semantic.nodes.data[root - 1] = valueNode;
                }
                resolveWhenResultType(
                    semantic, root - 1, semantic.returnType);
                resolveIfResultType(
                    semantic, root - 1, semantic.returnType);
                markExpressionMoved(semantic, root - 1);
            }
        }
        return;
    }
    if (node.kind == AstKind.ExpressionStatement) {
        val previousMutationRoot = semantic.mutationRoot;
        semantic.mutationRoot = root - 1;
        expressionType(semantic, root - 1);
        semantic.mutationRoot = previousMutationRoot;
    }
}
