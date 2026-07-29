module kbootstrap.containers;

extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);
extern fn k_boot_live_allocations(): u64;
extern fn k_boot_stderr(data: u8*, length: u64);

struct ByteBuffer(data: u8*, length: u64, capacity: u64) {
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

fn byteBufferNew() => ByteBuffer(k_boot_alloc(2) as u8*, 0, 2);

struct TokenList(data: Token*, length: u64, capacity: u64) {
    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(Token)) as Token*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, value: Token) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn tokenListNew(): TokenList {
    val bytes = 2 * sizeof(Token);
    return TokenList(k_boot_alloc(bytes) as Token*, 0, 2);
}

struct ExprList(data: unit**, length: u64, capacity: u64) {
    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(unit*)) as unit**;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, value: unit*) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn exprListNew() => ExprList(k_boot_alloc(2 * sizeof(unit*)) as unit**, 0, 2);

struct StringRef(data: u8*, length: u64)
struct StringList(data: StringRef*, length: u64, capacity: u64) {
    fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(StringRef)) as StringRef*;
        for (i in 0..<self.length) data[i] = self.data[i];
        k_boot_free(self.data as unit*);
        self.data = data;
        self.capacity = capacity;
    }

    fn add(var self, value: StringRef) {
        if (self.length == self.capacity) self.grow();
        self.data[self.length] = value;
        self.length++;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn stringListNew() => StringList(k_boot_alloc(2 * sizeof(StringRef)) as StringRef*, 0, 2);

struct SymbolEntry(key: u64, value: unit*)
struct SymbolTable(data: SymbolEntry*, length: u64, capacity: u64) {
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

    fn free(val self) => k_boot_free(self.data as unit*);
}

fn symbolTableNew() => SymbolTable(k_boot_alloc(2 * sizeof(SymbolEntry)) as SymbolEntry*, 0, 2);
