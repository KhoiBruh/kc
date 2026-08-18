module bootstrap.semantic.context;

import bootstrap.*;
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
}

struct IntegerConstant(ok: bool, negative: bool, overflow: bool, magnitude: u64)

fn sourceHash(source: Source, start: u64, end: u64): u64 {
    var value: u64 = 5381;
    for (i in start..<end) value = value * 33 + source.data[i] as u64;
    return value;
}

fn nodeHash(val semantic: Semantic, node: AstNode) =>
    sourceHash(semantic.source, node.start, node.end);

fn semanticFail(var semantic: Semantic, category: u32, node: AstNode) =>
    if (semantic.result.ok) 
        semantic.result = semanticError(category, node, semantic.genericArguments);
