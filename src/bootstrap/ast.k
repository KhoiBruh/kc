module bootstrap.ast;

import bootstrap.list.List;

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

struct AstView(nodes: List<AstNode>) {

    fn expressionChildBefore(val self, root: u64): u64 =>
        self.nodes.data[root].subtreeStart - 1;

    fn declarationRoots(val self): u64* {
        val programRoot = self.nodes.length - 1;
        val program = self.nodes.data[programRoot];
        val roots =
            k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
        var root = programRoot - 1;
        for (index in program.aux>..0) {
            roots[index as u64] = root;
            root = self.nodes.data[root].subtreeStart - 1;
        }
        return roots;
    }

    fn blockStatementRoots(val self, blockRoot: u64): u64* {
        val block = self.nodes.data[blockRoot];
        val roots =
            k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
        var root = blockRoot - 1;
        for (index in block.aux>..0) {
            roots[index as u64] = root;
            root = self.nodes.data[root].subtreeStart - 1;
        }
        return roots;
    }

    fn firstStatementRoot(val self, blockRoot: u64): u64 {
        val block = self.nodes.data[blockRoot];
        var roots =
            k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
        var root = blockRoot - 1;
        for (index in block.aux>..0) {
            roots[index as u64] = root;
            root = self.nodes.data[root].subtreeStart - 1;
        }
        val result = roots[0];
        k_boot_free(roots as unit*);
        return result;
    }

    fn callCalleeRoot(val self, callRoot: u64): u64 {
        val call = self.nodes.data[callRoot];
        var cursor = callRoot - 1;
        val argumentCount = call.callArgumentCount();
        for (argument in 0..<argumentCount) {
            cursor = self.expressionChildBefore(cursor);
        }
        val explicitTypeCount = call.callTypeArgumentCount();
        for (explicitType in 0..<explicitTypeCount) {
            cursor = self.expressionChildBefore(cursor);
        }
        return cursor;
    }

    fn returnTypeRoot(val self, functionRoot: u64): u64 {
        if (self.nodes.data[functionRoot].isExtern()) {
            return functionRoot - 1;
        }
        return self.nodes.data[functionRoot - 1].subtreeStart - 1;
    }

    fn parameterRoot(val self, functionRoot: u64, position: u32): u64 {
        val function = self.nodes.data[functionRoot];
        var root = functionRoot - 1;
        if (!function.isExtern()) {
            root = self.nodes.data[root].subtreeStart - 1;
        }
        val remaining = function.parameterCount();
        for (index in position - 1..<remaining) {
            root = self.nodes.data[root].subtreeStart - 1;
        }
        return root;
    }

    fn emitterRootBeforeStructMethods(val self, structureRoot: u64): u64 {
        var root = structureRoot - 1;
        val remaining = self.nodes.data[structureRoot].methodCount();
        for (method in 0..<remaining) {
            root = self.nodes.data[root].subtreeStart - 1;
        }
        return root;
    }

    fn emitterFieldRootAt(val self, structureRoot: u64, wanted: u32): u64 {
        val structure = self.nodes.data[structureRoot];
        var roots =
            k_boot_alloc((structure.fieldCount() as u64) * sizeof(u64)) as u64*;
        var root = self.emitterRootBeforeStructMethods(structureRoot);
        val remaining = structure.fieldCount();
        for (index in remaining>..0) {
            roots[index as u64] = root;
            root = self.nodes.data[root].subtreeStart - 1;
        }
        val result = roots[wanted as u64];
        k_boot_free(roots as unit*);
        return result;
    }

    fn emitterAssociatedOwnerStructRoot(val self, functionRoot: u64): u64 {
        if (self.nodes.data[functionRoot].conversionKind != 2) {
            return self.nodes.length;
        }
        val program = self.nodes.data[self.nodes.length - 1];
        val roots = self.declarationRoots();
        var owner = self.nodes.length;
        for (index in 0..<program.aux) {
            val structureRoot = roots[index as u64];
            if (self.nodes.data[structureRoot].kind == AstKind.STRUCT_DECLARATION) {
                var methodRoot = structureRoot - 1;
                val methodCount = self.nodes.data[structureRoot].methodCount();
                for (methodIndex in 0..<methodCount) {
                    if (methodRoot == functionRoot) owner = structureRoot;
                    methodRoot = self.nodes.data[methodRoot].subtreeStart - 1;
                }
            }
        }
        k_boot_free(roots as unit*);
        return owner;
    }

    fn emitterStructTypeParameterRoot(
        val self, structureRoot: u64, position: u32
    ): u64 {
        val structure = self.nodes.data[structureRoot];
        var lastRoot = self.emitterRootBeforeStructMethods(structureRoot);
        val fields = structure.fieldCount();

        for (field in 0..<fields) lastRoot = self.nodes.data[lastRoot].subtreeStart - 1;
        val remain = structure.structTypeParameterCount();
        for (index in position..<remain) lastRoot = self.nodes.data[lastRoot].subtreeStart - 1;

        return lastRoot;
    }

    fn emitterTypeParameterRoot(val self, functionRoot: u64, position: u32): u64 {
        var returnRoot = self.returnTypeRoot(functionRoot);

        val params = self.nodes.data[functionRoot].parameterCount();
        for (param in 0..<params) returnRoot = self.nodes.data[returnRoot].subtreeStart - 1;

        val remain = self.nodes.data[functionRoot].typeParameterCount();
        for (index in position - 1..<remain) returnRoot = self.nodes.data[returnRoot].subtreeStart - 1;

        return returnRoot;
    }

}