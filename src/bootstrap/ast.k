module bootstrap.ast;

enum AstKind : u32 {
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

enum ParameterMode : u32 {
    Owned,
    ImmutableBorrow,
    MutableBorrow
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
) {

    fn mode(val self) => when (self.aux) {
        ParameterMode.ImmutableBorrow.value -> ParameterMode.ImmutableBorrow;
        ParameterMode.MutableBorrow.value -> ParameterMode.MutableBorrow;
        else -> ParameterMode.Owned;
    };

    fn isExtern(val self): bool => (self.aux / 65536) % 2 == 1;

    fn infersReturn(val self): bool => (self.storage / 2) % 2 == 1;

    fn isExpressionBody(val self): bool => self.storage % 2 == 1;

    fn methodCount(val self): u32 => self.storage as u32;

    fn fieldCount(val self): u32 => self.aux % 65536;

    fn parameterCount(val self): u32 => self.aux % 65536;

    fn typeParameterCount(val self): u32 => (self.aux / 131072) % 65536;

    fn structTypeParameterCount(val self): u32 => self.aux / 65536;

    fn callTypeArgumentCount(val self): u32 => self.aux / 65536;

    fn callArgumentCount(val self): u32 => self.aux % 65536;

    fn whenBranchCount(val self): u32 => self.aux % 65536;

    fn whenHasSubject(val self): bool => (self.aux / 65536) % 2 == 1;

    fn whenBranchIsElse(val self): bool => self.aux % 2 == 1;

    fn whenBranchPatternCount(val self): u32 => self.aux / 65536;

}