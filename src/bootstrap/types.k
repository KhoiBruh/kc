module bootstrap.types;

import bootstrap.ast.AstNode;
import bootstrap.list.List;
import bootstrap.token.TokenKind;

enum TypeKind : u32 {
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
        self.kind.value + (size as u32) * 256);

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

	fn requiresRangeCheck(val self, target: TypeValue): bool {
		if (self.kind == target.kind) return false;
		val sourceWidth = self.intWidth();
		val targetWidth = target.intWidth();
		if (self.isSigned() == target.isSigned()) {
			return targetWidth < sourceWidth;
		}
		if (self.isSigned()) return true;
		return targetWidth <= sourceWidth;
	}

	fn implicitlyWidensTo(val self, target: TypeValue): bool {
		if (!self.isInteger()) return false;
		if (!target.isInteger()) return false;
		if (self.kind == target.kind) return false;
		if (target.intWidth() <= self.intWidth()) return false;
		if (self.isSigned() && !target.isSigned()) return false;
		return true;
	}

	fn equals(val self, right: TypeValue, val genericArguments: List<TypeValue>): bool {
		if (self.kind != right.kind) return false;
		if (self.name != right.name) return false;
		if (self.kind == TypeKind.Struct) {
			val leftCount = self.pointee / 65536;
			val rightCount = right.pointee / 65536;
			if (leftCount != rightCount) return false;
			if (leftCount == 0) return true;
			val leftStart = self.pointee % 65536;
			val rightStart = right.pointee % 65536;
			for (index in 0..<leftCount) {
				val leftArg = genericArguments.data[leftStart as u64 + index as u64];
				val rightArg = genericArguments.data[rightStart as u64 + index as u64];
				if (!leftArg.equals(rightArg, genericArguments)) {
					return false;
				}
			}
			return true;
		}
		return self.pointee == right.pointee;
	}

	fn accepts(val self, actual: TypeValue, val genericArguments: List<TypeValue>): bool {
		if (self.equals(actual, genericArguments)) return true;
		if (actual.implicitlyWidensTo(self)) return true;
		if (self.kind == TypeKind.Nullable) {
			if (actual.kind == TypeKind.NullLiteral) return true;
			return TypeValue(typeKindFromValue(self.pointee), self.name, 0).equals(actual, genericArguments);
		}
		if (actual.kind == TypeKind.IntegerLiteral) {
			if (self.isInteger()) return true;
		}
		if (actual.kind == TypeKind.F64) {
			if (self.isFloat()) return true;
		}
		if (self.kind == TypeKind.Array) {
			if (actual.kind == TypeKind.Array) {
				if (self.arraySize() == actual.arraySize()) {
					if (actual.arrayElement().kind == TypeKind.Invalid) return true;
				}
			}
		}
		return false;
	}
}

fn invalidType() => TypeValue(TypeKind.Invalid, 0, 0);

fn unitType() => TypeValue(TypeKind.Unit, 0, 0);

fn boolType() => TypeValue(TypeKind.Bool, 0, 0);

fn integerLiteralType() => TypeValue(TypeKind.IntegerLiteral, 0, 0);

fn primitiveType(tokenKind: u32): TypeValue => when (tokenKind) {
    TokenKind.KwUnit.value -> unitType();
    TokenKind.KwBool.value -> boolType();
    TokenKind.KwI32.value -> TypeValue(TypeKind.I32, 0, 0);
    TokenKind.KwI64.value -> TypeValue(TypeKind.I64, 0, 0);
    TokenKind.KwU8.value -> TypeValue(TypeKind.U8, 0, 0);
    TokenKind.KwU32.value -> TypeValue(TypeKind.U32, 0, 0);
    TokenKind.KwU64.value -> TypeValue(TypeKind.U64, 0, 0);
    TokenKind.KwF32.value -> TypeValue(TypeKind.F32, 0, 0);
    TokenKind.KwF64.value -> TypeValue(TypeKind.F64, 0, 0);
    TokenKind.KwString.value -> TypeValue(TypeKind.String, 0, 0);
    else -> invalidType();
};

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
