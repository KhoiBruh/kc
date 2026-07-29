module kbootstrap.types;

import kbootstrap.containers.ByteBuffer;
import kbootstrap.ast.AstNode;

struct TypeValue(kind: u32, name: u64, pointee: u32)

struct TypeValueList(
    data: TypeValue*, length: u64, capacity: u64)

fn typeValueListNew(): TypeValueList {
    return TypeValueList(
        k_boot_alloc(8 * sizeof(TypeValue)) as TypeValue*, 0, 8);
}

fn typeValueListAppend(var list: TypeValueList, value: TypeValue): u64 {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data =
            k_boot_alloc(capacity * sizeof(TypeValue)) as TypeValue*;
        var index: u64 = 0;
        while (index < list.length) {
            data[index] = list.data[index];
            index = index + 1;
        }
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    val index = list.length;
    list.data[index] = value;
    list.length = index + 1;
    return index;
}

fn typeValueListFree(list: TypeValueList) {
    k_boot_free(list.data as unit*);
}

fn invalidType(): TypeValue {
    return TypeValue(0, 0, 0);
}

fn unitType(): TypeValue {
    return TypeValue(1, 0, 0);
}

fn boolType(): TypeValue {
    return TypeValue(2, 0, 0);
}

fn integerLiteralType(): TypeValue {
    return TypeValue(11, 0, 0);
}

fn arrayType(element: TypeValue, size: u64): TypeValue {
    return TypeValue(
        19, element.name, element.kind + (size as u32) * 256);
}

fn arrayElement(type: TypeValue): TypeValue {
    return TypeValue(type.pointee % 256, type.name, 0);
}

fn arraySize(type: TypeValue): u64 {
    return (type.pointee / 256) as u64;
}

fn isFloatType(type: TypeValue): bool {
    if (type.kind == 17) return true;
    return type.kind == 18;
}

fn isIntegerType(type: TypeValue): bool {
    if (type.kind >= 3) return type.kind <= 7;
    return false;
}

fn integerTypeWidth(type: TypeValue): u32 {
    if (type.kind == 4) return 64;
    if (type.kind == 5) return 8;
    if (type.kind == 7) return 64;
    return 32;
}

fn integerTypeIsSigned(type: TypeValue): bool {
    if (type.kind == 3) return true;
    return type.kind == 4;
}

fn integerCastRequiresRangeCheck(source: TypeValue, target: TypeValue): bool {
    if (source.kind == target.kind) return false;
    val sourceWidth = integerTypeWidth(source);
    val targetWidth = integerTypeWidth(target);
    if (integerTypeIsSigned(source) == integerTypeIsSigned(target)) {
        return targetWidth < sourceWidth;
    }
    if (integerTypeIsSigned(source)) return true;
    return targetWidth <= sourceWidth;
}

fn integerImplicitlyWidens(source: TypeValue, target: TypeValue): bool {
    if (!isIntegerType(source)) return false;
    if (!isIntegerType(target)) return false;
    if (source.kind == target.kind) return false;
    if (integerTypeWidth(target) <= integerTypeWidth(source)) return false;
    if (integerTypeIsSigned(source) && !integerTypeIsSigned(target)) return false;
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
        if (isFloatType(expected)) return true;
    }
    if (expected.kind == 19) {
        if (actual.kind == 19) {
            if (arraySize(expected) == arraySize(actual)) {
                if (arrayElement(actual).kind == 0) return true;
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
struct LocalList(data: LocalInfo*, length: u64, capacity: u64)

fn localListNew() => LocalList(k_boot_alloc(8 * sizeof(LocalInfo)) as LocalInfo*, 0, 8);

fn localListGrow(var list: LocalList) {
    val capacity = list.capacity * 2;
    val data = k_boot_alloc(capacity * sizeof(LocalInfo)) as LocalInfo*;
    var index: u64 = 0;
    while (index < list.length) {
        data[index] = list.data[index];
        index = index + 1;
    }
    k_boot_free(list.data as unit*);
    list.data = data;
    list.capacity = capacity;
}

fn localListAppend(var list: LocalList, value: LocalInfo) {
    if (list.length == list.capacity) localListGrow(list);
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn localListFree(list: LocalList) => k_boot_free(list.data as unit*);

struct DeclarationInfo(name: u64, node: u64)
struct DeclarationList(data: DeclarationInfo*, length: u64, capacity: u64)

fn declarationListNew() => DeclarationList(k_boot_alloc(8 * sizeof(DeclarationInfo)) as DeclarationInfo*, 0, 8);

fn declarationListGrow(var list: DeclarationList) {
    val capacity = list.capacity * 2;
    val data = k_boot_alloc(capacity * sizeof(DeclarationInfo)) as DeclarationInfo*;
    var index: u64 = 0;
    while (index < list.length) {
        data[index] = list.data[index];
        index = index + 1;
    }
    k_boot_free(list.data as unit*);
    list.data = data;
    list.capacity = capacity;
}

fn declarationListAppend(
    var list: DeclarationList, value: DeclarationInfo) {
    if (list.length == list.capacity) declarationListGrow(list);
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn declarationListFree(list: DeclarationList) => k_boot_free(list.data as unit*);
