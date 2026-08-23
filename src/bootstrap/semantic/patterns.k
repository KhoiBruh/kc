module bootstrap.semantic.patterns;

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

fn enumVariantStart(enumeration: AstNode) =>
    enumeration.subtreeStart + 1 + enumeration.storage;

fn enumExplicitConstant(val semantic: Semantic, variant: AstNode): IntegerConstant {
    if (variant.conversionKind == 0)
        return IntegerConstant(false, false, false, 0);
    var magnitude: u64 = 0;
    var overflow = false;
    for (offset in variant.storage..<variant.typeName) {
        val digit = (semantic.source.data[offset] - 48) as u64;
        if (magnitude > 1844674407370955161) overflow = true;
        else if (magnitude == 1844674407370955161 && digit > 5) overflow = true;
        if (!overflow) magnitude = magnitude * 10 + digit;
    }
    return IntegerConstant(true, variant.ownership == 1, overflow, magnitude);
}

fn whenConditionRoot(val semantic: Semantic, branchRoot: u64, valueForm: bool): u64 {
    if (!valueForm) {
        val bodyRoot = branchRoot - 1;
        return semantic.nodes.data[bodyRoot].subtreeStart - 1;
    }
    val branch = semantic.nodes.data[branchRoot];
    val valueRoot = branchRoot - 1;
    var conditionRoot = semantic.nodes.data[valueRoot].subtreeStart - 1;
    val statements = (branch.aux % 65536) / 2;
    for (statement in 0..<statements) {
        conditionRoot = semantic.nodes.data[conditionRoot].subtreeStart - 1;
    }
    return conditionRoot;
}

fn whenPatternRoot(
    val semantic: Semantic, branchRoot: u64,
    valueForm: bool, patternIndex: u32
): u64 {
    val branch = semantic.nodes.data[branchRoot];
    val patternCount = branch.whenBranchPatternCount();
    var root = whenConditionRoot(semantic, branchRoot, valueForm);
    val remaining = patternCount - patternIndex - 1;
    for (index in 0..<remaining) {
        root = semantic.nodes.data[root].subtreeStart - 1;
    }
    return root;
}

fn enumWhenExhaustive(
    var semantic: Semantic, subject: TypeValue, 
    roots: u64*, branchCount: u32, valueForm: bool
): bool {
    if (subject.kind != TypeKind.ENUM) return false;
    val enumIndex = declarationFind(semantic.enums, subject.name);
    if (enumIndex == semantic.enums.length) return false;
    val declaration = semantic.nodes.data[semantic.enums.data[enumIndex].node];
    var unique: u32 = 0;
    for (index in 0..<branchCount) {
        val branch = semantic.nodes.data[roots[index as u64]];
        val isElse = branch.whenBranchIsElse();

        if (!isElse) {
          val patternCount = branch.whenBranchPatternCount();
          for (patternIndex in 0..<patternCount) {
            val conditionRoot = whenPatternRoot(
                semantic, roots[index as u64], valueForm, patternIndex);
            val condition = semantic.nodes.data[conditionRoot];
            if (condition.kind == AstKind.MEMBER && condition.typeKind == TypeKind.ENUM.value &&
                    condition.typeName == subject.name) {
                for (prior in 0..index) {
                    val priorBranch = semantic.nodes.data[roots[prior as u64]];
                    val priorElse = priorBranch.whenBranchIsElse();
                    if (!priorElse) {
                      var priorCount = priorBranch.whenBranchPatternCount();
                      if (prior == index) priorCount = patternIndex;
                      for (priorPattern in 0..<priorCount) {
                        val priorRoot = whenPatternRoot(
                            semantic, roots[prior as u64], valueForm,
                            priorPattern);
                        val priorCondition = semantic.nodes.data[priorRoot];
                        if (priorCondition.kind == AstKind.MEMBER &&
                                priorCondition.typeKind == TypeKind.ENUM.value &&
                                priorCondition.typeName == subject.name &&
                                priorCondition.conversionKind == condition.conversionKind) {
                            var diagnostic = condition;
                            diagnostic.start = semantic.nodes.data[
                                condition.subtreeStart].start;
                            semantic.fail(1, diagnostic);
                            return false;
                        }
                      }
                    }
                }
                unique++;
            }
          }
        }
    }

    return unique == declaration.aux;
}
