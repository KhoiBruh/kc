module kbootstrap.containers;

extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);
extern fn k_boot_live_allocations(): u64;
extern fn k_boot_stderr(data: u8*, length: u64);

struct ByteBuffer(data: u8*, length: u64, capacity: u64)

fn byteBufferNew() => ByteBuffer(k_boot_alloc(2) as u8*, 0, 2);

fn byteBufferGrow(var buffer: ByteBuffer) {
    val newCapacity = buffer.capacity * 2;
    val newData = k_boot_alloc(newCapacity) as u8*;
    for (i in 0..<buffer.length) newData[i] = buffer.data[i];
    k_boot_free(buffer.data as unit*);
    buffer.data = newData;
    buffer.capacity = newCapacity;
}

fn byteBufferAppend(var buffer: ByteBuffer, val value: u8) {
    if (buffer.length == buffer.capacity) byteBufferGrow(buffer);
    buffer.data[buffer.length] = value;
    buffer.length = buffer.length + 1;
}

fn byteBufferFree(buffer: ByteBuffer) => k_boot_free(buffer.data as unit*);

struct TokenList(data: Token*, length: u64, capacity: u64)

fn tokenListNew(): TokenList {
    val bytes = 2 * sizeof(Token);
    return TokenList(k_boot_alloc(bytes) as Token*, 0, 2);
}

fn tokenListGrow(var list: TokenList) {
    val newCapacity = list.capacity * 2;
    val newData = k_boot_alloc(newCapacity * sizeof(Token)) as Token*;
    for (i in 0..<list.length) newData[i] = list.data[i];
    k_boot_free(list.data as unit*);
    list.data = newData;
    list.capacity = newCapacity;
}

fn tokenListAppend(var list: TokenList, val value: Token) {
    if (list.length == list.capacity) tokenListGrow(list);
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn tokenListFree(list: TokenList) => k_boot_free(list.data as unit*);

struct ExprList(data: unit**, length: u64, capacity: u64)

fn exprListNew() => ExprList(k_boot_alloc(2 * sizeof(unit*)) as unit**, 0, 2);

fn exprListGrow(var list: ExprList) {
    val newCapacity = list.capacity * 2;
    val newData = k_boot_alloc(newCapacity * sizeof(unit*)) as unit**;
    for (i in 0..<list.length) newData[i] = list.data[i];
    k_boot_free(list.data as unit*);
    list.data = newData;
    list.capacity = newCapacity;
}

fn exprListAppend(var list: ExprList, val value: unit*) {
    if (list.length == list.capacity) exprListGrow(list);
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn exprListFree(list: ExprList) => k_boot_free(list.data as unit*);

struct StringRef(data: u8*, length: u64)
struct StringList(data: StringRef*, length: u64, capacity: u64)

fn stringListNew() => StringList(k_boot_alloc(2 * sizeof(StringRef)) as StringRef*, 0, 2);

fn stringListGrow(var list: StringList) {
    val newCapacity = list.capacity * 2;
    val newData = k_boot_alloc(newCapacity * sizeof(StringRef)) as StringRef*;
    for (i in 0..<list.length) newData[i] = list.data[i];
    k_boot_free(list.data as unit*);
    list.data = newData;
    list.capacity = newCapacity;
}

fn stringListAppend(var list: StringList, val value: StringRef) {
    if (list.length == list.capacity) stringListGrow(list);
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn stringListFree(list: StringList) => k_boot_free(list.data as unit*);

struct SymbolEntry(key: u64, value: unit*)
struct SymbolTable(data: SymbolEntry*, length: u64, capacity: u64)

fn symbolTableNew() => SymbolTable(k_boot_alloc(2 * sizeof(SymbolEntry)) as SymbolEntry*, 0, 2);

fn symbolTableGrow(var table: SymbolTable) {
    val newCapacity = table.capacity * 2;
    val newData = k_boot_alloc(newCapacity * sizeof(SymbolEntry)) as SymbolEntry*;
    for (i in 0..<table.length) newData[i] = table.data[i];
    k_boot_free(table.data as unit*);
    table.data = newData;
    table.capacity = newCapacity;
}

fn symbolTableAppend(var table: SymbolTable, val entry: SymbolEntry) {
    if (table.length == table.capacity) symbolTableGrow(table);
    table.data[table.length] = entry;
    table.length = table.length + 1;
}

fn symbolTableFind(val table: SymbolTable, val key: u64): u64 {
    for (i in 0..<table.length) if (table.data[i].key == key) return i;
    return table.length;
}

fn symbolTableFree(table: SymbolTable) => k_boot_free(table.data as unit*);
