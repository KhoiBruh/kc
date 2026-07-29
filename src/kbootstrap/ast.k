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
    conversionKind: u32
)

struct AstList(data: AstNode*, length: u64, capacity: u64) {
    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(AstNode)) as AstNode*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, node: AstNode): u64 {
        if (self.length == self.capacity) self.grow();
        val index = self.length;
        self.data[index] = node;
        self.length++;
        return index;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn astListNew() => AstList(k_boot_alloc(4 * sizeof(AstNode)) as AstNode*, 0, 4);
