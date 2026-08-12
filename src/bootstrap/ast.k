module bootstrap.ast;

enum AstKind: u32 {
    Invalid,
    NamedType,
    PointerType,
    NullableType,
    SliceType,
    ArrayType,
    Reserved6,
    Reserved7,
    Reserved8,
    Reserved9,
    Identifier,
    Literal,
    Unary,
    Binary,
    Assignment,
    Cast,
    Call,
    Member,
    Index,
    Postfix,
    UnitLiteral,
    Sizeof,
    ArrayLiteral,
    WhenExpression,
    WhenExpressionBranch,
    IfExpression,
    Reserved26,
    Reserved27,
    Reserved28,
    Reserved29,
    Block,
    IfStatement,
    WhileStatement,
    VariableDeclaration,
    ReturnStatement,
    ExpressionStatement,
    BreakStatement,
    ContinueStatement,
    ForStatement,
    WhenStatement,
    ParameterOrWhenBranch,
    FunctionOrDefer,
    StructField,
    StructDeclaration,
    Program,
    Name,
    TypeParameter,
    ModuleDeclaration,
    ImportDeclaration,
    EnumDeclaration,
    ConstantDeclaration
}

enum ParameterMode: u32 {
    Owned = 0,
    ImmutableBorrow = 1,
    MutableBorrow = 2
}


struct AstNode(
    kind: AstKind,
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
    conversionKind: u32,
    ownership: u32
)

fn parameterMode(node: AstNode): ParameterMode => when (node.aux) {
    ParameterMode.ImmutableBorrow.value -> ParameterMode.ImmutableBorrow;
    ParameterMode.MutableBorrow.value -> ParameterMode.MutableBorrow;
    else -> ParameterMode.Owned;
};
