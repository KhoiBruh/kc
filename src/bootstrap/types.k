module bootstrap.types;

import bootstrap.ast.AstNode;
import bootstrap.list.List;
import bootstrap.token.TokenKind;
import bootstrap.token.tokenKindValue;

enum TypeKind {
    Invalid,
    Unit,
    Bool,
    I32,
    I64,
    U8,
    U32,
    U64,
    Struct,
    Pointer,
    String,
    IntegerLiteral,
    Function,
    Slice,
    TypeParameter,
    Nullable,
    NullLiteral,
    F32,
    F64,
    Array,
    Enum
}

fn typeKindValue(kind: TypeKind): u32 => when (kind) {
    TypeKind.Invalid -> 0;
    TypeKind.Unit -> 1;
    TypeKind.Bool -> 2;
    TypeKind.I32 -> 3;
    TypeKind.I64 -> 4;
    TypeKind.U8 -> 5;
    TypeKind.U32 -> 6;
    TypeKind.U64 -> 7;
    TypeKind.Struct -> 8;
    TypeKind.Pointer -> 9;
    TypeKind.String -> 10;
    TypeKind.IntegerLiteral -> 11;
    TypeKind.Function -> 12;
    TypeKind.Slice -> 13;
    TypeKind.TypeParameter -> 14;
    TypeKind.Nullable -> 15;
    TypeKind.NullLiteral -> 16;
    TypeKind.F32 -> 17;
    TypeKind.F64 -> 18;
    TypeKind.Array -> 19;
    TypeKind.Enum -> 20;
};

fn typeKindFromValue(value: u32): TypeKind => when (value) {
    1 -> TypeKind.Unit;
    2 -> TypeKind.Bool;
    3 -> TypeKind.I32;
    4 -> TypeKind.I64;
    5 -> TypeKind.U8;
    6 -> TypeKind.U32;
    7 -> TypeKind.U64;
    8 -> TypeKind.Struct;
    9 -> TypeKind.Pointer;
    10 -> TypeKind.String;
    11 -> TypeKind.IntegerLiteral;
    12 -> TypeKind.Function;
    13 -> TypeKind.Slice;
    14 -> TypeKind.TypeParameter;
    15 -> TypeKind.Nullable;
    16 -> TypeKind.NullLiteral;
    17 -> TypeKind.F32;
    18 -> TypeKind.F64;
    19 -> TypeKind.Array;
    20 -> TypeKind.Enum;
    else -> TypeKind.Invalid;
};

struct TypeValue(kind: TypeKind, name: u64, pointee: u32) {

	fn array(val self, size: u64) => TypeValue(
        TypeKind.Array, self.name,
        typeKindValue(self.kind) + (size as u32) * 256);

	fn arrayElement(val self) => TypeValue(
        typeKindFromValue(self.pointee % 256), self.name, 0);

	fn arraySize(val self) => self.pointee / 256;

	fn isFloat(val self) =>
        self.kind == TypeKind.F32 || self.kind == TypeKind.F64;

	fn isInteger(val self) =>
        self.kind == TypeKind.I32 || self.kind == TypeKind.I64 ||
        self.kind == TypeKind.U8 || self.kind == TypeKind.U32 ||
        self.kind == TypeKind.U64;

	fn isSigned(val self) =>
        self.kind == TypeKind.I32 || self.kind == TypeKind.I64;

	fn intWidth(val self) => when (self.kind) {
		TypeKind.U8 -> 8;
		TypeKind.I64, TypeKind.U64 -> 64;
		else -> 32;
	};
}

fn invalidType() => TypeValue(TypeKind.Invalid, 0, 0);

fn unitType() => TypeValue(TypeKind.Unit, 0, 0);

fn boolType() => TypeValue(TypeKind.Bool, 0, 0);

fn integerLiteralType() => TypeValue(TypeKind.IntegerLiteral, 0, 0);

