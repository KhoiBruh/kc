module kbootstrap.types;

import kbootstrap.containers.ByteBuffer;
import kbootstrap.ast.AstNode;
import kbootstrap.list.List;

struct TypeValue(kind: u32, name: u64, pointee: u32) {

	fn array(val self, size: u64) => TypeValue(19, self.name, self.kind + (size as u32) * 256);

	fn arrayElement(val self) => TypeValue(self.pointee % 256, self.name, 0);

	fn arraySize(val self) => self.pointee / 256;

	fn isFloat(val self) => self.kind in 17..18;

	fn isInteger(val self) => self.kind in 3..7;

	fn isSigned(val self) => self.kind in 3..4;

	fn intWidth(val self) => when (self.kind) {
		5 -> 8;
		4, 7 -> 64;
		else -> 32;
	};
}

fn invalidType() => TypeValue(0, 0, 0);

fn unitType() => TypeValue(1, 0, 0);

fn boolType() => TypeValue(2, 0, 0);

fn integerLiteralType() => TypeValue(11, 0, 0);

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

fn typeEquals(left: TypeValue, right: TypeValue, genericArguments: List<TypeValue>): bool {
    if (left.kind != right.kind) return false;
    if (left.name != right.name) return false;
    if (left.kind == 8) {
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

fn typeAccepts(expected: TypeValue, actual: TypeValue, genericArguments: List<TypeValue>): bool {
    if (typeEquals(expected, actual, genericArguments)) return true;
    if (integerImplicitlyWidens(actual, expected)) return true;
    if (expected.kind == 15) {
        if (actual.kind == 16) return true;
        return typeEquals(
            TypeValue(expected.pointee, expected.name, 0), actual, genericArguments);
    }
    if (actual.kind == 11) {
        if (expected.kind >= 3) {
            if (expected.kind <= 7) return true;
        }
    }
    if (actual.kind == 18) {
        if (expected.isFloat()) return true;
    }
    if (expected.kind == 19) {
        if (actual.kind == 19) {
            if (expected.arraySize() == actual.arraySize()) {
                if (actual.arrayElement().kind == 0) return true;
            }
        }
    }
    return false;
}

fn primitiveType(tokenKind: u32) => when (tokenKind) {
    49 -> unitType();
    32 -> boolType();
    35 -> TypeValue(3, 0, 0);
    36 -> TypeValue(4, 0, 0);
    38 -> TypeValue(5, 0, 0);
    40 -> TypeValue(6, 0, 0);
    41 -> TypeValue(7, 0, 0);
    45 -> TypeValue(17, 0, 0);
    46 -> TypeValue(18, 0, 0);
    48 -> TypeValue(10, 0, 0);
    else -> invalidType();
};

struct LocalInfo(name: u64, valueType: TypeValue, mutable: bool, storage: u64)
fn localFind(locals: List<LocalInfo>, name: u64): u64 {
    for (index in locals.length>..0)
        if (locals.data[index].name == name) return index;
    return locals.length;
}

fn localFindFrom(locals: List<LocalInfo>, name: u64, start: u64): u64 {
    for (index in locals.length>..start)
        if (locals.data[index].name == name) return index;
    return locals.length;
}

struct DeclarationInfo(name: u64, node: u64)
fn declarationFind(declarations: List<DeclarationInfo>, name: u64): u64 {
    for (index in 0..<declarations.length)
        if (declarations.data[index].name == name) return index;
    return declarations.length;
}
