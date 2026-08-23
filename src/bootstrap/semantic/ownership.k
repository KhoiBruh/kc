module bootstrap.semantic.ownership;

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

fn markOwnerRootMoved(var semantic: Semantic, root: u64) {
    val node = semantic.nodes.data[root];
    if (node.kind == AstKind.IDENTIFIER) {
        val local = localFind(semantic.locals, semantic.hash(node));
        if (local != semantic.locals.length) {
            var value = semantic.locals.data[local];
            value.moved = true;
            semantic.locals.data[local] = value;
            var movedNode = semantic.nodes.data[root];
            if (movedNode.ownership % 2 == 0) movedNode.ownership++;
            semantic.nodes.data[root] = movedNode;
        }
        return;
    }
    if (node.kind == AstKind.MEMBER || node.kind == AstKind.POSTFIX) {
        markOwnerRootMoved(semantic, root - 1);
        return;
    }
    if (node.kind == AstKind.INDEX) {
        val indexRoot = root - 1;
        val objectRoot = semantic.nodes.data[indexRoot].subtreeStart - 1;
        if (semantic.nodes.data[objectRoot].typeKind == TypeKind.ARRAY.value) {
            markOwnerRootMoved(semantic, objectRoot);
        }
    }
}

fn markExpressionMoved(var semantic: Semantic, root: u64) {
    if (semantic.suppressMoves) return;
    val node = semantic.nodes.data[root];
    val value = TypeValue(typeKindFromValue(node.typeKind), node.typeName, node.typePointee);
    if (!typeNeedsOwnership(semantic, value)) return;
    if (node.kind == AstKind.IF_EXPRESSION) {
        val elseValueRoot = root - 1;
        var thenValueRoot = semantic.nodes.data[elseValueRoot].subtreeStart - 1;
        for (index in 0..<node.aux / 65536) {
            thenValueRoot = semantic.nodes.data[thenValueRoot].subtreeStart - 1;
        }
        markExpressionMoved(semantic, thenValueRoot);
        markExpressionMoved(semantic, elseValueRoot);
        return;
    }
    if (node.kind == AstKind.WHEN_EXPRESSION) {
        var branchRoot = root - 1;
        for (index in node.aux % 65536>..0) {
            markExpressionMoved(semantic, branchRoot - 1);
            branchRoot = semantic.nodes.data[branchRoot].subtreeStart - 1;
        }
        return;
    }
    if (node.kind == AstKind.ARRAY_LITERAL) {
        var childRoot = root - 1;
        for (index in 0..<node.aux) {
            markExpressionMoved(semantic, childRoot);
            childRoot = semantic.nodes.data[childRoot].subtreeStart - 1;
        }
        return;
    }
    markOwnerRootMoved(semantic, root);
}

fn captureOwnership(val semantic: Semantic, count: u64): u8* {
    val states = k_boot_alloc(count) as u8*;
    for (index in 0..<count) {
        states[index] = if (semantic.locals.data[index].moved)
            1 as u8 else 0 as u8;
    }
    return states;
}

fn restoreOwnership(var semantic: Semantic, states: u8*, count: u64) {
    for (index in 0..<count) {
        var local = semantic.locals.data[index];
        local.moved = states[index] == 1;
        semantic.locals.data[index] = local;
    }
}

fn mergeOwnership(
    var semantic: Semantic, left: u8*, right: u8*, count: u64) {
    for (index in 0..<count) {
        var local = semantic.locals.data[index];
        local.moved = left[index] == 1 || right[index] == 1;
        semantic.locals.data[index] = local;
    }
}

fn includeCurrentOwnership(
    val semantic: Semantic, states: u8*, count: u64) {
    for (index in 0..<count) {
        if (semantic.locals.data[index].moved) states[index] = 1 as u8;
    }
}
