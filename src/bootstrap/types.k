module bootstrap.types;

import bootstrap.ast.AstNode;
import bootstrap.list.List;
import bootstrap.token.TokenKind;

enum TypeKind : u32 {
    INVALID,
    UNIT,
    BOOL,
    I32,
    I64,
    U8,
    U32,
    U64,
    STRUCT,
    POINTER,
    STR,
    INTEGER_LITERAL,
    FUNCTION,
    SLICE,
    TYPE_PARAMETER,
    NULLABLE,
    NULL_LITERAL,
    F32,
    F64,
    ARRAY,
    ENUM
}

fn typeKindFromValue(value: u32): TypeKind => when (value) {
    1 -> TypeKind.UNIT;
    2 -> TypeKind.BOOL;
    3 -> TypeKind.I32;
    4 -> TypeKind.I64;
    5 -> TypeKind.U8;
    6 -> TypeKind.U32;
    7 -> TypeKind.U64;
    8 -> TypeKind.STRUCT;
    9 -> TypeKind.POINTER;
    10 -> TypeKind.STR;
    11 -> TypeKind.INTEGER_LITERAL;
    12 -> TypeKind.FUNCTION;
    13 -> TypeKind.SLICE;
    14 -> TypeKind.TYPE_PARAMETER;
    15 -> TypeKind.NULLABLE;
    16 -> TypeKind.NULL_LITERAL;
    17 -> TypeKind.F32;
    18 -> TypeKind.F64;
    19 -> TypeKind.ARRAY;
    20 -> TypeKind.ENUM;
    else -> TypeKind.INVALID;
};

struct TypeValue(kind: TypeKind, name: u64, pointee: u32) {

	fn array(val self, size: u64) => TypeValue(
        TypeKind.ARRAY, self.name,
        self.kind.value + (size as u32) * 256
	);

	fn arrayElement(val self) => TypeValue(
        typeKindFromValue(self.pointee % 256), self.name, 0
	);

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

		if (self.isSigned() == target.isSigned()) return targetWidth < sourceWidth;
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

	fn genericStart(val self) => self.pointee % 65536;

	fn genericCount(val self) => self.pointee / 65536;

	fn equals(val self, right: TypeValue, val genericArguments: List<TypeValue>): bool {
		if (self.kind != right.kind) return false;
		if (self.name != right.name) return false;

		if (self.kind == TypeKind.STRUCT) {
			val leftCount = self.genericCount();
			val rightCount = right.genericCount();
			if (leftCount != rightCount) return false;
			if (leftCount == 0) return true;

			val leftStart = self.genericStart();
			val rightStart = right.genericStart();

			for (index in 0..<leftCount) {
				val leftArg = genericArguments.data[leftStart + index];
				val rightArg = genericArguments.data[rightStart + index];
				if (!leftArg.equals(rightArg, genericArguments)) return false;
			}

			return true;
		}

		return self.pointee == right.pointee;
	}

	fn accepts(val self, actual: TypeValue, val genericArguments: List<TypeValue>): bool {
		if (self.equals(actual, genericArguments)) return true;
		if (actual.implicitlyWidensTo(self)) return true;

		if (self.kind == TypeKind.NULLABLE) {
			if (actual.kind == TypeKind.NULL_LITERAL) return true;
			return TypeValue(typeKindFromValue(self.pointee), self.name, 0).equals(actual, genericArguments);
		}

		if (actual.kind == TypeKind.INTEGER_LITERAL) {
			if (self.isInteger()) return true;
		}

		if (actual.kind == TypeKind.F64) {
			if (self.isFloat()) return true;
		}

		if (self.kind == TypeKind.ARRAY) {
			if (actual.kind == TypeKind.ARRAY) {
				if (self.arraySize() == actual.arraySize()) {
					if (actual.arrayElement().kind == TypeKind.INVALID) return true;
				}
			}
		}

		return false;
	}
}

fn invalidType() => TypeValue(TypeKind.INVALID, 0, 0);

fn unitType() => TypeValue(TypeKind.UNIT, 0, 0);

fn boolType() => TypeValue(TypeKind.BOOL, 0, 0);

fn integerLiteralType() => TypeValue(TypeKind.INTEGER_LITERAL, 0, 0);

fn primitiveType(tokenKind: u32) => when (tokenKind) {
    TokenKind.UNIT.value -> unitType();
    TokenKind.BOOL.value -> boolType();
    TokenKind.I32.value -> TypeValue(TypeKind.I32, 0, 0);
    TokenKind.I64.value -> TypeValue(TypeKind.I64, 0, 0);
    TokenKind.U8.value -> TypeValue(TypeKind.U8, 0, 0);
    TokenKind.U32.value -> TypeValue(TypeKind.U32, 0, 0);
    TokenKind.U64.value -> TypeValue(TypeKind.U64, 0, 0);
    TokenKind.F32.value -> TypeValue(TypeKind.F32, 0, 0);
    TokenKind.F64.value -> TypeValue(TypeKind.F64, 0, 0);
    TokenKind.STR.value -> TypeValue(TypeKind.STR, 0, 0);
    else -> invalidType();
};

struct LocalInfo(
    name: u64, valueType: TypeValue, mutable: bool,
    storage: u64, moved: bool, autoDrop: bool
)

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
