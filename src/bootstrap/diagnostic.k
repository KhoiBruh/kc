module bootstrap.diagnostic;

import bootstrap.containers.ByteBuffer;
import bootstrap.types.TypeValue;
import bootstrap.list.List;

struct SemanticResult(
    ok: bool, category: u32, start: u64, end: u64,
    genericArguments: List<TypeValue>
)

fn semanticSuccess() => SemanticResult(true, 0, 0, 0, List<TypeValue>.new());

fn semanticError(
    category: u32, node: AstNode,
    val genericArguments: List<TypeValue>
) => SemanticResult(false, category, node.start, node.end, genericArguments);
