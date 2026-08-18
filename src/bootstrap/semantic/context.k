module bootstrap.semantic.context;

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

struct Semantic(
    source: Source,
    nodes: List<AstNode>,
    structs: List<DeclarationInfo>,
    enums: List<DeclarationInfo>,
    functions: List<DeclarationInfo>,
    constants: List<DeclarationInfo>,
    locals: List<LocalInfo>,
    genericArguments: List<TypeValue>,
    result: SemanticResult,
    returnType: TypeValue,
    scopeStart: u64,
    currentFunction: u64,
    currentStruct: u64,
    loopDepth: u32,
    mutationRoot: u64,
    suppressMoves: bool
) {

	fn free(var self) {
		k_boot_free(self.locals.data as unit*);
		k_boot_free(self.functions.data as unit*);
		k_boot_free(self.constants.data as unit*);
		k_boot_free(self.enums.data as unit*);
		k_boot_free(self.structs.data as unit*);
	}

	fn fail(var self, category: u32, node: AstNode) {
		if (self.result.ok)
			self.result = semanticError(category, node, self.genericArguments);
	}
}

struct IntegerConstant(ok: bool, negative: bool, overflow: bool, magnitude: u64)

fn sourceHash(source: Source, start: u64, end: u64): u64 {
    var value: u64 = 5381;
    for (i in start..<end) value = value * 33 + source.data[i] as u64;
    return value;
}

fn nodeHash(val semantic: Semantic, node: AstNode) =>
    sourceHash(semantic.source, node.start, node.end);
