module bootstrap.ast;

struct AstNode(
    kind: u32,
    start: u64,
    end: u64,
    subtreeStart: u64,
    aux: u32,
    typeKind: u32,
    typeName: u64,
    typePointee: u32,
    storage: u64,
    genericArgumentStart: u64,
    genericArgumentCount: u32,
    conversionKind: u32
)
