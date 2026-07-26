module kbootstrap.diagnostic;

import kbootstrap.containers.ByteBuffer;
import kbootstrap.types.TypeValue;

struct SemanticResult(
    ok: bool, category: u32, start: u64, end: u64,
    genericArguments: TypeValueList)

fn semanticSuccess(genericArguments: TypeValueList): SemanticResult {
    return SemanticResult(true, 0, 0, 0, genericArguments);
}

fn semanticError(
    category: u32, node: AstNode,
    genericArguments: TypeValueList): SemanticResult {
    return SemanticResult(
        false, category, node.start, node.end, genericArguments);
}
