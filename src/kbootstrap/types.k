module kbootstrap.types;

import kbootstrap.containers.ByteBuffer;
import kbootstrap.ast.AstNode;

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

struct TypeValueList(data: TypeValue*, length: u64, capacity: u64) {

	fn add(var self, value: TypeValue): u64 {
        if (self.length == self.capacity) {
            val capacity = self.capacity * 2;
            val data = k_boot_alloc(capacity * sizeof(TypeValue)) as TypeValue*;
            for (i in 0..<self.length) data[i] = self.data[i];
            k_boot_free(self.data as unit*);
            self.data = data;
            self.capacity = capacity;
        }

        val index = self.length;
        self.data[index] = value;
        self.length = index + 1;
        return index;
    }

    fn free(var self) => k_boot_free(self.data as unit*);
}

fn typeValueListNew(): TypeValueList {
    return TypeValueList(
        k_boot_alloc(8 * sizeof(TypeValue)) as TypeValue*, 0, 8);
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

fn typeEquals(left: TypeValue, right: TypeValue, genericArguments: TypeValueList): bool {
    if (left.kind != right.kind) return false;
    if (left.name != right.name) return false;
    if (left.kind == 8) {
        val leftCount = left.pointee / 65536;
        val rightCount = right.pointee / 65536;
        if (leftCount != rightCount) return false;
        if (leftCount == 0) return true;
        val leftStart = left.pointee % 65536;
        val rightStart = right.pointee % 65536;
        var index: u32 = 0;
        while (index < leftCount) {
            val leftArg = genericArguments.data[leftStart as u64 + index as u64];
            val rightArg = genericArguments.data[rightStart as u64 + index as u64];
            if (!typeEquals(leftArg, rightArg, genericArguments)) {
                return false;
            }
            index = index + 1;
        }
        return true;
    }
    return left.pointee == right.pointee;
}

fn typeAccepts(expected: TypeValue, actual: TypeValue, genericArguments: TypeValueList): bool {
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
struct LocalList(data: LocalInfo*, length: u64, capacity: u64) {
    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(LocalInfo)) as LocalInfo*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, value: LocalInfo) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn find(val self, name: u64): u64 {
        for (index in self.length>..0)
            if (self.data[index].name == name) return index;
        return self.length;
    }

    fn findFrom(val self, name: u64, start: u64): u64 {
        for (index in self.length>..start)
            if (self.data[index].name == name) return index;
        return self.length;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn localListNew() => LocalList(k_boot_alloc(8 * sizeof(LocalInfo)) as LocalInfo*, 0, 8);

struct DeclarationInfo(name: u64, node: u64)
struct DeclarationList(data: DeclarationInfo*, length: u64, capacity: u64) {
    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(DeclarationInfo)) as DeclarationInfo*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, value: DeclarationInfo) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn find(val self, name: u64): u64 {
        for (index in 0..<self.length)
            if (self.data[index].name == name) return index;
        return self.length;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn declarationListNew() => DeclarationList(k_boot_alloc(8 * sizeof(DeclarationInfo)) as DeclarationInfo*, 0, 8);
