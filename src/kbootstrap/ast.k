module kbootstrap.ast;

import kbootstrap.containers.ByteBuffer;

struct AstNode(
    kind: u32,
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
    conversionKind: u32)

struct AstList(data: AstNode*, length: u64, capacity: u64)

fn astListNew(): AstList {
    return AstList(k_boot_alloc(4 * sizeof(AstNode)) as AstNode*, 0, 4);
}

fn astListGrow(var list: AstList) {
    val newCapacity = list.capacity * 2;
    val newData =
        k_boot_alloc(newCapacity * sizeof(AstNode)) as AstNode*;
    var index: u64 = 0;
    while (index < list.length) {
        newData[index] = list.data[index];
        index = index + 1;
    }
    k_boot_free(list.data as unit*);
    list.data = newData;
    list.capacity = newCapacity;
}

fn astListAppend(var list: AstList, val node: AstNode): u64 {
    if (list.length == list.capacity) {
        astListGrow(list);
    }
    val index = list.length;
    list.data[index] = node;
    list.length = index + 1;
    return index;
}

fn astListFree(list: AstList) {
    k_boot_free(list.data as unit*);
}
