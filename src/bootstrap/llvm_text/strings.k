module bootstrap.llvm_text.strings;

import bootstrap.*;
import bootstrap.token.TokenKind;

fn appendPrivateStringPrefix(var buffer: StringBuilder) {
    buffer.append(" = private unnamed_addr constant [");
}

fn appendStringArrayPrefix(var buffer: StringBuilder) {
    buffer.append(" x i8] c\"");
}

fn appendStringTerminator(var buffer: StringBuilder) {
    buffer.append("\\00\"\n");
}

fn appendStringType(var buffer: StringBuilder) {
    buffer.append("{ ptr, i64, i64 }");
}

fn appendStringInsertPointer(var buffer: StringBuilder) {
    buffer.append(" { ptr, i64, i64 } undef, ptr @.ks");
}

fn appendIndexZero(var buffer: StringBuilder) {
    buffer.append(", 0\n");
}

fn appendSpacedStringType(var buffer: StringBuilder) {
    buffer.append(" { ptr, i64, i64 } ");
}

fn appendI64Prefix(var buffer: StringBuilder) {
    buffer.append(", i64 ");
}

fn appendIndexOne(var buffer: StringBuilder) {
    buffer.append(", 1\n");
}

fn appendStringCapacity(var buffer: StringBuilder) {
    buffer.append(", i64 0, 2\n");
}

fn appendExtractLengthAndPrint(var buffer: StringBuilder) {
    buffer.append(", 1\n  call void @k_std_print_bytes(ptr ");
}

fn appendCloseLine(var buffer: StringBuilder) {
    buffer.append(")\n");
}



fn hexDigit(value: u8): u8 {
    if (value < 10) return 48 + value;
    return 55 + value;
}

fn appendEscapedByte(var buffer: StringBuilder, value: u8) {
    if (value >= 32 && value <= 126 && value != 34 && value != 92) {
        buffer.add(value);
        return;
    }
    buffer.append("\\");
    buffer.add(hexDigit(value / 16));
    buffer.add(hexDigit(value % 16));
}

fn appendUtf8(var buffer: StringBuilder, codepoint: u32) {
    if (codepoint <= 127) { buffer.add(codepoint as u8); return; }
    if (codepoint <= 2047) {
        buffer.add((192 + codepoint / 64) as u8);
        buffer.add((128 + codepoint % 64) as u8);
        return;
    }
    if (codepoint <= 65535) {
        buffer.add((224 + codepoint / 4096) as u8);
        buffer.add((128 + (codepoint / 64) % 64) as u8);
        buffer.add((128 + codepoint % 64) as u8);
        return;
    }
    buffer.add((240 + codepoint / 262144) as u8);
    buffer.add((128 + (codepoint / 4096) % 64) as u8);
    buffer.add((128 + (codepoint / 64) % 64) as u8);
    buffer.add((128 + codepoint % 64) as u8);
}

fn decodeStringLiteral(source: Source, node: AstNode): StringBuilder {
    var result = StringBuilder.new();
    var offset = node.start + 1;
    while (offset + 1 < node.end) {
        var value = source.data[offset];
        if (value != 92) { result.add(value); offset++; continue; }
        offset++;
        value = source.data[offset];
        if (value == 110) result.add(10);
        else if (value == 114) result.add(13);
        else if (value == 116) result.add(9);
        else if (value == 48) result.add(0);
        else if (value == 117) {
            offset += 2;
            var codepoint: u32 = 0;
            while (source.data[offset] != 125) {
                val digit = source.data[offset];
                var numeric = (digit - 48) as u32;
                if (digit >= 65) numeric = (digit - 55) as u32;
                if (digit >= 97) numeric = (digit - 87) as u32;
                codepoint = codepoint * 16 + numeric;
                offset++;
            }
            appendUtf8(result, codepoint);
        } else result.add(value);
        offset++;
    }
    return result;
}

fn appendStringGlobal(var buffer: StringBuilder, source: Source, node: AstNode, root: u64) {
    var decoded = decodeStringLiteral(source, node);
    defer decoded.free();
    buffer.append("@.k");
    buffer.append("s"); appendDecimal(buffer, root);
    appendPrivateStringPrefix(buffer);
    appendDecimal(buffer, decoded.length + 1);
    appendStringArrayPrefix(buffer);
    for (index in 0..<decoded.length) appendEscapedByte(buffer, decoded.data[index]);
    appendStringTerminator(buffer);
}

fn emitOwnedStringLiteral(
    var buffer: StringBuilder,
    source: Source,
    node: AstNode,
    var counter: IrCounter): IrValue {
    var decoded = decodeStringLiteral(source, node);
    defer decoded.free();
    var capacity = decoded.length;
    if (capacity == 0) capacity = 1;
    val data = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, data); appendEquals(buffer);
    appendCall(buffer); buffer.append("ptr");
    appendFunctionOpen(buffer);
    buffer.append("k_std_alloc(");
    appendI64(buffer); buffer.append(" "); appendDecimal(buffer, capacity);
    buffer.append(")"); appendNewline(buffer);
    for (index in 0..<decoded.length) {
        val address = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, address); appendEquals(buffer);
        appendGetElementPtr(buffer); buffer.append(" ");
        buffer.append("i8, ptr ");
        buffer.append("%"); appendDecimal(buffer, data); buffer.append(", ");
        appendI64(buffer); buffer.append(" "); appendDecimal(buffer, index);
        appendNewline(buffer);
        appendStore(buffer); buffer.append("i8 ");
        appendDecimal(buffer, decoded.data[index]);
        appendPtr(buffer); appendDecimal(buffer, address);
        appendNewline(buffer);
    }
    var temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    appendInsertValue(buffer); appendSpacedStringType(buffer);
    buffer.append("undef, ptr ");
    buffer.append("%"); appendDecimal(buffer, data); appendIndexZero(buffer);
    temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    appendInsertValue(buffer); appendSpacedStringType(buffer);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
    appendI64Prefix(buffer); appendDecimal(buffer, decoded.length);
    appendIndexOne(buffer);
    temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    appendInsertValue(buffer); appendSpacedStringType(buffer);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
    appendI64Prefix(buffer); appendDecimal(buffer, capacity);
    buffer.append(", 2"); appendNewline(buffer);
    return IrValue(IrValueKind.Temporary, 0, 0, temporary, TypeKind.String.value, 0, 0);
}

