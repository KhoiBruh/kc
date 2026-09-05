module bootstrap.containers;

import bootstrap.heap.alloc;
import bootstrap.heap.free;
import bootstrap.heap.grow;

extern fn k_boot_live_allocations(): u64;
extern fn k_boot_stderr(data: u8*, length: u64);
extern fn k_boot_string_copy(data: u8*, length: u64, output: unit*);

struct ByteBuffer(data: u8*, length: u64, capacity: u64) {

	fn new() => ByteBuffer(alloc<u8>(2), 0, 2);

    fn grow(var self) {
        val capacity = self.capacity * 2;
        self.data = grow<u8>(self.data, self.length, capacity);
        self.capacity = capacity;
    }

    fn add(var self, value: u8) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn append(var self, val bytes: []u8) {
        for (byte in bytes) self.add(byte);
    }

    fn free(self) => free<u8>(self.data);
}

struct StringBuilder(data: u8*, length: u64, capacity: u64) {

    fn new() => StringBuilder(alloc<u8>(2), 0, 2);

    fn grow(var self) {
        val capacity = self.capacity * 2;
        self.data = grow<u8>(self.data, self.length, capacity);
        self.capacity = capacity;
    }

    fn add(var self, value: u8) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn appendBytes(var self, val bytes: []u8) {
        for (byte in bytes) self.add(byte);
    }

    fn append(var self, val text: str) {
        val bytes = text.bytes;
        for (value in bytes) self.add(value);
    }

    fn to_str(val self): str {
        var result = "";
        k_boot_string_copy(self.data, self.length, (&result) as unit*);
        return result;
    }

    fn free(self) => free<u8>(self.data);
}

struct StrLayout(data: u8*, length: u64, capacity: u64)
struct StringRef(data: u8*, length: u64)

struct SymbolEntry(key: u64, value: unit*)
struct SymbolTable(data: SymbolEntry*, length: u64, capacity: u64) {

	// SymbolTable stays on the raw k_boot_* ABI: nothing references it from
	// the entry graph yet, and kc0 lowers generic specializations even in
	// unreachable declarations ("type not supported by the LLVM backend").
	// Move these to heap.alloc/grow/free once it is reachable from main.
	fn new() => SymbolTable(k_boot_alloc(2 * sizeof(SymbolEntry)) as SymbolEntry*, 0, 2);

    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(SymbolEntry)) as SymbolEntry*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
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

    fn free(self) => k_boot_free(self.data as unit*);
}
