fn main(): i32 {
    var bytes = byteBufferNew();
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

    var tokens = listNew<Token>(sizeof(Token));
    listAdd<Token>(tokens, Token(4, 10, 12));
    listAdd<Token>(tokens, Token(5, 12, 14));
    listAdd<Token>(tokens, Token(6, 14, 16));
    if (tokens.data[2].kind != 6) {
        return 3;
    }
    listFree<Token>(tokens);

    val expression = k_boot_alloc(1);
    var expressions = listNew<unit*>(sizeof(unit*));
    listAdd<unit*>(expressions, expression);
    if (expressions.data[0] != expression) {
        return 4;
    }
    listFree<unit*>(expressions);
    k_boot_free(expression);

    val text = k_boot_alloc(4) as u8*;
    var strings = listNew<StringRef>(sizeof(StringRef));
    listAdd<StringRef>(strings, StringRef(text, 4));
    if (strings.data[0].length != 4) {
        return 5;
    }
    listFree<StringRef>(strings);
    k_boot_free(text as unit*);

    val symbolValue = k_boot_alloc(1);
    var symbols = symbolTableNew();
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
