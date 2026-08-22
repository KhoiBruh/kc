module bootstrap.semantic.statements;

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

fn checkBlock(var semantic: Semantic, root: u64) {
    if (semantic.nodes.data[root].kind != AstKind.BLOCK) {
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
    if (node.kind == AstKind.RETURN_STATEMENT ||
        node.kind == AstKind.BREAK_STATEMENT ||
        node.kind == AstKind.CONTINUE_STATEMENT) return true;
    if (node.kind == AstKind.BLOCK) {
        if (node.aux == 0) return false;
        return statementTerminates(nodes, root - 1);
    }
    if (node.kind == AstKind.IF_STATEMENT && node.aux == 1) {
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
    if (node.kind == AstKind.BLOCK) {
        checkBlock(semantic, root);
        return;
    }
    if (node.kind == AstKind.IF_STATEMENT) {
        var thenRoot = root - 1;
        var elseRoot = semantic.nodes.length;
        if (node.aux == 1) {
            elseRoot = thenRoot;
            thenRoot = semantic.nodes.data[elseRoot].subtreeStart - 1;
        }
        val conditionRoot =
            semantic.nodes.data[thenRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != TypeKind.BOOL) {
            semantic.fail(
                6, semantic.nodes.data[conditionRoot]);
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
    if (node.kind == AstKind.WHILE_STATEMENT) {
        val bodyRoot = root - 1;
        semantic.loopDepth++;
        checkBlock(semantic, bodyRoot);
        semantic.loopDepth--;
        val conditionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        if (expressionType(semantic, conditionRoot).kind != TypeKind.BOOL) {
            semantic.fail(
                6, semantic.nodes.data[conditionRoot]);
        }
        return;
    }
    if (node.kind == AstKind.FOR_STATEMENT) {
        val bodyRoot = root - 1;
        val collectionRoot =
            semantic.nodes.data[bodyRoot].subtreeStart - 1;
        var collectionNode = semantic.nodes.data[collectionRoot];
        var valueType = expressionType(semantic, collectionRoot);
        var range = collectionNode.kind == AstKind.BINARY;
        if (range) {
            range = collectionNode.aux == TokenKind.RANGE.value;
            if (collectionNode.aux == TokenKind.RANGE_EXCLUSIVE.value) range = true;
            if (collectionNode.aux == TokenKind.RANGE_EXCLUSIVE_START.value) range = true;
            if (collectionNode.aux == TokenKind.RANGE_EXCLUSIVE_BOTH.value) range = true;
        }
        if (range) {
            if (node.aux == 1) {
                semantic.fail(
                    4,
                    semantic.nodes.data[node.subtreeStart + 1]);
                return;
            }
        } else {
            var collection = valueType.kind == TypeKind.SLICE;
            if (valueType.kind == TypeKind.ARRAY) collection = true;
            if (!collection) {
                semantic.fail(4, collectionNode);
                return;
            }
            if (valueType.kind == TypeKind.SLICE) {
                valueType = TypeValue(
                    typeKindFromValue(valueType.pointee), valueType.name, 0);
            } else {
                valueType = valueType.arrayElement();
            }
        }
        if (valueType.kind == TypeKind.INTEGER_LITERAL) {
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
                semantic.fail(4, collectionNode);
                return;
            }
        }
        val savedLocals = semantic.locals.length;
        val nameNode = semantic.nodes.data[node.subtreeStart];
        semantic.locals.add(LocalInfo(
            semantic.hash(nameNode), valueType, false, nameNode.start,
            false, false));
        if (node.aux == 1) {
            val indexNode = semantic.nodes.data[node.subtreeStart + 1];
            semantic.locals.add(
                LocalInfo(
                    semantic.hash(indexNode),
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
    if (node.kind == AstKind.WHEN_STATEMENT) {
        val branchCount = node.whenBranchCount();
        val hasSubject = if (node.whenHasSubject()) 1 else 0;
        if (branchCount == 0) {
            semantic.fail(4, node);
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
            if (subject.kind == TypeKind.INTEGER_LITERAL) {
                subject = TypeValue(TypeKind.I32, 0, 0);
                var subjectNode = semantic.nodes.data[subjectRoot];
                subjectNode.typeKind = TypeKind.I32.value;
                semantic.nodes.data[subjectRoot] = subjectNode;
            }
            var comparable = subject.kind == TypeKind.BOOL;
            if (subject.isInteger()) comparable = true;
            if (subject.kind == TypeKind.ENUM) comparable = true;
            if (!comparable) {
                semantic.fail(6, semantic.nodes.data[subjectRoot]);
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
            if (current.whenBranchIsElse()) hasElse = true;
            val bodyRoot = roots[index as u64] - 1;
            if (!current.whenBranchIsElse()) {
              val patternCount = current.whenBranchPatternCount();
              for (patternIndex in 0..<patternCount) {
                val conditionRoot = whenPatternRoot(
                    semantic, roots[index as u64], false, patternIndex);
                val condition = expressionType(semantic, conditionRoot);
                if (hasSubject == 1) {
                    if (
                        !subject.accepts(
                            condition,
                            semantic.genericArguments
                        )
                    ) {
                        semantic.fail(
                            4,
                            semantic.nodes.data[conditionRoot]);
                    } else {
                        var conditionNode = semantic.nodes.data[conditionRoot];
                        conditionNode.typeKind = subject.kind.value;
                        conditionNode.typeName = subject.name;
                        conditionNode.typePointee = subject.pointee;
                        semantic.nodes.data[conditionRoot] = conditionNode;
                    }
                } else {
                    if (condition.kind != TypeKind.BOOL) {
                        semantic.fail(
                            6,
                            semantic.nodes.data[conditionRoot]);
                    }
                }
              }
            }
            val savedLocals = semantic.locals.length;
            val savedScopeStart = semantic.scopeStart;
            semantic.scopeStart = savedLocals;
            checkStatement(semantic, bodyRoot);
            semantic.locals.setLength(savedLocals);
            semantic.scopeStart = savedScopeStart;
            includeCurrentOwnership(
                semantic, ownershipMerged, ownershipCount);
        }
        restoreOwnership(semantic, ownershipMerged, ownershipCount);
        k_boot_free(ownershipMerged as unit*);
        k_boot_free(ownershipBefore as unit*);
        val exhaustive = enumWhenExhaustive(
            semantic, subject, roots, branchCount, false);
        if (subject.kind == TypeKind.ENUM && !hasElse && !exhaustive) {
            semantic.fail(4, node);
        }
        k_boot_free(roots as unit*);
        return;
    }
    if (node.kind == AstKind.FUNCTION_OR_DEFER) {
        val savedSuppressMoves = semantic.suppressMoves;
        semantic.suppressMoves = true;
        checkStatement(semantic, root - 1);
        semantic.suppressMoves = savedSuppressMoves;
        return;
    }
    if (node.kind == AstKind.BREAK_STATEMENT) {
        if (semantic.loopDepth == 0) {
            semantic.fail(4, node);
        }
        return;
    }
    if (node.kind == AstKind.CONTINUE_STATEMENT) {
        if (semantic.loopDepth == 0) {
            semantic.fail(4, node);
        }
        return;
    }
    if (node.kind == AstKind.VARIABLE_DECLARATION) {
        val initializerRoot = root - 1;
        var initializer = expressionType(semantic, initializerRoot);
        val nameNode = semantic.nodes.data[node.subtreeStart];
        val name = semantic.hash(nameNode);
        if (localFindFrom(semantic.locals, name, semantic.scopeStart) !=
                semantic.locals.length) {
            semantic.fail(1, nameNode);
            return;
        }
        var valueType = initializer;
        if (valueType.kind == TypeKind.INTEGER_LITERAL) {
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
            if (!valueType.accepts(initializer, semantic.genericArguments)) {
                semantic.fail(
                    4, semantic.nodes.data[initializerRoot]);
            }
            resolveWhenResultType(semantic, initializerRoot, valueType);
            resolveIfResultType(semantic, initializerRoot, valueType);
            if (initializer.kind == TypeKind.ARRAY) {
                if (initializer.arrayElement().kind == TypeKind.INVALID) {
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
            (valueType.kind == TypeKind.STRUCT || valueType.kind == TypeKind.STR) &&
            typeNeedsOwnership(semantic, valueType);
        var declarationNode = semantic.nodes.data[root];
        if (automaticDrop) declarationNode.ownership = 2;
        semantic.nodes.data[root] = declarationNode;
        semantic.locals.add(LocalInfo(
            name, valueType, node.aux == TokenKind.VAR.value, nameNode.start,
            false, automaticDrop));
        return;
    }
    if (node.kind == AstKind.RETURN_STATEMENT) {
        var actual = unitType();
        if (node.aux == 1) {
            actual = expressionType(semantic, root - 1);
            actual = contextualizeLiteralByteSlice(
                semantic, root - 1, semantic.returnType, actual);
        }
        val function = semantic.nodes.data[semantic.currentFunction];
        if (function.storage % 2 == 1 && node.aux == 1) {
            var statementLike = actual.kind == TypeKind.UNIT;
            if (semantic.nodes.data[root - 1].kind == AstKind.ASSIGNMENT)
                statementLike = true;
            if (statementLike) {
                if (semantic.returnType.kind != TypeKind.UNIT)
                    semantic.fail(5, semantic.nodes.data[root - 1]);
                else {
                    var expressionStatement = node;
                    expressionStatement.kind = AstKind.EXPRESSION_STATEMENT;
                    semantic.nodes.data[root] = expressionStatement;
                }
                return;
            }
        }
        if (!semantic.returnType.accepts(actual, semantic.genericArguments)) {
            if (node.aux == 1) {
                semantic.fail(
                    5, semantic.nodes.data[root - 1]);
            } else {
                semantic.fail(5, node);
            }
        } else {
            if (node.aux == 1) {
                var returnNode = semantic.nodes.data[root];
                returnNode.typeKind = semantic.returnType.kind.value;
                returnNode.typeName = semantic.returnType.name;
                returnNode.typePointee = semantic.returnType.pointee;
                if (semantic.returnType.kind == TypeKind.NULLABLE) {
                    if (actual.kind == TypeKind.NULL_LITERAL) {
                        returnNode.conversionKind = 2;
                    } else {
                        if (actual.kind != TypeKind.NULLABLE) {
                            returnNode.conversionKind = 1;
                        }
                    }
                }
                semantic.nodes.data[root] = returnNode;
                var valueNode = semantic.nodes.data[root - 1];
                if (valueNode.typeKind == TypeKind.INTEGER_LITERAL.value) {
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
    if (node.kind == AstKind.EXPRESSION_STATEMENT) {
        val previousMutationRoot = semantic.mutationRoot;
        semantic.mutationRoot = root - 1;
        expressionType(semantic, root - 1);
        semantic.mutationRoot = previousMutationRoot;
    }
}
