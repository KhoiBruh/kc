module bootstrap.ast;

enum AstKind {
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

fn astKindValue(kind: AstKind): u32 => when (kind) {
    AstKind.Invalid -> 0;
    AstKind.NamedType -> 1;
    AstKind.PointerType -> 2;
    AstKind.NullableType -> 3;
    AstKind.SliceType -> 4;
    AstKind.ArrayType -> 5;
    AstKind.Reserved6 -> 6;
    AstKind.Reserved7 -> 7;
    AstKind.Reserved8 -> 8;
    AstKind.Reserved9 -> 9;
    AstKind.Identifier -> 10;
    AstKind.Literal -> 11;
    AstKind.Unary -> 12;
    AstKind.Binary -> 13;
    AstKind.Assignment -> 14;
    AstKind.Cast -> 15;
    AstKind.Call -> 16;
    AstKind.Member -> 17;
    AstKind.Index -> 18;
    AstKind.Postfix -> 19;
    AstKind.UnitLiteral -> 20;
    AstKind.Sizeof -> 21;
    AstKind.ArrayLiteral -> 22;
    AstKind.WhenExpression -> 23;
    AstKind.WhenExpressionBranch -> 24;
    AstKind.IfExpression -> 25;
    AstKind.Reserved26 -> 26;
    AstKind.Reserved27 -> 27;
    AstKind.Reserved28 -> 28;
    AstKind.Reserved29 -> 29;
    AstKind.Block -> 30;
    AstKind.IfStatement -> 31;
    AstKind.WhileStatement -> 32;
    AstKind.VariableDeclaration -> 33;
    AstKind.ReturnStatement -> 34;
    AstKind.ExpressionStatement -> 35;
    AstKind.BreakStatement -> 36;
    AstKind.ContinueStatement -> 37;
    AstKind.ForStatement -> 38;
    AstKind.WhenStatement -> 39;
    AstKind.ParameterOrWhenBranch -> 40;
    AstKind.FunctionOrDefer -> 41;
    AstKind.StructField -> 42;
    AstKind.StructDeclaration -> 43;
    AstKind.Program -> 44;
    AstKind.Name -> 45;
    AstKind.TypeParameter -> 46;
    AstKind.ModuleDeclaration -> 47;
    AstKind.ImportDeclaration -> 48;
    AstKind.EnumDeclaration -> 49;
    AstKind.ConstantDeclaration -> 50;
};

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
