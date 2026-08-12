fn main(): i32 {
    if (TokenKind.EndOfFile.value != 0) return 10;
    if (TokenKind.Identifier.value != 1) return 11;
    if (TokenKind.StringLiteral.value != 5) return 12;
    if (TokenKind.KwFn.value != 10) return 13;
    if (TokenKind.LeftParen.value != 50) return 14;
    if (TokenKind.Equal.value != 65) return 15;
    if (TokenKind.Range.value != 87) return 16;
    if (TokenKind.RangeExclusive.value != 88) return 17;
    if (TokenKind.RangeExclusiveStart.value != 93) return 18;
    if (TokenKind.RangeExclusiveBoth.value != 94) return 19;

    var bytes = ByteBuffer.new();
    bytes.append("");
    bytes.append("\u{7}\u{8}\u{9}");
    if (bytes.length != 3) {
        return 1;
    }
    if (bytes.data[2] != 9) {
        return 2;
    }
    bytes.free();

    var tokens = List<Token>.new();
    tokens.add(Token(TokenKind.CharLiteral, 10, 12));
    tokens.add(Token(TokenKind.StringLiteral, 12, 14));
    tokens.add(Token(TokenKind.KwVal, 14, 16));
    if (tokens.data[2].kind != TokenKind.KwVal) {
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

    {
        var builder = StringBuilder.new();
        val raw = k_boot_alloc(3) as u8*;
        raw[0] = 1;
        raw[1] = 2;
        raw[2] = 3;
        builder.appendBytes(slice(raw, 0));
        builder.appendBytes(slice(raw, 3));
        if (builder.length != 3) return 20;
        if (builder.data[2] != 3) return 21;
        k_boot_free(raw as unit*);
        builder.append("A ");
        builder.append("😀");
        var built = builder.toString();
        val view = (&built) as StringLayout*;
        if ((*view).length != 9) {
            return 9;
        }
        if ((*view).data[8] != 128) {
            return 10;
        }
    }
    if (k_boot_live_allocations() != 0) {
        return 8;
    }
    return 0;
}
