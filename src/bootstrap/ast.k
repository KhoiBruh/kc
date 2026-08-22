module bootstrap.ast;

enum AstKind : u32 {
    INVALID,
    NAMED_TYPE,
    POINTER_TYPE,
    NULLABLE_TYPE,
    SLICE_TYPE,
    ARRAY_TYPE,
    RESERVED_6,
    RESERVED_7,
    RESERVED_8,
    RESERVED_9,
    IDENTIFIER,
    LITERAL,
    UNARY,
    BINARY,
    ASSIGNMENT,
    CAST,
    CALL,
    MEMBER,
    INDEX,
    POSTFIX,
    UNIT_LITERAL,
    SIZEOF,
    ARRAY_LITERAL,
    WHEN_EXPRESSION,
    WHEN_EXPRESSION_BRANCH,
    IF_EXPRESSION,
    RESERVED_26,
    RESERVED_27,
    RESERVED_28,
    RESERVED_29,
    BLOCK,
    IF_STATEMENT,
    WHILE_STATEMENT,
    VARIABLE_DECLARATION,
    RETURN_STATEMENT,
    EXPRESSION_STATEMENT,
    BREAK_STATEMENT,
    CONTINUE_STATEMENT,
    FOR_STATEMENT,
    WHEN_STATEMENT,
    PARAMETER_OR_WHEN_BRANCH,
    FUNCTION_OR_DEFER,
    STRUCT_FIELD,
    STRUCT_DECLARATION,
    PROGRAM,
    NAME,
    TYPE_PARAMETER,
    MODULE_DECLARATION,
    IMPORT_DECLARATION,
    ENUM_DECLARATION,
    CONSTANT_DECLARATION
}

enum ParameterMode : u32 {
    OWNED,
    IMMUTABLE_BORROW,
    MUTABLE_BORROW
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
        ParameterMode.IMMUTABLE_BORROW.value -> ParameterMode.IMMUTABLE_BORROW;
        ParameterMode.MUTABLE_BORROW.value -> ParameterMode.MUTABLE_BORROW;
        else -> ParameterMode.OWNED;
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