fn integerCastRequiresRangeCheck(source: TypeValue, target: TypeValue): bool {
    if (source.kind == target.kind) return false;
    val sourceWidth = source.intWidth();
    val targetWidth = target.intWidth();
    if (source.isSigned() == target.isSigned()) {
        return targetWidth < sourceWidth;
    }
    if (source.isSigned()) return true;
    return targetWidth <= sourceWidth;
}

fn integerImplicitlyWidens(source: TypeValue, target: TypeValue): bool {
    if (!source.isInteger()) return false;
    if (!target.isInteger()) return false;
    if (source.kind == target.kind) return false;
    if (target.intWidth() <= source.intWidth()) return false;
    if (source.isSigned() && !target.isSigned()) return false;
    return true;
}

fn typeEquals(left: TypeValue, right: TypeValue, val genericArguments: List<TypeValue>): bool {
    if (left.kind != right.kind) return false;
    if (left.name != right.name) return false;
    if (left.kind == TypeKind.Struct) {
        val leftCount = left.pointee / 65536;
        val rightCount = right.pointee / 65536;
        if (leftCount != rightCount) return false;
        if (leftCount == 0) return true;
        val leftStart = left.pointee % 65536;
        val rightStart = right.pointee % 65536;
        for (index in 0..<leftCount) {
            val leftArg = genericArguments.data[leftStart as u64 + index as u64];
            val rightArg = genericArguments.data[rightStart as u64 + index as u64];
            if (!typeEquals(leftArg, rightArg, genericArguments)) {
                return false;
            }
        }
        return true;
    }
    return left.pointee == right.pointee;
}

fn typeAccepts(expected: TypeValue, actual: TypeValue, val genericArguments: List<TypeValue>): bool {
    if (typeEquals(expected, actual, genericArguments)) return true;
    if (integerImplicitlyWidens(actual, expected)) return true;
    if (expected.kind == TypeKind.Nullable) {
        if (actual.kind == TypeKind.NullLiteral) return true;
        return typeEquals(
            TypeValue(typeKindFromValue(expected.pointee), expected.name, 0), actual, genericArguments);
    }
    if (actual.kind == TypeKind.IntegerLiteral) {
        if (expected.isInteger()) return true;
    }
    if (actual.kind == TypeKind.F64) {
        if (expected.isFloat()) return true;
    }
    if (expected.kind == TypeKind.Array) {
        if (actual.kind == TypeKind.Array) {
            if (expected.arraySize() == actual.arraySize()) {
                if (actual.arrayElement().kind == TypeKind.Invalid) return true;
            }
        }
    }
    return false;
}

fn primitiveType(tokenKind: u32): TypeValue {
    if (tokenKind == tokenKindValue(TokenKind.KwUnit)) return unitType();
    if (tokenKind == tokenKindValue(TokenKind.KwBool)) return boolType();
    if (tokenKind == tokenKindValue(TokenKind.KwI32)) return TypeValue(TypeKind.I32, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwI64)) return TypeValue(TypeKind.I64, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwU8)) return TypeValue(TypeKind.U8, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwU32)) return TypeValue(TypeKind.U32, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwU64)) return TypeValue(TypeKind.U64, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwF32)) return TypeValue(TypeKind.F32, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwF64)) return TypeValue(TypeKind.F64, 0, 0);
    if (tokenKind == tokenKindValue(TokenKind.KwString)) return TypeValue(TypeKind.String, 0, 0);
    return invalidType();
}

struct LocalInfo(
    name: u64, valueType: TypeValue, mutable: bool, storage: u64,
    moved: bool, autoDrop: bool)
fn localFind(val locals: List<LocalInfo>, name: u64): u64 {
    for (index in locals.length>..0)
        if (locals.data[index].name == name) return index;
    return locals.length;
}

fn localFindFrom(val locals: List<LocalInfo>, name: u64, start: u64): u64 {
    for (index in locals.length>..start)
        if (locals.data[index].name == name) return index;
    return locals.length;
}

struct DeclarationInfo(name: u64, node: u64)
fn declarationFind(val declarations: List<DeclarationInfo>, name: u64): u64 {
    for (index in 0..<declarations.length)
        if (declarations.data[index].name == name) return index;
    return declarations.length;
}
