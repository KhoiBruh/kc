module kbootstrap.containers;

import kbootstrap.list.k_boot_alloc;
import kbootstrap.list.k_boot_free;

extern fn k_boot_live_allocations(): u64;
extern fn k_boot_stderr(data: u8*, length: u64);

struct ByteBuffer(data: u8*, length: u64, capacity: u64) {

	fn new() => ByteBuffer(k_boot_alloc(2) as u8*, 0, 2);

    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity) as u8*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, value: u8) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

struct StringRef(data: u8*, length: u64)

struct SymbolEntry(key: u64, value: unit*)
struct SymbolTable(data: SymbolEntry*, length: u64, capacity: u64) {

	fn new() => SymbolTable(k_boot_alloc(2 * sizeof(SymbolEntry)) as SymbolEntry*, 0, 2);

    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(SymbolEntry)) as SymbolEntry*;
        for (i in 0..<self.length) data[i] = self.data[i];
        self.free();
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, entry: SymbolEntry) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = entry;
        self.length++;
    }

    fn find(val self, key: u64): u64 {
        for (i in 0..<self.length) if (self.data[i].key == key) return i;
        return self.length;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}
