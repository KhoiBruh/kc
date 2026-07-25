fn main(): i32 {
    var bytes = byteBufferNew();
    byteBufferAppend(bytes, 7);
    byteBufferAppend(bytes, 8);
    byteBufferAppend(bytes, 9);
    if (bytes.length != 3) {
        return 1;
    }
    if (bytes.data[2] != 9) {
        return 2;
    }
    byteBufferFree(bytes);

    var tokens = tokenListNew();
    tokenListAppend(tokens, Token(4, 10, 12));
    tokenListAppend(tokens, Token(5, 12, 14));
    tokenListAppend(tokens, Token(6, 14, 16));
    if (tokens.data[2].kind != 6) {
        return 3;
    }
    tokenListFree(tokens);

    val expression = k_boot_alloc(1);
    var expressions = exprListNew();
    exprListAppend(expressions, expression);
    if (expressions.data[0] != expression) {
        return 4;
    }
    exprListFree(expressions);
    k_boot_free(expression);

    val text = k_boot_alloc(4) as u8*;
    var strings = stringListNew();
    stringListAppend(strings, StringRef(text, 4));
    if (strings.data[0].length != 4) {
        return 5;
    }
    stringListFree(strings);
    k_boot_free(text as unit*);

    val symbolValue = k_boot_alloc(1);
    var symbols = symbolTableNew();
    symbolTableAppend(symbols, SymbolEntry(42, symbolValue));
    if (symbolTableFind(symbols, 42) != 0) {
        return 6;
    }
    if (symbolTableFind(symbols, 7) != symbols.length) {
        return 7;
    }
    symbolTableFree(symbols);
    k_boot_free(symbolValue);
    if (k_boot_live_allocations() != 0) {
        return 8;
    }
    return 0;
}
