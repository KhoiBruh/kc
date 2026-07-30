fn main(): i32 {
    var bytes = ByteBuffer.new();
    bytes.add(7);
    bytes.add(8);
    bytes.add(9);
    if (bytes.length != 3) {
        return 1;
    }
    if (bytes.data[2] != 9) {
        return 2;
    }
    bytes.free();

    var tokens = List<Token>.new();
    tokens.add(Token(4, 10, 12));
    tokens.add(Token(5, 12, 14));
    tokens.add(Token(6, 14, 16));
    if (tokens.data[2].kind != 6) {
        return 3;
    }
    tokens.free();

    val expression = k_boot_alloc(1);
    var expressions = List<unit*>.new();
    expressions.add(expression);
    if (expressions.data[0] != expression) {
        return 4;
    }
    expressions.free();
    k_boot_free(expression);

    val text = k_boot_alloc(4) as u8*;
    var strings = List<StringRef>.new();
    strings.add(StringRef(text, 4));
    if (strings.data[0].length != 4) {
        return 5;
    }
    strings.free();
    k_boot_free(text as unit*);

    val symbolValue = k_boot_alloc(1);
    var symbols = SymbolTable.new();
    symbols.add(SymbolEntry(42, symbolValue));
    if (symbols.find(42) != 0) {
        return 6;
    }
    if (symbols.find(7) != symbols.length) {
        return 7;
    }
    symbols.free();
    k_boot_free(symbolValue);
    if (k_boot_live_allocations() != 0) {
        return 8;
    }
    return 0;
}
