module kbootstrap.llvm_text;

import kbootstrap.*;

fn appendDecimal(var buffer: ByteBuffer, value: u64) {
    val digits = k_boot_alloc(20) as u8*;
    var remaining = value;
    var length: u64 = 0;
    if (remaining == 0) {
        byteBufferAppend(buffer, 48);
    } else {
        while (remaining > 0) {
            digits[length] = (remaining % 10) as u8 + 48;
            remaining = remaining / 10;
            length = length + 1;
        }
        while (length > 0) {
            length = length - 1;
            byteBufferAppend(buffer, digits[length]);
        }
    }
    k_boot_free(digits as unit*);
}

fn appendSource(
    var buffer: ByteBuffer, source: Source, start: u64, end: u64) {
    var offset = start;
    while (offset < end) {
        byteBufferAppend(buffer, source.data[offset]);
        offset = offset + 1;
    }
}

fn appendDefine(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 102);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
}

fn appendI32(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 51);
    byteBufferAppend(buffer, 50);
}

fn appendFunctionOpen(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 64);
}

fn appendEmptyParameters(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 40);
    byteBufferAppend(buffer, 41);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 123);
    byteBufferAppend(buffer, 10);
}

fn appendEntry(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 10);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 32);
}

fn appendReturnI32(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 32);
    appendI32(buffer);
    byteBufferAppend(buffer, 32);
}

fn appendFunctionClose(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 10);
    byteBufferAppend(buffer, 125);
    byteBufferAppend(buffer, 10);
}

fn appendValuePrefix(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 37);
}

fn appendEquals(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 61);
    byteBufferAppend(buffer, 32);
}

fn appendLoad(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 32);
}

fn appendStore(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
}

fn appendPtr(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 37);
}

fn appendAlloca(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 32);
}

fn appendCall(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 32);
}

fn appendPrintDeclaration(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 64);
    byteBufferAppend(buffer, 107);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 51);
    byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 40);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 51);
    byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 41);
    byteBufferAppend(buffer, 10);
    byteBufferAppend(buffer, 10);
    appendPrintBytesDeclaration(buffer);
}
fn appendPrintBytesDeclaration(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 64);
    byteBufferAppend(buffer, 107);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 40);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 41);
    byteBufferAppend(buffer, 10);
    byteBufferAppend(buffer, 10);
}

fn appendPrivateStringPrefix(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 61);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 91);
}

fn appendStringArrayPrefix(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 120);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 56);
    byteBufferAppend(buffer, 93);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 34);
}

fn appendStringTerminator(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 92);
    byteBufferAppend(buffer, 48);
    byteBufferAppend(buffer, 48);
    byteBufferAppend(buffer, 34);
    byteBufferAppend(buffer, 10);
}

fn appendStringType(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 123);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 125);
}

fn appendStringInsertPointer(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 123);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 125);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 102);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 64);
    byteBufferAppend(buffer, 46);
    byteBufferAppend(buffer, 107);
    byteBufferAppend(buffer, 115);
}

fn appendIndexZero(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 48);
    byteBufferAppend(buffer, 10);
}

fn appendSpacedStringType(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 123);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 125);
    byteBufferAppend(buffer, 32);
}

fn appendI64Prefix(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 32);
}

fn appendIndexOne(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 49);
    byteBufferAppend(buffer, 10);
}

fn appendStringCapacity(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 48);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 10);
}

fn appendExtractLengthAndPrint(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 49);
    byteBufferAppend(buffer, 10);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 64);
    byteBufferAppend(buffer, 107);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 40);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
}

fn appendCloseLine(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 41);
    byteBufferAppend(buffer, 10);
}



fn hexDigit(value: u8): u8 {
    if (value < 10) return 48 + value;
    return 55 + value;
}

fn appendEscapedByte(var buffer: ByteBuffer, value: u8) {
    if (value >= 32 && value <= 126 && value != 34 && value != 92) {
        byteBufferAppend(buffer, value);
        return;
    }
    byteBufferAppend(buffer, 92);
    byteBufferAppend(buffer, hexDigit(value / 16));
    byteBufferAppend(buffer, hexDigit(value % 16));
}

fn appendUtf8(var buffer: ByteBuffer, codepoint: u32) {
    if (codepoint <= 127) { byteBufferAppend(buffer, codepoint as u8); return; }
    if (codepoint <= 2047) {
        byteBufferAppend(buffer, (192 + codepoint / 64) as u8);
        byteBufferAppend(buffer, (128 + codepoint % 64) as u8);
        return;
    }
    if (codepoint <= 65535) {
        byteBufferAppend(buffer, (224 + codepoint / 4096) as u8);
        byteBufferAppend(buffer, (128 + (codepoint / 64) % 64) as u8);
        byteBufferAppend(buffer, (128 + codepoint % 64) as u8);
        return;
    }
    byteBufferAppend(buffer, (240 + codepoint / 262144) as u8);
    byteBufferAppend(buffer, (128 + (codepoint / 4096) % 64) as u8);
    byteBufferAppend(buffer, (128 + (codepoint / 64) % 64) as u8);
    byteBufferAppend(buffer, (128 + codepoint % 64) as u8);
}

fn decodeStringLiteral(source: Source, node: AstNode): ByteBuffer {
    var result = byteBufferNew();
    var offset = node.start + 1;
    while (offset + 1 < node.end) {
        var value = source.data[offset];
        if (value != 92) { byteBufferAppend(result, value); offset = offset + 1; continue; }
        offset = offset + 1;
        value = source.data[offset];
        if (value == 110) byteBufferAppend(result, 10);
        else if (value == 114) byteBufferAppend(result, 13);
        else if (value == 116) byteBufferAppend(result, 9);
        else if (value == 48) byteBufferAppend(result, 0);
        else if (value == 117) {
            offset = offset + 2;
            var codepoint: u32 = 0;
            while (source.data[offset] != 125) {
                val digit = source.data[offset];
                var numeric = (digit - 48) as u32;
                if (digit >= 65) numeric = (digit - 55) as u32;
                if (digit >= 97) numeric = (digit - 87) as u32;
                codepoint = codepoint * 16 + numeric;
                offset = offset + 1;
            }
            appendUtf8(result, codepoint);
        } else byteBufferAppend(result, value);
        offset = offset + 1;
    }
    return result;
}

fn appendStringGlobal(var buffer: ByteBuffer, source: Source, node: AstNode, root: u64) {
    var decoded = decodeStringLiteral(source, node);
    byteBufferAppend(buffer, 64); byteBufferAppend(buffer, 46); byteBufferAppend(buffer, 107);
    byteBufferAppend(buffer, 115); appendDecimal(buffer, root);
    appendPrivateStringPrefix(buffer);
    appendDecimal(buffer, decoded.length + 1);
    appendStringArrayPrefix(buffer);
    var index: u64 = 0;
    while (index < decoded.length) { appendEscapedByte(buffer, decoded.data[index]); index = index + 1; }
    appendStringTerminator(buffer);
    byteBufferFree(decoded);
}

fn appendPanicDeclaration(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 118); byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 64);
    byteBufferAppend(buffer, 107); byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 98); byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 95); byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 40); byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52); byteBufferAppend(buffer, 41);
    byteBufferAppend(buffer, 10); byteBufferAppend(buffer, 10);
}

fn appendModuleHeader(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 103);
    byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 61); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 34); byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 45); byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 58); byteBufferAppend(buffer, 119);
    byteBufferAppend(buffer, 45); byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 50); byteBufferAppend(buffer, 55);
    byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 51); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 58); byteBufferAppend(buffer, 51);
    byteBufferAppend(buffer, 50); byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 55); byteBufferAppend(buffer, 49);
    byteBufferAppend(buffer, 58); byteBufferAppend(buffer, 51);
    byteBufferAppend(buffer, 50); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 51); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 45); byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 50); byteBufferAppend(buffer, 55);
    byteBufferAppend(buffer, 50); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 54); byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 58); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52); byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 54); byteBufferAppend(buffer, 52);
    byteBufferAppend(buffer, 45); byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 49); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 56); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 49); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 56); byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 56);
    byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 49); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 56); byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 56);
    byteBufferAppend(buffer, 58); byteBufferAppend(buffer, 49);
    byteBufferAppend(buffer, 54); byteBufferAppend(buffer, 58);
    byteBufferAppend(buffer, 51); byteBufferAppend(buffer, 50);
    byteBufferAppend(buffer, 58); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52); byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 83); byteBufferAppend(buffer, 49);
    byteBufferAppend(buffer, 50); byteBufferAppend(buffer, 56);
    byteBufferAppend(buffer, 34); byteBufferAppend(buffer, 10);
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 103);
    byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 61); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 34); byteBufferAppend(buffer, 120);
    byteBufferAppend(buffer, 56); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 95); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52); byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 45); byteBufferAppend(buffer, 119);
    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 119); byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 45); byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 34);
    byteBufferAppend(buffer, 10); byteBufferAppend(buffer, 10);
}

fn sourceNodeIsPrint(source: Source, node: AstNode): bool {
    if (node.end - node.start != 5) return false;
    if (source.data[node.start] != 112) return false;
    if (source.data[node.start + 1] != 114) return false;
    if (source.data[node.start + 2] != 105) return false;
    if (source.data[node.start + 3] != 110) return false;
    return source.data[node.start + 4] == 116;
}

fn appendOperator(var buffer: ByteBuffer, kind: u32, typeKind: u32) {
    var floating = typeKind == 17;
    if (typeKind == 18) floating = true;
    if (floating) byteBufferAppend(buffer, 102);
    if (kind == 60) {
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 100);
        byteBufferAppend(buffer, 100);
    }
    if (kind == 61) {
        byteBufferAppend(buffer, 115);
        byteBufferAppend(buffer, 117);
        byteBufferAppend(buffer, 98);
    }
    if (kind == 62) {
        byteBufferAppend(buffer, 109);
        byteBufferAppend(buffer, 117);
        byteBufferAppend(buffer, 108);
    }
    if (kind == 63) {
        if (floating) {
            byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 118); return;
        }
        var unsigned = typeKind == 5;
        if (typeKind == 6) unsigned = true;
        if (typeKind == 7) unsigned = true;
        if (unsigned) {
            byteBufferAppend(buffer, 117);
        } else {
            byteBufferAppend(buffer, 115);
        }
        byteBufferAppend(buffer, 100);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 118);
    }
    if (kind == 64) {
        if (floating) {
            byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 101);
            byteBufferAppend(buffer, 109); return;
        }
        var unsigned = typeKind == 5;
        if (typeKind == 6) unsigned = true;
        if (typeKind == 7) unsigned = true;
        if (unsigned) {
            byteBufferAppend(buffer, 117);
        } else {
            byteBufferAppend(buffer, 115);
        }
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 109);
    }
}

fn appendNewline(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 10);
}

fn appendCastOpcode(var buffer: ByteBuffer, kind: u32) {
    when (kind) {
        1 -> byteBufferAppend(buffer, 115);
        2 -> byteBufferAppend(buffer, 122);
        else -> {
            byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114);
            byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 99);
            return;
        }
    }
    byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 120);
    byteBufferAppend(buffer, 116);
}

fn appendFloatCastOpcode(var buffer: ByteBuffer, kind: u32) {
    if (kind == 1) {
        byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 120);
        byteBufferAppend(buffer, 116); return;
    }
    if (kind == 2) {
        byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
        byteBufferAppend(buffer, 99); return;
    }
    if (kind == 3) byteBufferAppend(buffer, 115);
    if (kind == 4) byteBufferAppend(buffer, 117);
    var integerToFloat = kind == 3;
    if (kind == 4) integerToFloat = true;
    if (integerToFloat) {
        byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 102);
        byteBufferAppend(buffer, 112); return;
    }
    byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 111);
    if (kind == 5) {
        byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 105);
    } else {
        byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 105);
    }
}

fn appendFloatIntegerConstant(
    var buffer: ByteBuffer, negative: bool, magnitude: u64,
    appendSix: bool
) {
    if (negative) byteBufferAppend(buffer, 45);
    appendDecimal(buffer, magnitude);
    if (appendSix) byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 46); byteBufferAppend(buffer, 48);
}

fn appendFloatCastBound(
    var buffer: ByteBuffer, sourceKind: u32, targetKind: u32,
    lower: bool
) {
    if (lower) {
        if (targetKind == 3) {
            var magnitude: u64 = 2147483649;
            if (sourceKind == 17) magnitude = 2147483648;
            appendFloatIntegerConstant(buffer, true, magnitude, false);
            return;
        }
        if (targetKind == 4) {
            appendFloatIntegerConstant(
                buffer, true, 9223372036854775808, false);
            return;
        }
        appendFloatIntegerConstant(buffer, true, 1, false);
        return;
    }
    if (targetKind == 3) {
        appendFloatIntegerConstant(buffer, false, 2147483648, false);
    } else {
        if (targetKind == 4) {
            appendFloatIntegerConstant(
                buffer, false, 9223372036854775808, false);
        } else {
            if (targetKind == 5) {
                appendFloatIntegerConstant(buffer, false, 256, false);
            }
            if (targetKind == 6) {
                appendFloatIntegerConstant(buffer, false, 4294967296, false);
            }
            if (targetKind == 7) {
                appendFloatIntegerConstant(
                    buffer, false, 1844674407370955161, true);
            }
        }
    }
}

fn appendCastPanic(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 64); byteBufferAppend(buffer, 107);
    byteBufferAppend(buffer, 95); byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 40);
    byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 41);
    appendNewline(buffer);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 104); byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 98); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 101); appendNewline(buffer);
}

struct IrValue(
    kind: u32, start: u64, end: u64, temporary: u64,
    typeKind: u32, typeName: u64, typePointee: u32)
struct IrCounter(
    value: u64,
    block: u64,
    currentBlock: u64,
    continueBlock: u64,
    breakBlock: u64)

fn appendStructSpecializationSuffix(
    var buffer: ByteBuffer, arguments: TypeValueList,
    start: u64, count: u32) {
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 115);
    appendDecimal(buffer, count as u64);
    var index: u32 = 0;
    while (index < count) {
        val type = arguments.data[start + index as u64];
        byteBufferAppend(buffer, 95);
        appendDecimal(buffer, type.kind as u64);
        byteBufferAppend(buffer, 95);
        appendDecimal(buffer, type.name);
        byteBufferAppend(buffer, 95);
        appendDecimal(buffer, type.pointee as u64);
        index = index + 1;
    }
}

fn appendType(
    var buffer: ByteBuffer, genericArguments: TypeValueList,
    kind: u32, name: u64, pointee: u32) {
    if (kind == 1) {
        byteBufferAppend(buffer, 118);
        byteBufferAppend(buffer, 111);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 100);
    }
    if (kind == 2) {
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 49);
    }
    if (kind == 3) appendI32(buffer);
    if (kind == 4) {
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 54);
        byteBufferAppend(buffer, 52);
    }
    if (kind == 5) {
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 56);
    }
    if (kind == 6) appendI32(buffer);
    if (kind == 7) {
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 54);
        byteBufferAppend(buffer, 52);
    }
    if (kind == 8) {
        byteBufferAppend(buffer, 37);
        byteBufferAppend(buffer, 115);
        appendDecimal(buffer, name);
        val start = pointee % 65536;
        val count = pointee / 65536;
        if (count > 0) {
            appendStructSpecializationSuffix(buffer, genericArguments, start as u64, count);
        }
    }
    if (kind == 9) {
        byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 114);
    }
    if (kind == 10) {
        appendStringType(buffer);
    }
    if (kind == 17) {
        byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 116);
    }
    if (kind == 18) {
        byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 111);
        byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 98);
        byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 101);
    }
    if (kind == 11) appendI32(buffer);
    if (kind == 20) appendI32(buffer);
    if (kind == 13) {
        byteBufferAppend(buffer, 123);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 54);
        byteBufferAppend(buffer, 52);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 125);
    }
    if (kind == 15) {
        byteBufferAppend(buffer, 123);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 49);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        appendType(buffer, genericArguments, pointee, name, 0);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 125);
    }
    if (kind == 19) {
        byteBufferAppend(buffer, 91);
        appendDecimal(buffer, (pointee / 256) as u64);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 120);
        byteBufferAppend(buffer, 32);
        appendType(buffer, genericArguments, pointee % 256, name, 0);
        byteBufferAppend(buffer, 93);
    }
}

fn appendNodeType(var buffer: ByteBuffer, genericArguments: TypeValueList, node: AstNode) {
    appendType(
        buffer, genericArguments, node.typeKind, node.typeName, node.typePointee);
}

fn appendLocalPrefix(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 46);
}

fn appendI64(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 54);
    byteBufferAppend(buffer, 52);
}

fn appendGetElementPtr(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 103);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
}

fn appendInsertValue(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 101);
}

fn appendExtractValue(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 120);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 101);
}

fn appendUndef(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 102);
}

fn appendUnreachable(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 104); byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 98); byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 101);
}

fn appendSpecializationSuffix(
    var buffer: ByteBuffer, arguments: TypeValueList,
    start: u64, count: u32) {
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 95);
    byteBufferAppend(buffer, 103);
    appendDecimal(buffer, count as u64);
    var index: u32 = 0;
    while (index < count) {
        val type = arguments.data[start + index as u64];
        byteBufferAppend(buffer, 95);
        appendDecimal(buffer, type.kind as u64);
        byteBufferAppend(buffer, 95);
        appendDecimal(buffer, type.name);
        byteBufferAppend(buffer, 95);
        appendDecimal(buffer, type.pointee as u64);
        index = index + 1;
    }
}

fn declarationRoots(nodes: AstList): u64* {
    val programRoot = nodes.length - 1;
    val program = nodes.data[programRoot];
    val roots =
        k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
    var root = programRoot - 1;
    var remaining = program.aux;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return roots;
}

fn structRootByName(
    source: Source, nodes: AstList, name: u64): u64 {
    val program = nodes.data[nodes.length - 1];
    val roots = declarationRoots(nodes);
    var index: u32 = 0;
    var found = nodes.length;
    while (index < program.aux) {
        val root = roots[index as u64];
        val node = nodes.data[root];
        if (node.kind == 43) {
            val nameNode = nodes.data[node.subtreeStart];
            if (sourceHash(source, nameNode.start, nameNode.end) == name) {
                found = root;
            }
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
    return found;
}

fn functionRootByName(
    source: Source, nodes: AstList, name: u64): u64 {
    val program = nodes.data[nodes.length - 1];
    val roots = declarationRoots(nodes);
    var index: u32 = 0;
    var found = nodes.length;
    while (index < program.aux) {
        val root = roots[index as u64];
        val node = nodes.data[root];
        if (node.kind == 41) {
            val nameNode = nodes.data[node.subtreeStart];
            if (sourceHash(source, nameNode.start, nameNode.end) == name) {
                found = root;
            }
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
    return found;
}

fn emitterStructTypeParameterCount(structure: AstNode): u32 {
    return structure.aux / 65536;
}

fn emitterStructFieldCount(structure: AstNode): u32 {
    return structure.aux % 65536;
}

fn emitterStructMethodCount(structure: AstNode): u64 => structure.storage;

fn emitterRootBeforeStructMethods(nodes: AstList, structureRoot: u64): u64 {
    var root = structureRoot - 1;
    var remaining = emitterStructMethodCount(nodes.data[structureRoot]);
    while (remaining > 0) {
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn emitterStructTypeParameterRoot(
    source: Source, nodes: AstList, structureRoot: u64, position: u32): u64 {
    val structure = nodes.data[structureRoot];
    var root = emitterRootBeforeStructMethods(nodes, structureRoot);
    var fields = emitterStructFieldCount(structure);
    while (fields > 0) {
        root = nodes.data[root].subtreeStart - 1;
        fields = fields - 1;
    }
    var remaining = emitterStructTypeParameterCount(structure);
    while (remaining > position) {
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn emitterStructTypeParameterPosition(
    source: Source, nodes: AstList, structureRoot: u64, name: u64): u32 {
    val count = emitterStructTypeParameterCount(
        nodes.data[structureRoot]);
    var position: u32 = 1;
    while (position <= count) {
        val root = emitterStructTypeParameterRoot(
            source, nodes, structureRoot, position);
        val parameter = nodes.data[root];
        val nameNode = nodes.data[parameter.subtreeStart];
        if (sourceHash(source, nameNode.start, nameNode.end) == name) {
            return position - 1;
        }
        position = position + 1;
    }
    return count;
}

fn substituteStructEmitterType(
    source: Source, nodes: AstList, structureRoot: u64,
    pattern: TypeValue, arguments: TypeValueList,
    argumentStart: u64, count: u32): TypeValue {
    if (pattern.kind == 14) {
        val position = emitterStructTypeParameterPosition(
            source, nodes, structureRoot, pattern.name);
        if (position >= count) return invalidType();
        return arguments.data[argumentStart + position as u64];
    }
    if (pattern.kind == 15) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(pattern.pointee, pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(15, inner.name, inner.kind);
    }
    if (pattern.kind == 9) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(pattern.pointee, pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(9, inner.name, inner.kind);
    }
    if (pattern.kind == 13) {
        val inner = substituteStructEmitterType(
            source, nodes, structureRoot,
            TypeValue(pattern.pointee, pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(13, inner.name, inner.kind);
    }
    return pattern;
}

fn emitterFieldRootAt(
    nodes: AstList, structureRoot: u64, wanted: u32): u64 {
    val structure = nodes.data[structureRoot];
    var roots =
        k_boot_alloc((emitterStructFieldCount(structure) as u64) * sizeof(u64)) as u64*;
    var root = emitterRootBeforeStructMethods(nodes, structureRoot);
    var remaining = emitterStructFieldCount(structure);
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    val result = roots[wanted as u64];
    k_boot_free(roots as unit*);
    return result;
}

fn fieldIndexByName(
    source: Source, nodes: AstList, structureRoot: u64,
    nameNode: AstNode): u32 {
    val wanted = sourceHash(source, nameNode.start, nameNode.end);
    val structure = nodes.data[structureRoot];
    val fieldCount = emitterStructFieldCount(structure);
    var index: u32 = 0;
    while (index < fieldCount) {
        val field = nodes.data[emitterFieldRootAt(nodes, structureRoot, index)];
        val fieldName = nodes.data[field.subtreeStart];
        if (sourceHash(source, fieldName.start, fieldName.end) == wanted) {
            return index;
        }
        index = index + 1;
    }
    return fieldCount;
}

fn alignUp(value: u64, alignment: u64): u64 {
    return ((value + alignment - 1) / alignment) * alignment;
}

fn typeAlignment(
    source: Source, nodes: AstList, genericArguments: TypeValueList,
    kind: u32, name: u64, pointee: u32): u64 {
    if (kind == 2) return 1;
    if (kind == 5) return 1;
    if (kind == 3) return 4;
    if (kind == 6) return 4;
    if (kind == 11) return 4;
    if (kind == 20) return 4;
    if (kind == 17) return 4;
    if (kind == 4) return 8;
    if (kind == 7) return 8;
    if (kind == 9) return 8;
    if (kind == 10) return 24;
    if (kind == 18) return 8;
    if (kind == 13) return 8;
    if (kind == 19) {
        return typeAlignment(
            source, nodes, genericArguments,
            pointee % 256, name, 0);
    }
    if (kind == 8) {
        val structureRoot = structRootByName(source, nodes, name);
        val structure = nodes.data[structureRoot];
        val fieldCount = emitterStructFieldCount(structure);
        val start = pointee % 65536;
        val count = pointee / 65536;
        var alignment: u64 = 1;
        var index: u32 = 0;
        while (index < fieldCount) {
            val typeNode = nodes.data[
                emitterFieldRootAt(nodes, structureRoot, index) - 1];
            var fieldType = TypeValue(typeNode.typeKind, typeNode.typeName, typeNode.typePointee);
            if (count > 0) {
                fieldType = substituteStructEmitterType(
                    source, nodes, structureRoot, fieldType,
                    genericArguments, start as u64, count);
            }
            val fieldAlignment = typeAlignment(
                source, nodes, genericArguments, fieldType.kind,
                fieldType.name, fieldType.pointee);
            if (fieldAlignment > alignment) {
                alignment = fieldAlignment;
            }
            index = index + 1;
        }
        return alignment;
    }
    return 1;
}

fn typeSize(
    source: Source, nodes: AstList, genericArguments: TypeValueList,
    kind: u32, name: u64, pointee: u32): u64 {
    if (kind == 1) return 0;
    if (kind == 2) return 1;
    if (kind == 5) return 1;
    if (kind == 3) return 4;
    if (kind == 6) return 4;
    if (kind == 11) return 4;
    if (kind == 20) return 4;
    if (kind == 17) return 4;
    if (kind == 4) return 8;
    if (kind == 7) return 8;
    if (kind == 9) return 8;
    if (kind == 10) return 8;
    if (kind == 18) return 8;
    if (kind == 13) return 16;
    if (kind == 19) {
        val elementSize = typeSize(
            source, nodes, genericArguments,
            pointee % 256, name, 0);
        val count = (pointee / 256) as u64;
        return count * elementSize;
    }
    if (kind == 8) {
        val structureRoot = structRootByName(source, nodes, name);
        val structure = nodes.data[structureRoot];
        val fieldCount = emitterStructFieldCount(structure);
        val start = pointee % 65536;
        val count = pointee / 65536;
        var size: u64 = 0;
        var index: u32 = 0;
        while (index < fieldCount) {
            val typeNode = nodes.data[
                emitterFieldRootAt(nodes, structureRoot, index) - 1];
            var fieldType = TypeValue(typeNode.typeKind, typeNode.typeName, typeNode.typePointee);
            if (count > 0) {
                fieldType = substituteStructEmitterType(
                    source, nodes, structureRoot, fieldType,
                    genericArguments, start as u64, count);
            }
            val alignment = typeAlignment(
                source, nodes, genericArguments, fieldType.kind,
                fieldType.name, fieldType.pointee);
            size = alignUp(size, alignment);
            size = size + typeSize(
                source, nodes, genericArguments, fieldType.kind,
                fieldType.name, fieldType.pointee);
            index = index + 1;
        }
        return alignUp(
            size, typeAlignment(source, nodes, genericArguments, kind, name, pointee));
    }
    return 0;
}

fn appendIrValue(
    var buffer: ByteBuffer, source: Source, value: IrValue) {
    if (value.kind == 1) {
        appendSource(buffer, source, value.start, value.end);
    } else {
        if (value.kind == 4) {
            byteBufferAppend(buffer, 37);
            appendLocalPrefix(buffer);
            appendDecimal(buffer, value.temporary);
            return;
        }
        if (value.kind == 3) {
            appendDecimal(buffer, value.temporary);
            return;
        }
        if (value.kind == 5) {
            byteBufferAppend(buffer, 122); byteBufferAppend(buffer, 101);
            byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 111);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 116);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 97);
            byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 122); byteBufferAppend(buffer, 101);
            byteBufferAppend(buffer, 114);
            return;
        }
        byteBufferAppend(buffer, 37);
        appendDecimal(buffer, value.temporary);
    }
}

fn appendPointerValue(
    var buffer: ByteBuffer, source: Source, value: IrValue) {
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
    if (value.kind == 1) {
        byteBufferAppend(buffer, 37);
        appendSource(buffer, source, value.start, value.end);
    } else {
        appendIrValue(buffer, source, value);
    }
}

fn nextTemporary(var counter: IrCounter): u64 {
    val value = counter.value;
    counter.value = value + 1;
    return value;
}

fn emitImplicitIntegerWiden(
    var buffer: ByteBuffer, source: Source,
    genericArguments: TypeValueList, value: IrValue,
    targetKind: u32, targetName: u64, targetPointee: u32,
    var counter: IrCounter): IrValue {
    val sourceType = TypeValue(value.typeKind, value.typeName, value.typePointee);
    val targetType = TypeValue(targetKind, targetName, targetPointee);
    if (!integerImplicitlyWidens(sourceType, targetType)) return value;
    val temporary = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer);
    var opcode: u32 = 2;
    if (sourceType.isSigned()) opcode = 1;
    appendCastOpcode(buffer, opcode); byteBufferAppend(buffer, 32);
    appendType(
        buffer, genericArguments,
        value.typeKind, value.typeName, value.typePointee);
    byteBufferAppend(buffer, 32); appendIrValue(buffer, source, value);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 32);
    appendType(buffer, genericArguments, targetKind, targetName, targetPointee);
    appendNewline(buffer);
    return IrValue(
        2, 0, 0, temporary, targetKind, targetName, targetPointee);
}

fn nextBlock(var counter: IrCounter): u64 {
    val value = counter.block;
    counter.block = value + 1;
    return value;
}

fn appendBlockName(var buffer: ByteBuffer, block: u64) {
    byteBufferAppend(buffer, 98);
    appendDecimal(buffer, block);
}

fn appendBlockLabel(
    var buffer: ByteBuffer, var counter: IrCounter, block: u64) {
    appendBlockName(buffer, block);
    byteBufferAppend(buffer, 58);
    appendNewline(buffer);
    counter.currentBlock = block;
}

fn appendBlockReference(var buffer: ByteBuffer, block: u64) {
    byteBufferAppend(buffer, 37);
    if (block == 18446744073709551615) {
        byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 110);
        byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 121);
    } else {
        appendBlockName(buffer, block);
    }
}

fn appendBranch(var buffer: ByteBuffer, block: u64) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 37);
    appendBlockName(buffer, block);
    appendNewline(buffer);
}

fn appendConditionalBranch(
    var buffer: ByteBuffer, source: Source, condition: IrValue,
    trueBlock: u64, falseBlock: u64) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 49);
    byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, condition);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 37);
    appendBlockName(buffer, trueBlock);
    byteBufferAppend(buffer, 44);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 37);
    appendBlockName(buffer, falseBlock);
    appendNewline(buffer);
}

fn appendComparison(
    var buffer: ByteBuffer, kind: u32, typeKind: u32) {
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 32);
    if (kind == 79) {
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 113);
    }
    if (kind == 80) {
        byteBufferAppend(buffer, 110);
        byteBufferAppend(buffer, 101);
    }
    var unsigned = typeKind == 5;
    if (typeKind == 6) unsigned = true;
    if (typeKind == 7) unsigned = true;
    if (typeKind == 20) unsigned = true;
    if (kind == 66) {
        if (unsigned) {
            byteBufferAppend(buffer, 117);
        } else {
            byteBufferAppend(buffer, 115);
        }
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 116);
    }
    if (kind == 81) {
        if (unsigned) {
            byteBufferAppend(buffer, 117);
        } else {
            byteBufferAppend(buffer, 115);
        }
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 101);
    }
    if (kind == 67) {
        if (unsigned) {
            byteBufferAppend(buffer, 117);
        } else {
            byteBufferAppend(buffer, 115);
        }
        byteBufferAppend(buffer, 103);
        byteBufferAppend(buffer, 116);
    }
    if (kind == 82) {
        if (unsigned) {
            byteBufferAppend(buffer, 117);
        } else {
            byteBufferAppend(buffer, 115);
        }
        byteBufferAppend(buffer, 103);
        byteBufferAppend(buffer, 101);
    }
}

fn expressionChildBefore(nodes: AstList, root: u64): u64 {
    return nodes.data[root].subtreeStart - 1;
}

fn emitAddress(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    genericArguments: TypeValueList,
    root: u64,
    var counter: IrCounter): IrValue {
    val node = nodes.data[root];
    if (node.kind == 10) {
        return IrValue(
            4, node.start, node.end, node.storage,
            9, node.typeName, node.typeKind);
    }
    if (node.kind == 12) {
        if (node.aux == 62) {
            return emitExpression(
                buffer, source, nodes, genericArguments,
                root - 1, counter);
        }
    }
    if (node.kind == 17) {
        val objectRoot = root - 1;
        val objectNode = nodes.data[objectRoot];
        val objectAddress = emitAddress(
            buffer, source, nodes, genericArguments,
            objectRoot, counter);
        val structureRoot =
            structRootByName(source, nodes, objectNode.typeName);
        val fieldIndex = fieldIndexByName(
            source, nodes, structureRoot, node);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendGetElementPtr(buffer);
        byteBufferAppend(buffer, 32);
        appendType(buffer, genericArguments, 8, objectNode.typeName, objectNode.typePointee);
        appendPointerValue(buffer, source, objectAddress);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        appendI32(buffer);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 48);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        appendI32(buffer);
        byteBufferAppend(buffer, 32);
        appendDecimal(buffer, fieldIndex as u64);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary, 9,
            node.typeName, node.typeKind);
    }
    if (node.kind == 18) {
        val indexRoot = root - 1;
        val objectRoot = expressionChildBefore(nodes, indexRoot);
        val object = emitExpression(
            buffer, source, nodes, genericArguments,
            objectRoot, counter);
        val index = emitExpression(
            buffer, source, nodes, genericArguments,
            indexRoot, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendGetElementPtr(buffer);
        byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, node);
        appendPointerValue(buffer, source, object);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        appendType(
            buffer, genericArguments, index.typeKind, index.typeName, index.typePointee);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, index);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary, 9,
            node.typeName, node.typeKind);
    }
    return IrValue(0, 0, 0, 0, 0, 0, 0);
}

fn appendFloatRangeComparison(
    var buffer: ByteBuffer, source: Source,
    genericArguments: TypeValueList, value: IrValue,
    targetKind: u32, temporary: u64, lower: bool) {
    appendValuePrefix(buffer); appendDecimal(buffer, temporary);
    appendEquals(buffer);
    byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 99);
    byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 111);
    if (lower) {
        var inclusive = targetKind == 4;
        if (targetKind == 3) {
            if (value.typeKind == 17) inclusive = true;
        }
        byteBufferAppend(buffer, 103);
        if (inclusive) byteBufferAppend(buffer, 101);
        else byteBufferAppend(buffer, 116);
    } else {
        byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 116);
    }
    byteBufferAppend(buffer, 32);
    appendType(
        buffer, genericArguments,
        value.typeKind, value.typeName, value.typePointee);
    byteBufferAppend(buffer, 32); appendIrValue(buffer, source, value);
    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
    appendFloatCastBound(
        buffer, value.typeKind, targetKind, lower);
    appendNewline(buffer);
}

fn emitExpression(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    genericArguments: TypeValueList,
    root: u64,
    var counter: IrCounter): IrValue {
    val node = nodes.data[root];
    if (node.kind == 11) {
        if (node.typeKind == 16) {
            return IrValue(3, 0, 0, 0, 16, 0, 0);
        }
        if (node.typeKind == 10) {
            var decoded = decodeStringLiteral(source, node);
            var temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer); appendInsertValue(buffer);
            appendStringInsertPointer(buffer);
            appendDecimal(buffer, root); appendIndexZero(buffer);
            temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer); appendInsertValue(buffer);
            appendSpacedStringType(buffer);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
            appendI64Prefix(buffer); appendDecimal(buffer, decoded.length);
            appendIndexOne(buffer);
            temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary); appendEquals(buffer); appendInsertValue(buffer);
            appendSpacedStringType(buffer);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary - 1);
            appendStringCapacity(buffer);
            byteBufferFree(decoded);
            return IrValue(2, 0, 0, temporary, 10, 0, 0);
        }
        return IrValue(
            1, node.start, node.end, 0,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 25) {
        val thenCount = node.aux % 65536;
        val elseCount = node.aux / 65536;
        val elseValueRoot = root - 1;
        val elseRoots =
            k_boot_alloc((elseCount as u64) * sizeof(u64)) as u64*;
        var childRoot = nodes.data[elseValueRoot].subtreeStart - 1;
        var remaining = elseCount;
        while (remaining > 0) {
            elseRoots[remaining as u64 - 1] = childRoot;
            childRoot = nodes.data[childRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        val thenValueRoot = childRoot;
        val thenRoots =
            k_boot_alloc((thenCount as u64) * sizeof(u64)) as u64*;
        childRoot = nodes.data[thenValueRoot].subtreeStart - 1;
        remaining = thenCount;
        while (remaining > 0) {
            thenRoots[remaining as u64 - 1] = childRoot;
            childRoot = nodes.data[childRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        val condition = emitExpression(
            buffer, source, nodes, genericArguments, childRoot, counter);
        val thenBlock = nextBlock(counter);
        val elseBlock = nextBlock(counter);
        val mergeBlock = nextBlock(counter);
        appendConditionalBranch(
            buffer, source, condition, thenBlock, elseBlock);
        appendBlockLabel(buffer, counter, thenBlock);
        var index: u32 = 0;
        while (index < thenCount) {
            val statement = nodes.data[thenRoots[index as u64]];
            if (statement.kind == 33) {
                emitVariableAlloca(
                    buffer, genericArguments, nodes,
                    thenRoots[index as u64]);
            }
            index = index + 1;
        }
        index = 0;
        while (index < thenCount) {
            emitStatement(
                buffer, source, nodes, genericArguments,
                thenRoots[index as u64], counter);
            index = index + 1;
        }
        val thenValue = emitExpression(
            buffer, source, nodes, genericArguments, thenValueRoot, counter);
        val thenValueBlock = counter.currentBlock;
        appendBranch(buffer, mergeBlock);
        appendBlockLabel(buffer, counter, elseBlock);
        index = 0;
        while (index < elseCount) {
            val statement = nodes.data[elseRoots[index as u64]];
            if (statement.kind == 33) {
                emitVariableAlloca(
                    buffer, genericArguments, nodes,
                    elseRoots[index as u64]);
            }
            index = index + 1;
        }
        index = 0;
        while (index < elseCount) {
            emitStatement(
                buffer, source, nodes, genericArguments,
                elseRoots[index as u64], counter);
            index = index + 1;
        }
        val elseValue = emitExpression(
            buffer, source, nodes, genericArguments, elseValueRoot, counter);
        val elseValueBlock = counter.currentBlock;
        appendBranch(buffer, mergeBlock);
        appendBlockLabel(buffer, counter, mergeBlock);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, temporary);
        appendEquals(buffer);
        byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 104);
        byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, node);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 91);
        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, thenValue);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendBlockReference(buffer, thenValueBlock);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 93);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 91); byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, elseValue);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendBlockReference(buffer, elseValueBlock);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 93);
        appendNewline(buffer);
        k_boot_free(thenRoots as unit*);
        k_boot_free(elseRoots as unit*);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 23) {
        val branchCount = node.aux % 65536;
        val hasSubject = node.aux / 65536;
        val roots = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        val values =
            k_boot_alloc((branchCount as u64) * sizeof(IrValue)) as IrValue*;
        val blocks = k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
        var branchRoot = root - 1;
        var remaining = branchCount;
        while (remaining > 0) {
            roots[remaining as u64 - 1] = branchRoot;
            branchRoot = nodes.data[branchRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        var subject = IrValue(0, 0, 0, 0, 0, 0, 0);
        if (hasSubject == 1) {
            subject = emitExpression(
                buffer, source, nodes, genericArguments, branchRoot, counter);
        }
        val mergeBlock = nextBlock(counter);
        var hasElse = false;
        var index: u32 = 0;
        while (index < branchCount) {
            val branch = nodes.data[roots[index as u64]];
            val valueRoot = roots[index as u64] - 1;
            val statementCount = (branch.aux % 65536) / 2;
            val statementRoots =
                k_boot_alloc((statementCount as u64) * sizeof(u64)) as u64*;
            var beforeValue = nodes.data[valueRoot].subtreeStart - 1;
            var statementRemaining = statementCount;
            while (statementRemaining > 0) {
                statementRoots[statementRemaining as u64 - 1] = beforeValue;
                beforeValue = nodes.data[beforeValue].subtreeStart - 1;
                statementRemaining = statementRemaining - 1;
            }
            var statementIndex: u32 = 0;
            while (statementIndex < statementCount) {
                val statement = nodes.data[statementRoots[statementIndex as u64]];
                if (statement.kind == 33) {
                    emitVariableAlloca(
                        buffer, genericArguments, nodes,
                        statementRoots[statementIndex as u64]);
                }
                statementIndex = statementIndex + 1;
            }
            val bodyBlock = nextBlock(counter);
            var nextBlockValue = mergeBlock;
            if (branch.aux % 2 == 0) {
                nextBlockValue = nextBlock(counter);
                val patternCount = branch.aux / 65536;
                val patternRoots =
                    k_boot_alloc((patternCount as u64) * sizeof(u64)) as u64*;
                var patternRoot = beforeValue;
                var patternRemaining = patternCount;
                while (patternRemaining > 0) {
                    patternRoots[patternRemaining as u64 - 1] = patternRoot;
                    patternRoot = nodes.data[patternRoot].subtreeStart - 1;
                    patternRemaining = patternRemaining - 1;
                }
                var patternIndex: u32 = 0;
                while (patternIndex < patternCount) {
                    var condition = emitExpression(
                        buffer, source, nodes, genericArguments,
                        patternRoots[patternIndex as u64], counter);
                    if (hasSubject == 1) {
                        val compared = nextTemporary(counter);
                        appendValuePrefix(buffer); appendDecimal(buffer, compared);
                        appendEquals(buffer); appendComparison(buffer, 79, subject.typeKind);
                        byteBufferAppend(buffer, 32);
                        appendType(
                            buffer, genericArguments,
                            subject.typeKind, subject.typeName, subject.typePointee);
                        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, subject);
                        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
                        appendIrValue(buffer, source, condition); appendNewline(buffer);
                        condition = IrValue(2, 0, 0, compared, 2, 0, 0);
                    }
                    var missBlock = nextBlockValue;
                    if (patternIndex + 1 < patternCount) missBlock = nextBlock(counter);
                    appendConditionalBranch(
                        buffer, source, condition, bodyBlock, missBlock);
                    patternIndex = patternIndex + 1;
                    if (patternIndex < patternCount) {
                        appendBlockLabel(buffer, counter, missBlock);
                    }
                }
                k_boot_free(patternRoots as unit*);
            } else {
                hasElse = true;
                appendBranch(buffer, bodyBlock);
            }
            appendBlockLabel(buffer, counter, bodyBlock);
            statementIndex = 0;
            while (statementIndex < statementCount) {
                emitStatement(
                    buffer, source, nodes, genericArguments,
                    statementRoots[statementIndex as u64], counter);
                statementIndex = statementIndex + 1;
            }
            values[index as u64] = emitExpression(
                buffer, source, nodes, genericArguments, valueRoot, counter);
            blocks[index as u64] = counter.currentBlock;
            appendBranch(buffer, mergeBlock);
            if (branch.aux % 2 == 0) {
                appendBlockLabel(buffer, counter, nextBlockValue);
            }
            k_boot_free(statementRoots as unit*);
            index = index + 1;
        }
        if (!hasElse) {
            appendUnreachable(buffer); 
            appendNewline(buffer); 
        }
        appendBlockLabel(buffer, counter, mergeBlock);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, temporary);
        appendEquals(buffer);
        byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 104);
        byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, node);
        byteBufferAppend(buffer, 32);
        index = 0;
        while (index < branchCount) {
            if (index > 0) {
                byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            }
            byteBufferAppend(buffer, 91); byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, values[index as u64]);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendBlockReference(buffer, blocks[index as u64]);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 93);
            index = index + 1;
        }
        appendNewline(buffer);
        k_boot_free(blocks as unit*);
        k_boot_free(values as unit*);
        k_boot_free(roots as unit*);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 22) {
        if (node.aux == 0) {
            return IrValue(
                5, 0, 0, 0,
                node.typeKind, node.typeName, node.typePointee);
        }
        val roots =
            k_boot_alloc((node.aux as u64) * sizeof(u64)) as u64*;
        var childRoot = root - 1;
        var remaining = node.aux;
        while (remaining > 0) {
            roots[remaining as u64 - 1] = childRoot;
            childRoot = nodes.data[childRoot].subtreeStart - 1;
            remaining = remaining - 1;
        }
        var aggregate = IrValue(
            3, 0, 0, 0, node.typeKind, node.typeName, node.typePointee);
        var index: u32 = 0;
        while (index < node.aux) {
            val element = emitExpression(
                buffer, source, nodes, genericArguments,
                roots[index as u64], counter);
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer); appendInsertValue(buffer);
            appendNodeType(buffer, genericArguments, node);
            byteBufferAppend(buffer, 32);
            if (index == 0) {
                byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 102);
            } else {
                appendIrValue(buffer, source, aggregate);
            }
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendType(
                buffer, genericArguments,
                node.typePointee % 256, node.typeName, 0);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, element);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendDecimal(buffer, index as u64); appendNewline(buffer);
            aggregate = IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
            index = index + 1;
        }
        k_boot_free(roots as unit*);
        return aggregate;
    }
    if (node.kind == 12) {
        val operandRoot = root - 1;
        if (node.aux == 68) {
            return emitAddress(
                buffer, source, nodes, genericArguments,
                operandRoot, counter);
        }
        val operand = emitExpression(
            buffer, source, nodes, genericArguments,
            operandRoot, counter);
        if (node.aux == 62) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            appendLoad(buffer);
            appendNodeType(buffer, genericArguments, node);
            appendPointerValue(buffer, source, operand);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.aux == 61) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            if (TypeValue(node.typeKind, node.typeName, node.typePointee).isFloat()) {
                byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 103);
                byteBufferAppend(buffer, 32);
                appendNodeType(buffer, genericArguments, node);
                byteBufferAppend(buffer, 32);
            } else {
                byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 117);
                byteBufferAppend(buffer, 98); byteBufferAppend(buffer, 32);
                appendNodeType(buffer, genericArguments, node);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 48);
                byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            }
            appendIrValue(buffer, source, operand);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.aux == 73) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            byteBufferAppend(buffer, 120); byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 32);
            appendNodeType(buffer, genericArguments, node);
            byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, operand);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 101);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        return operand;
    }
    if (node.kind == 10) {
        var isConstant = node.aux == 1;
        if (node.storage < nodes.length) {
            if (nodes.data[node.storage].kind == 50) isConstant = true;
        }
        if (isConstant) {
            return emitExpression(
                buffer, source, nodes, genericArguments,
                node.storage - 1, counter);
        }
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendLoad(buffer);
        appendNodeType(buffer, genericArguments, node);
        appendPtr(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, node.storage);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 13) {
        val rightRoot = root - 1;
        val leftRoot = expressionChildBefore(nodes, rightRoot);
        if (node.aux == 18) {
            val range = nodes.data[rightRoot];
            val upperRoot = rightRoot - 1;
            val lowerRoot = expressionChildBefore(nodes, upperRoot);
            val subject = emitExpression(
                buffer, source, nodes, genericArguments, leftRoot, counter);
            val lower = emitExpression(
                buffer, source, nodes, genericArguments, lowerRoot, counter);
            val upper = emitExpression(
                buffer, source, nodes, genericArguments, upperRoot, counter);
            var lowerOperator: u32 = 82;
            if (range.aux == 93 || range.aux == 94) lowerOperator = 67;
            var upperOperator: u32 = 81;
            if (range.aux == 88 || range.aux == 94) upperOperator = 66;
            val lowerCheck = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, lowerCheck); appendEquals(buffer);
            appendComparison(buffer, lowerOperator, subject.typeKind);
            byteBufferAppend(buffer, 32);
            appendType(
                buffer, genericArguments,
                subject.typeKind, subject.typeName, subject.typePointee);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, subject);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, lower); appendNewline(buffer);
            val upperCheck = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, upperCheck); appendEquals(buffer);
            appendComparison(buffer, upperOperator, subject.typeKind);
            byteBufferAppend(buffer, 32);
            appendType(
                buffer, genericArguments,
                subject.typeKind, subject.typeName, subject.typePointee);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, subject);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, upper); appendNewline(buffer);
            val result = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, result); appendEquals(buffer);
            byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 49);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, lowerCheck); byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, upperCheck); appendNewline(buffer);
            return IrValue(2, 0, 0, result, 2, 0, 0);
        }
        var left = emitExpression(
            buffer, source, nodes, genericArguments,
            leftRoot, counter);
        var logical = node.aux == 83;
        if (node.aux == 84) logical = true;
        if (logical) {
            val leftBlock = counter.currentBlock;
            val rhsBlock = nextBlock(counter);
            val mergeBlock = nextBlock(counter);
            if (node.aux == 83) {
                appendConditionalBranch(
                    buffer, source, left, rhsBlock, mergeBlock);
            } else {
                appendConditionalBranch(
                    buffer, source, left, mergeBlock, rhsBlock);
            }
            appendBlockLabel(buffer, counter, rhsBlock);
            val right = emitExpression(
                buffer, source, nodes, genericArguments,
                rightRoot, counter);
            val rightBlock = counter.currentBlock;
            appendBranch(buffer, mergeBlock);
            appendBlockLabel(buffer, counter, mergeBlock);
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer);
            byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 104);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 49);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 91);
            if (node.aux == 83) byteBufferAppend(buffer, 48);
            else byteBufferAppend(buffer, 49);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendBlockReference(buffer, leftBlock);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 93);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 91);
            appendIrValue(buffer, source, right);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendBlockReference(buffer, rightBlock);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 93);
            appendNewline(buffer);
            return IrValue(2, 0, 0, temporary, 2, 0, 0);
        }
        var right = emitExpression(
            buffer, source, nodes, genericArguments,
            rightRoot, counter);
        var comparison = false;
        if (node.aux == 66) comparison = true;
        if (node.aux == 67) comparison = true;
        if (node.aux >= 79) {
            if (node.aux <= 82) comparison = true;
        }
        if (comparison) {
            val leftType = TypeValue(left.typeKind, left.typeName, left.typePointee);
            val rightType = TypeValue(right.typeKind, right.typeName, right.typePointee);
            if (integerImplicitlyWidens(leftType, rightType)) {
                left = emitImplicitIntegerWiden(
                    buffer, source, genericArguments, left,
                    right.typeKind, right.typeName, right.typePointee, counter);
            } else {
                if (integerImplicitlyWidens(rightType, leftType)) {
                    right = emitImplicitIntegerWiden(
                        buffer, source, genericArguments, right,
                        left.typeKind, left.typeName, left.typePointee, counter);
                }
            }
        } else {
            left = emitImplicitIntegerWiden(
                buffer, source, genericArguments, left,
                node.typeKind, node.typeName, node.typePointee, counter);
            right = emitImplicitIntegerWiden(
                buffer, source, genericArguments, right,
                node.typeKind, node.typeName, node.typePointee, counter);
        }
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        if (comparison) appendComparison(buffer, node.aux, left.typeKind);
        else appendOperator(buffer, node.aux, node.typeKind);
        byteBufferAppend(buffer, 32);
        if (comparison) {
            appendType(
                buffer, genericArguments, left.typeKind, left.typeName, left.typePointee);
        } else {
            appendNodeType(buffer, genericArguments, node);
        }
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, left);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, right);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 14) {
        val rightRoot = root - 1;
        val leftRoot = expressionChildBefore(nodes, rightRoot);
        var right = emitExpression(
            buffer, source, nodes, genericArguments,
            rightRoot, counter);
        val target = emitAddress(
            buffer, source, nodes, genericArguments,
            leftRoot, counter);
        val targetNode = nodes.data[leftRoot];
        right = emitImplicitIntegerWiden(
            buffer, source, genericArguments, right,
            targetNode.typeKind, targetNode.typeName,
            targetNode.typePointee, counter);
        if (node.aux != 65) {
            val loaded = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
            appendLoad(buffer);
            appendType(
                buffer, genericArguments, targetNode.typeKind,
                targetNode.typeName, targetNode.typePointee);
            appendPointerValue(buffer, source, target); appendNewline(buffer);
            val updated = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, updated); appendEquals(buffer);
            appendOperator(buffer, node.aux - 14, targetNode.typeKind);
            byteBufferAppend(buffer, 32);
            appendType(
                buffer, genericArguments, targetNode.typeKind,
                targetNode.typeName, targetNode.typePointee);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, loaded); byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, right);
            appendNewline(buffer);
            right = IrValue(
                2, 0, 0, updated, targetNode.typeKind,
                targetNode.typeName, targetNode.typePointee);
        }
        appendStore(buffer);
        appendType(
            buffer, genericArguments, targetNode.typeKind,
            targetNode.typeName, targetNode.typePointee);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, right);
        appendPointerValue(buffer, source, target);
        appendNewline(buffer);
        return right;
    }
    if (node.kind == 15) {
        val typeRoot = root - 1;
        val valueRoot = expressionChildBefore(nodes, typeRoot);
        val value = emitExpression(
            buffer, source, nodes, genericArguments,
            valueRoot, counter);
        if (node.typeKind == value.typeKind) return value;
        if (node.typeKind == 9) return value;
        if (value.typeKind == 9) return value;
        val sourceType = TypeValue(value.typeKind, value.typeName, value.typePointee);
        val targetType = TypeValue(node.typeKind, node.typeName, node.typePointee);
        if (node.conversionKind >= 5) {
            if (node.conversionKind == 6) {
                val lower = nextTemporary(counter);
                val upper = nextTemporary(counter);
                val check = nextTemporary(counter);
                appendFloatRangeComparison(
                    buffer, source, genericArguments, value,
                    targetType.kind, lower, true);
                appendFloatRangeComparison(
                    buffer, source, genericArguments, value,
                    targetType.kind, upper, false);
                appendValuePrefix(buffer); appendDecimal(buffer, check);
                appendEquals(buffer);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 49);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
                appendDecimal(buffer, lower); byteBufferAppend(buffer, 44);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
                appendDecimal(buffer, upper); appendNewline(buffer);
                val validBlock = nextBlock(counter);
                val panicBlock = nextBlock(counter);
                appendConditionalBranch(
                    buffer, source, IrValue(2, 0, 0, check, 2, 0, 0),
                    validBlock, panicBlock);
                appendBlockLabel(buffer, counter, panicBlock);
                appendCastPanic(buffer);
                appendBlockLabel(buffer, counter, validBlock);
            }
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer);
            var opcode: u32 = 1;
            if (sourceType.isInteger()) {
                opcode = 4;
                if (sourceType.isSigned()) opcode = 3;
            } else {
                if (targetType.isInteger()) {
                    opcode = 6;
                    if (targetType.isSigned()) opcode = 5;
                } else {
                    if (node.typeKind == 17) opcode = 2;
                }
            }
            appendFloatCastOpcode(buffer, opcode);
            byteBufferAppend(buffer, 32);
            appendType(
                buffer, genericArguments,
                value.typeKind, value.typeName, value.typePointee);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, value);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 116);
            byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 32);
            appendNodeType(buffer, genericArguments, node);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        val sourceWidth = sourceType.intWidth();
        val targetWidth = targetType.intWidth();
        var converted = IrValue(
            value.kind, value.start, value.end, value.temporary,
            node.typeKind, node.typeName, node.typePointee);
        if (sourceWidth != targetWidth) {
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, temporary);
            appendEquals(buffer);
            var opcode: u32 = 3;
            if (targetWidth > sourceWidth) {
                opcode = 2;
                if (sourceType.isSigned()) opcode = 1;
            }
            appendCastOpcode(buffer, opcode);
            byteBufferAppend(buffer, 32);
            appendType(
                buffer, genericArguments, value.typeKind,
                value.typeName, value.typePointee);
            byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, value);
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 116);
            byteBufferAppend(buffer, 111);
            byteBufferAppend(buffer, 32);
            appendNodeType(buffer, genericArguments, node);
            appendNewline(buffer);
            converted = IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        if (node.conversionKind == 4) {
            var check: u64 = 0;
            if (sourceWidth != targetWidth) {
                val roundTrip = nextTemporary(counter);
                check = nextTemporary(counter);
                appendValuePrefix(buffer); appendDecimal(buffer, roundTrip);
                appendEquals(buffer);
                var reverseOpcode: u32 = 2;
                if (targetType.isSigned()) reverseOpcode = 1;
                appendCastOpcode(buffer, reverseOpcode);
                byteBufferAppend(buffer, 32);
                appendNodeType(buffer, genericArguments, node);
                byteBufferAppend(buffer, 32);
                appendIrValue(buffer, source, converted);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 32);
                appendType(
                    buffer, genericArguments, value.typeKind,
                    value.typeName, value.typePointee);
                appendNewline(buffer);
                appendValuePrefix(buffer); appendDecimal(buffer, check);
                appendEquals(buffer);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 112);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 113); byteBufferAppend(buffer, 32);
                appendType(
                    buffer, genericArguments, value.typeKind,
                    value.typeName, value.typePointee);
                byteBufferAppend(buffer, 32); appendIrValue(buffer, source, value);
                byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 37); appendDecimal(buffer, roundTrip);
                appendNewline(buffer);
            } else {
                check = nextTemporary(counter);
                appendValuePrefix(buffer); appendDecimal(buffer, check);
                appendEquals(buffer);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 112);
                byteBufferAppend(buffer, 32);
                var sourceSigned = sourceType.isSigned();
                if (sourceSigned) {
                    byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 103);
                    byteBufferAppend(buffer, 101);
                } else {
                    byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 108);
                    byteBufferAppend(buffer, 101);
                }
                byteBufferAppend(buffer, 32);
                appendType(
                    buffer, genericArguments, value.typeKind,
                    value.typeName, value.typePointee);
                byteBufferAppend(buffer, 32); appendIrValue(buffer, source, value);
                byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
                if (sourceSigned) {
                    byteBufferAppend(buffer, 48);
                } else {
                    if (sourceWidth == 32) appendDecimal(buffer, 2147483647);
                    else appendDecimal(buffer, 9223372036854775807);
                }
                appendNewline(buffer);
            }
            val validBlock = nextBlock(counter);
            val panicBlock = nextBlock(counter);
            appendConditionalBranch(
                buffer, source, IrValue(2, 0, 0, check, 2, 0, 0),
                validBlock, panicBlock);
            appendBlockLabel(buffer, counter, panicBlock);
            appendCastPanic(buffer);
            appendBlockLabel(buffer, counter, validBlock);
        }
        return converted;
    }
    if (node.kind == 17) {
        if (node.typeKind == 20) {
            return IrValue(3, 0, 0, node.storage, 20, node.typeName, 0);
        }
        val objectRoot = root - 1;
        val objectNode = nodes.data[objectRoot];
        val structureRoot =
            structRootByName(
                source, nodes, objectNode.typeName);
        val structure = nodes.data[structureRoot];
        val start = objectNode.typePointee % 65536;
        val count = objectNode.typePointee / 65536;
        
        var addressable = objectNode.kind == 10;
        if (objectNode.kind == 17) addressable = true;
        if (objectNode.kind == 18) addressable = true;
        if (objectNode.kind == 12) {
            if (objectNode.aux == 62) addressable = true;
        }
        if (!addressable) {
            val object = emitExpression(
                buffer, source, nodes, genericArguments,
                objectRoot, counter);
            val fieldIndex = fieldIndexByName(
                source, nodes, structureRoot, node);
            val extracted = nextTemporary(counter);
            appendValuePrefix(buffer);
            appendDecimal(buffer, extracted);
            appendEquals(buffer);
            appendExtractValue(buffer);
            byteBufferAppend(buffer, 32);
            appendType(buffer, genericArguments, 8, objectNode.typeName, objectNode.typePointee);
            byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, object);
            byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32);
            appendDecimal(buffer, fieldIndex as u64);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, extracted,
                node.typeKind, node.typeName, node.typePointee);
        }
        val address = emitAddress(
            buffer, source, nodes, genericArguments, root, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendLoad(buffer);
        appendNodeType(buffer, genericArguments, node);
        appendPointerValue(buffer, source, address);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 18) {
        val indexRoot = root - 1;
        val objectRoot = expressionChildBefore(nodes, indexRoot);
        val objectNode = nodes.data[objectRoot];
        var constantArray = false;
        if (objectNode.kind == 10) {
            if (objectNode.storage < nodes.length) {
                if (nodes.data[objectNode.storage].kind == 50) constantArray = true;
            }
        }
        var constantIndex = constantArray;
        if (nodes.data[indexRoot].kind != 11) constantIndex = false;
        if (constantIndex) {
            val object = emitExpression(
                buffer, source, nodes, genericArguments,
                objectRoot, counter);
            val temporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, temporary);
            appendEquals(buffer); appendExtractValue(buffer);
            appendType(
                buffer, genericArguments,
                object.typeKind, object.typeName, object.typePointee);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, object);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            appendSource(
                buffer, source,
                nodes.data[indexRoot].start, nodes.data[indexRoot].end);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, temporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        val address = emitAddress(
            buffer, source, nodes, genericArguments, root, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        appendLoad(buffer);
        appendNodeType(buffer, genericArguments, node);
        appendPointerValue(buffer, source, address);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 19) {
        if (node.aux == 91 || node.aux == 92) {
            val valueRoot = root - 1;
            val address = emitAddress(
                buffer, source, nodes, genericArguments, valueRoot, counter);
            val loaded = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
            appendLoad(buffer); appendNodeType(buffer, genericArguments, node);
            appendPointerValue(buffer, source, address); appendNewline(buffer);
            val updated = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, updated); appendEquals(buffer);
            var operatorKind: u32 = 60;
            if (node.aux == 92) operatorKind = 61;
            appendOperator(buffer, operatorKind, node.typeKind);
            byteBufferAppend(buffer, 32); appendNodeType(buffer, genericArguments, node);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, loaded); byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 49);
            if (TypeValue(node.typeKind, node.typeName, node.typePointee).isFloat()) {
                byteBufferAppend(buffer, 46);
                byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 48);
                byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 48);
                byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 48);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 43);
                byteBufferAppend(buffer, 48); byteBufferAppend(buffer, 48);
            }
            appendNewline(buffer);
            appendStore(buffer); appendNodeType(buffer, genericArguments, node);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, updated); appendPointerValue(buffer, source, address);
            appendNewline(buffer);
            return IrValue(
                2, 0, 0, updated,
                node.typeKind, node.typeName, node.typePointee);
        }
        val operand = emitExpression(
            buffer, source, nodes, genericArguments,
            root - 1, counter);
        val hasValue = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, hasValue);
        appendEquals(buffer);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 120);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 99);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 118);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 117);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 32);
        appendType(
            buffer, genericArguments, operand.typeKind, operand.typeName, operand.typePointee);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, operand);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 48);
        appendNewline(buffer);
        val validBlock = nextBlock(counter);
        val panicBlock = nextBlock(counter);
        appendConditionalBranch(
            buffer, source,
            IrValue(2, 0, 0, hasValue, 2, 0, 0),
            validBlock, panicBlock);
        appendBlockLabel(buffer, counter, panicBlock);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 99);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 118);
        byteBufferAppend(buffer, 111);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 100);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 64);
        byteBufferAppend(buffer, 107);
        byteBufferAppend(buffer, 95);
        byteBufferAppend(buffer, 98);
        byteBufferAppend(buffer, 111);
        byteBufferAppend(buffer, 111);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 95);
        byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 110);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 99);
        byteBufferAppend(buffer, 40);
        byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 110);
        byteBufferAppend(buffer, 117);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 54);
        byteBufferAppend(buffer, 52);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 48);
        byteBufferAppend(buffer, 41);
        appendNewline(buffer);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 117);
        byteBufferAppend(buffer, 110);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 99);
        byteBufferAppend(buffer, 104);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 98);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 101);
        appendNewline(buffer);
        appendBlockLabel(buffer, counter, validBlock);
        val value = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, value);
        appendEquals(buffer);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 120);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 99);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 118);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 117);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 32);
        appendType(
            buffer, genericArguments, operand.typeKind, operand.typeName, operand.typePointee);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, operand);
        byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 49);
        appendNewline(buffer);
        return IrValue(
            2, 0, 0, value,
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 21) {
        val typeNode = nodes.data[root - 1];
        return IrValue(
            3, 0, 0,
            typeSize(
                source, nodes, genericArguments, typeNode.typeKind,
                typeNode.typeName, typeNode.typePointee),
            node.typeKind, node.typeName, node.typePointee);
    }
    if (node.kind == 16) {
        var argumentCount = node.aux % 65536;
        val explicitTypeCount = node.aux / 65536;
        val arguments =
            k_boot_alloc(
                ((argumentCount + 1) as u64) * sizeof(u64)) as u64*;
        var cursor = root - 1;
        var remaining = argumentCount;
        while (remaining > 0) {
            arguments[remaining as u64 - 1] = cursor;
            cursor = expressionChildBefore(nodes, cursor);
            remaining = remaining - 1;
        }
        remaining = explicitTypeCount;
        while (remaining > 0) {
            cursor = expressionChildBefore(nodes, cursor);
            remaining = remaining - 1;
        }
        val callee = nodes.data[cursor];
        val isMethod = callee.kind == 17;
        if (isMethod) {
            remaining = argumentCount;
            while (remaining > 0) {
                arguments[remaining as u64] = arguments[remaining as u64 - 1];
                remaining = remaining - 1;
            }
            arguments[0] = cursor - 1;
            argumentCount = argumentCount + 1;
        }
        val calleeHash =
            sourceHash(source, callee.start, callee.end);
        var functionRoot = functionRootByName(source, nodes, calleeHash);
        if (isMethod) functionRoot = node.storage;
        val values =
            k_boot_alloc(
                (argumentCount as u64) * sizeof(IrValue)) as IrValue*;
        var index: u32 = 0;
        while (index < argumentCount) {
            var byReference = false;
            if (functionRoot != nodes.length) {
                val parameter = nodes.data[
                    parameterRoot(
                        nodes, functionRoot, index + 1)];
                if (parameter.aux == 2) byReference = true;
            }
            if (byReference) {
                values[index as u64] = emitAddress(
                    buffer, source, nodes, genericArguments,
                    arguments[index as u64], counter);
            } else {
                values[index as u64] = emitExpression(
                    buffer, source, nodes, genericArguments,
                    arguments[index as u64], counter);
                if (functionRoot != nodes.length) {
                    val parameterType = nodes.data[
                        parameterRoot(nodes, functionRoot, index + 1) - 1];
                    val concreteParameter = substituteEmitterType(
                        source, nodes, functionRoot,
                        TypeValue(
                            parameterType.typeKind,
                            parameterType.typeName,
                            parameterType.typePointee),
                        genericArguments,
                        node.genericArgumentStart,
                        node.genericArgumentCount);
                    values[index as u64] = emitImplicitIntegerWiden(
                        buffer, source, genericArguments,
                        values[index as u64], concreteParameter.kind,
                        concreteParameter.name, concreteParameter.pointee,
                        counter);
                }
            }
            index = index + 1;
        }
        if (node.typeKind == 8) {
        if (functionRoot == nodes.length) {
            val structureRoot =
                structRootByName(source, nodes, node.typeName);
            val structure = nodes.data[structureRoot];
            val start = node.typePointee % 65536;
            val count = node.typePointee / 65536;
            var aggregateTemporary: u64 = 0;
            index = 0;
            while (index < argumentCount) {
                aggregateTemporary = nextTemporary(counter);
                appendValuePrefix(buffer);
                appendDecimal(buffer, aggregateTemporary);
                appendEquals(buffer);
                appendInsertValue(buffer);
                byteBufferAppend(buffer, 32);
                appendNodeType(buffer, genericArguments, node);
                byteBufferAppend(buffer, 32);
                if (index == 0) {
                    appendUndef(buffer);
                } else {
                    byteBufferAppend(buffer, 37);
                    appendDecimal(buffer, aggregateTemporary - 1);
                }
                byteBufferAppend(buffer, 44);
                byteBufferAppend(buffer, 32);
                
                val fieldRoot = fieldRootAt(nodes, structureRoot, index);
                val fieldTypeNode = nodes.data[fieldRoot - 1];
                var fieldType = TypeValue(fieldTypeNode.typeKind, fieldTypeNode.typeName, fieldTypeNode.typePointee);
                if (count > 0) {
                    fieldType = substituteStructEmitterType(
                        source, nodes, structureRoot, fieldType,
                        genericArguments, start as u64, count);
                }
                appendType(
                    buffer, genericArguments,
                    fieldType.kind, fieldType.name, fieldType.pointee);
                
                byteBufferAppend(buffer, 32);
                appendIrValue(
                    buffer, source, values[index as u64]);
                byteBufferAppend(buffer, 44);
                byteBufferAppend(buffer, 32);
                appendDecimal(buffer, index as u64);
                appendNewline(buffer);
                index = index + 1;
            }
            k_boot_free(values as unit*);
            k_boot_free(arguments as unit*);
            return IrValue(
                2, 0, 0, aggregateTemporary,
                node.typeKind, node.typeName, node.typePointee);
        }
        }
        val isPrint = sourceNodeIsPrint(source, callee);
        if (isPrint && values[0].typeKind == 10) {
            val dataTemporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary); appendEquals(buffer); appendExtractValue(buffer);
            appendSpacedStringType(buffer); appendIrValue(buffer, source, values[0]);
            appendIndexZero(buffer);
            val lengthTemporary = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary); appendEquals(buffer); appendExtractValue(buffer);
            appendSpacedStringType(buffer); appendIrValue(buffer, source, values[0]);
            appendExtractLengthAndPrint(buffer);
            appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary);
            appendI64Prefix(buffer); appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary);
            appendCloseLine(buffer);
            k_boot_free(values as unit*); k_boot_free(arguments as unit*);
            return IrValue(3, 0, 0, 0, 1, 0, 0);
        }
        var temporary: u64 = 0;
        if (isPrint) {
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 32);
            appendCall(buffer);
            byteBufferAppend(buffer, 118);
            byteBufferAppend(buffer, 111);
            byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 100);
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 64);
            byteBufferAppend(buffer, 107);
            byteBufferAppend(buffer, 95);
            byteBufferAppend(buffer, 115);
            byteBufferAppend(buffer, 116);
            byteBufferAppend(buffer, 100);
            byteBufferAppend(buffer, 95);
            byteBufferAppend(buffer, 112);
            byteBufferAppend(buffer, 114);
            byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 116);
            byteBufferAppend(buffer, 95);
            byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 51);
            byteBufferAppend(buffer, 50);
        } else {
            if (node.typeKind != 1) {
                temporary = nextTemporary(counter);
                appendValuePrefix(buffer);
                appendDecimal(buffer, temporary);
                appendEquals(buffer);
            } else {
                byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 32);
            }
            appendCall(buffer);
            appendNodeType(buffer, genericArguments, node);
            appendFunctionOpen(buffer);
            if (isMethod) {
                val ownerType = nodes.data[arguments[0]].typeName;
                val ownerRoot = structRootByName(source, nodes, ownerType);
                val ownerName = nodes.data[nodes.data[ownerRoot].subtreeStart];
                appendSource(buffer, source, ownerName.start, ownerName.end);
                byteBufferAppend(buffer, 46);
            }
            appendSource(buffer, source, callee.start, callee.end);
            if (functionRoot != nodes.length) {
                if (functionTypeParameterCount(
                        nodes.data[functionRoot]) > 0) {
                    appendSpecializationSuffix(
                        buffer, genericArguments,
                        node.genericArgumentStart,
                        node.genericArgumentCount);
                }
            }
        }
        byteBufferAppend(buffer, 40);
        index = 0;
        while (index < argumentCount) {
            if (index > 0) {
                byteBufferAppend(buffer, 44);
                byteBufferAppend(buffer, 32);
            }
            if (functionRoot != nodes.length) {
                val callParameter = nodes.data[
                    parameterRoot(
                        nodes, functionRoot, index + 1)];
                if (callParameter.aux == 2) {
                    appendType(buffer, genericArguments, 9, 0, 0);
                } else {
                    val parameterType =
                        nodes.data[
                            parameterRoot(
                                nodes, functionRoot,
                                index + 1) - 1];
                    val concreteParameter = substituteEmitterType(
                        source, nodes, functionRoot,
                        TypeValue(
                            parameterType.typeKind,
                            parameterType.typeName,
                            parameterType.typePointee),
                        genericArguments,
                        node.genericArgumentStart,
                        node.genericArgumentCount);
                    appendType(
                        buffer, genericArguments, concreteParameter.kind,
                        concreteParameter.name,
                        concreteParameter.pointee);
                }
            } else {
                appendType(
                    buffer, genericArguments,
                    values[index as u64].typeKind,
                    values[index as u64].typeName,
                    values[index as u64].typePointee);
            }
            byteBufferAppend(buffer, 32);
            appendIrValue(buffer, source, values[index as u64]);
            index = index + 1;
        }
        byteBufferAppend(buffer, 41);
        appendNewline(buffer);
        k_boot_free(values as unit*);
        k_boot_free(arguments as unit*);
        if (isPrint) return IrValue(3, 0, 0, 0, 1, 0, 0);
        if (node.typeKind == 1) {
            return IrValue(3, 0, 0, 0, 1, 0, 0);
        }
        return IrValue(
            2, 0, 0, temporary,
            node.typeKind, node.typeName, node.typePointee);
    }
    return IrValue(0, 0, 0, 0, 0, 0, 0);
}

fn blockStatementRoots(nodes: AstList, blockRoot: u64): u64* {
    val block = nodes.data[blockRoot];
    val roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var root = blockRoot - 1;
    var remaining = block.aux;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return roots;
}

fn emitBlock(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    genericArguments: TypeValueList,
    root: u64,
    var counter: IrCounter): bool {
    val roots = blockStatementRoots(nodes, root);
    var index: u32 = 0;
    var terminated = false;
    while (index < nodes.data[root].aux) {
        if (!terminated) {
            terminated = emitStatement(
                buffer, source, nodes, genericArguments,
                roots[index as u64], counter);
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
    return terminated;
}

fn emitCollectionFor(
    var buffer: ByteBuffer, source: Source, nodes: AstList,
    genericArguments: TypeValueList, root: u64,
    var counter: IrCounter): bool {
    val statement = nodes.data[root];
    val bodyRoot = root - 1;
    val collectionRoot = expressionChildBefore(nodes, bodyRoot);
    val collectionNode = nodes.data[collectionRoot];
    val collectionValue = emitExpression(
        buffer, source, nodes, genericArguments, collectionRoot, counter);
    val valueName = nodes.data[statement.subtreeStart];
    var indexStorage = statement.start;
    if (statement.aux == 1) {
        indexStorage = nodes.data[statement.subtreeStart + 1].start;
    }
    var elementKind = collectionNode.typePointee;
    var elementName = collectionNode.typeName;
    var data = IrValue(0, 0, 0, 0, 9, elementName, elementKind);
    var length = IrValue(3, 0, 0, 0, 7, 0, 0);
    if (collectionNode.typeKind == 19) {
        elementKind = collectionNode.typePointee % 256;
        val pointer = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, pointer); appendEquals(buffer);
        appendGetElementPtr(buffer); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, collectionNode);
        appendPtr(buffer); appendLocalPrefix(buffer);
        appendDecimal(buffer, nodes.data[collectionRoot].storage);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendI32(buffer); byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 48);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendI32(buffer); byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 48);
        appendNewline(buffer);
        data = IrValue(2, 0, 0, pointer, 9, elementName, elementKind);
        length = IrValue(
            3, 0, 0, (collectionNode.typePointee / 256) as u64,
            7, 0, 0);
    } else {
        val dataTemporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, dataTemporary);
        appendEquals(buffer); appendExtractValue(buffer);
        appendNodeType(buffer, genericArguments, collectionNode);
        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, collectionValue);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 48);
        appendNewline(buffer);
        data = IrValue(2, 0, 0, dataTemporary, 9, elementName, elementKind);
        val lengthTemporary = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, lengthTemporary);
        appendEquals(buffer); appendExtractValue(buffer);
        appendNodeType(buffer, genericArguments, collectionNode);
        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, collectionValue);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 49);
        appendNewline(buffer);
        length = IrValue(2, 0, 0, lengthTemporary, 7, 0, 0);
    }
    appendStore(buffer); appendI64(buffer); byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 48); appendPtr(buffer); appendLocalPrefix(buffer);
    appendDecimal(buffer, indexStorage); appendNewline(buffer);
    val conditionBlock = nextBlock(counter);
    val bodyBlock = nextBlock(counter);
    val incrementBlock = nextBlock(counter);
    val endBlock = nextBlock(counter);
    appendBranch(buffer, conditionBlock);
    appendBlockLabel(buffer, counter, conditionBlock);
    val index = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, index); appendEquals(buffer);
    appendLoad(buffer); appendI64(buffer); appendPtr(buffer); appendLocalPrefix(buffer);
    appendDecimal(buffer, indexStorage); appendNewline(buffer);
    val compared = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, compared); appendEquals(buffer);
    appendComparison(buffer, 66, 7); byteBufferAppend(buffer, 32);
    appendI64(buffer); byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, IrValue(2, 0, 0, index, 7, 0, 0));
    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, length); appendNewline(buffer);
    appendConditionalBranch(
        buffer, source, IrValue(2, 0, 0, compared, 2, 0, 0),
        bodyBlock, endBlock);
    appendBlockLabel(buffer, counter, bodyBlock);
    val elementPointer = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, elementPointer); appendEquals(buffer);
    appendGetElementPtr(buffer); byteBufferAppend(buffer, 32);
    appendType(buffer, genericArguments, elementKind, elementName, 0);
    appendPointerValue(buffer, source, data);
    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32); appendI64(buffer);
    byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, IrValue(2, 0, 0, index, 7, 0, 0));
    appendNewline(buffer);
    val element = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, element); appendEquals(buffer);
    appendLoad(buffer); appendType(buffer, genericArguments, elementKind, elementName, 0);
    appendPointerValue(
        buffer, source,
        IrValue(2, 0, 0, elementPointer, 9, elementName, elementKind));
    appendNewline(buffer);
    appendStore(buffer); appendType(buffer, genericArguments, elementKind, elementName, 0);
    byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, IrValue(2, 0, 0, element, elementKind, elementName, 0));
    appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, valueName.start);
    appendNewline(buffer);
    val outerContinueBlock = counter.continueBlock;
    val outerBreakBlock = counter.breakBlock;
    counter.continueBlock = incrementBlock; counter.breakBlock = endBlock;
    val terminated = emitBlock(
        buffer, source, nodes, genericArguments, bodyRoot, counter);
    counter.continueBlock = outerContinueBlock; counter.breakBlock = outerBreakBlock;
    if (!terminated) appendBranch(buffer, incrementBlock);
    appendBlockLabel(buffer, counter, incrementBlock);
    val loaded = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
    appendLoad(buffer); appendI64(buffer); appendPtr(buffer); appendLocalPrefix(buffer);
    appendDecimal(buffer, indexStorage); appendNewline(buffer);
    val advanced = nextTemporary(counter);
    appendValuePrefix(buffer); appendDecimal(buffer, advanced); appendEquals(buffer);
    appendOperator(buffer, 60, 7); byteBufferAppend(buffer, 32); appendI64(buffer);
    byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, IrValue(2, 0, 0, loaded, 7, 0, 0));
    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 49);
    appendNewline(buffer);
    appendStore(buffer); appendI64(buffer); byteBufferAppend(buffer, 32);
    appendIrValue(buffer, source, IrValue(2, 0, 0, advanced, 7, 0, 0));
    appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, indexStorage);
    appendNewline(buffer); appendBranch(buffer, conditionBlock);
    appendBlockLabel(buffer, counter, endBlock);
    return false;
}

fn emitWhen(
    var buffer: ByteBuffer, source: Source, nodes: AstList,
    genericArguments: TypeValueList, root: u64,
    var counter: IrCounter): bool {
    val statement = nodes.data[root];
    val branchCount = statement.aux % 65536;
    val hasSubject = statement.aux / 65536;
    val roots =
        k_boot_alloc((branchCount as u64) * sizeof(u64)) as u64*;
    var branchRoot = root - 1;
    var remaining = branchCount;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = branchRoot;
        branchRoot = nodes.data[branchRoot].subtreeStart - 1;
        remaining = remaining - 1;
    }
    var subject = IrValue(0, 0, 0, 0, 0, 0, 0);
    if (hasSubject == 1) {
        subject = emitExpression(
            buffer, source, nodes, genericArguments, branchRoot, counter);
    }
    val mergeBlock = nextBlock(counter);
    var hasElse = false;
    var allTerminate = branchCount > 0;
    var index: u32 = 0;
    while (index < branchCount) {
        val branch = nodes.data[roots[index as u64]];
        val bodyRoot = roots[index as u64] - 1;
        val bodyBlock = nextBlock(counter);
        if (branch.aux % 2 == 0) {
            var nextBlockValue = mergeBlock;
            if (index + 1 < branchCount) {
                nextBlockValue = nextBlock(counter);
            }
            val patternCount = branch.aux / 65536;
            val patternRoots =
                k_boot_alloc((patternCount as u64) * sizeof(u64)) as u64*;
            var patternRoot = expressionChildBefore(nodes, bodyRoot);
            var patternRemaining = patternCount;
            while (patternRemaining > 0) {
                patternRoots[patternRemaining as u64 - 1] = patternRoot;
                patternRoot = nodes.data[patternRoot].subtreeStart - 1;
                patternRemaining = patternRemaining - 1;
            }
            var patternIndex: u32 = 0;
            while (patternIndex < patternCount) {
                var condition = emitExpression(
                    buffer, source, nodes, genericArguments,
                    patternRoots[patternIndex as u64], counter);
                if (hasSubject == 1) {
                    val compared = nextTemporary(counter);
                    appendValuePrefix(buffer); appendDecimal(buffer, compared);
                    appendEquals(buffer); appendComparison(buffer, 79, subject.typeKind);
                    byteBufferAppend(buffer, 32);
                    appendType(
                        buffer, genericArguments,
                        subject.typeKind, subject.typeName, subject.typePointee);
                    byteBufferAppend(buffer, 32); appendIrValue(buffer, source, subject);
                    byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
                    appendIrValue(buffer, source, condition); appendNewline(buffer);
                    condition = IrValue(2, 0, 0, compared, 2, 0, 0);
                }
                var missBlock = nextBlockValue;
                if (patternIndex + 1 < patternCount) missBlock = nextBlock(counter);
                appendConditionalBranch(
                    buffer, source, condition, bodyBlock, missBlock);
                patternIndex = patternIndex + 1;
                if (patternIndex < patternCount) {
                    appendBlockLabel(buffer, counter, missBlock);
                }
            }
            k_boot_free(patternRoots as unit*);
            appendBlockLabel(buffer, counter, bodyBlock);
            val terminated = emitBlock(
                buffer, source, nodes, genericArguments, bodyRoot, counter);
            if (!terminated) appendBranch(buffer, mergeBlock);
            if (!terminated) allTerminate = false;
            if (index + 1 < branchCount) {
                appendBlockLabel(buffer, counter, nextBlockValue);
            }
        } else {
            hasElse = true;
            appendBranch(buffer, bodyBlock);
            appendBlockLabel(buffer, counter, bodyBlock);
            val terminated = emitBlock(
                buffer, source, nodes, genericArguments, bodyRoot, counter);
            if (!terminated) appendBranch(buffer, mergeBlock);
            if (!terminated) allTerminate = false;
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
    if (hasElse) {
        if (allTerminate) return true;
    }
    appendBlockLabel(buffer, counter, mergeBlock);
    if (!hasElse && allTerminate && subject.typeKind == 20) {
        appendUnreachable(buffer); appendNewline(buffer);
        return true;
    }
    return false;
}

fn emitStatement(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    genericArguments: TypeValueList,
    root: u64,
    var counter: IrCounter): bool {
    val statement = nodes.data[root];
    if (statement.kind == 36) {
        appendBranch(buffer, counter.breakBlock);
        return true;
    }
    if (statement.kind == 37) {
        appendBranch(buffer, counter.continueBlock);
        return true;
    }
    if (statement.kind == 38) {
        val bodyRoot = root - 1;
        val collectionRoot = expressionChildBefore(nodes, bodyRoot);
        val collectionNode = nodes.data[collectionRoot];
        var range = collectionNode.kind == 13;
        if (range) {
            range = collectionNode.aux == 87;
            if (collectionNode.aux == 88) range = true;
            if (collectionNode.aux == 93) range = true;
            if (collectionNode.aux == 94) range = true;
        }
        if (!range) {
            return emitCollectionFor(
                buffer, source, nodes, genericArguments, root, counter);
        }
        val rightRoot = collectionRoot - 1;
        val leftRoot = expressionChildBefore(nodes, rightRoot);
        val start = emitExpression(
            buffer, source, nodes, genericArguments, leftRoot, counter);
        val finish = emitExpression(
            buffer, source, nodes, genericArguments, rightRoot, counter);
        val ascending = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, ascending); appendEquals(buffer);
        appendComparison(buffer, 81, start.typeKind); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, start);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val different = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, different); appendEquals(buffer);
        appendComparison(buffer, 80, start.typeKind); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, start);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val step = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, step); appendEquals(buffer);
        byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 49); byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 37); appendDecimal(buffer, ascending);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 49);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 45);
        byteBufferAppend(buffer, 49); appendNewline(buffer);
        var initial = start;
        if (collectionNode.aux == 93 || collectionNode.aux == 94) {
            val shifted = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, shifted); appendEquals(buffer);
            appendOperator(buffer, 60, start.typeKind); byteBufferAppend(buffer, 32);
            appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, start);
            byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 37); appendDecimal(buffer, step); appendNewline(buffer);
            initial = IrValue(
                2, 0, 0, shifted, start.typeKind, start.typeName, start.typePointee);
        }
        val name = nodes.data[statement.subtreeStart];
        appendStore(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32); appendIrValue(buffer, source, initial);
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer);
        val conditionBlock = nextBlock(counter);
        val bodyBlock = nextBlock(counter);
        val incrementBlock = nextBlock(counter);
        val endBlock = nextBlock(counter);
        appendBranch(buffer, conditionBlock);
        appendBlockLabel(buffer, counter, conditionBlock);
        val current = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, current); appendEquals(buffer);
        appendLoad(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer);
        val ascendingCompared = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, ascendingCompared); appendEquals(buffer);
        var ascendingOperator: u32 = 81;
        if (collectionNode.aux == 88 || collectionNode.aux == 94)
            ascendingOperator = 66;
        appendComparison(buffer, ascendingOperator, start.typeKind);
        byteBufferAppend(buffer, 32); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, IrValue(2, 0, 0, current, start.typeKind, start.typeName, start.typePointee));
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val descendingCompared = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, descendingCompared); appendEquals(buffer);
        var descendingOperator: u32 = 82;
        if (collectionNode.aux == 88 || collectionNode.aux == 94)
            descendingOperator = 67;
        appendComparison(buffer, descendingOperator, start.typeKind);
        byteBufferAppend(buffer, 32); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, IrValue(2, 0, 0, current, start.typeKind, start.typeName, start.typePointee));
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, finish); appendNewline(buffer);
        val compared = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, compared); appendEquals(buffer);
        byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 49); byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 37); appendDecimal(buffer, ascending);
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 49);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
        appendDecimal(buffer, ascendingCompared); byteBufferAppend(buffer, 44);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 49); byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 37); appendDecimal(buffer, descendingCompared);
        appendNewline(buffer);
        var conditionValue = IrValue(2, 0, 0, compared, 2, 0, 0);
        if (collectionNode.aux != 87) {
            val nonempty = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, nonempty); appendEquals(buffer);
            byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 49);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, compared); byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, different); appendNewline(buffer);
            conditionValue = IrValue(2, 0, 0, nonempty, 2, 0, 0);
        }
        appendConditionalBranch(
            buffer, source, conditionValue, bodyBlock, endBlock);
        appendBlockLabel(buffer, counter, bodyBlock);
        val outerContinueBlock = counter.continueBlock;
        val outerBreakBlock = counter.breakBlock;
        counter.continueBlock = incrementBlock;
        counter.breakBlock = endBlock;
        val terminated = emitBlock(
            buffer, source, nodes, genericArguments, bodyRoot, counter);
        counter.continueBlock = outerContinueBlock;
        counter.breakBlock = outerBreakBlock;
        if (!terminated) appendBranch(buffer, incrementBlock);
        appendBlockLabel(buffer, counter, incrementBlock);
        val loaded = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, loaded); appendEquals(buffer);
        appendLoad(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer);
        if (collectionNode.aux == 87 || collectionNode.aux == 93) {
            val terminal = nextTemporary(counter);
            appendValuePrefix(buffer); appendDecimal(buffer, terminal); appendEquals(buffer);
            appendComparison(buffer, 79, start.typeKind); byteBufferAppend(buffer, 32);
            appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
            byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 37);
            appendDecimal(buffer, loaded); byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32); appendIrValue(buffer, source, finish);
            appendNewline(buffer);
            val advanceBlock = nextBlock(counter);
            appendConditionalBranch(
                buffer, source, IrValue(2, 0, 0, terminal, 2, 0, 0),
                endBlock, advanceBlock);
            appendBlockLabel(buffer, counter, advanceBlock);
        }
        val advanced = nextTemporary(counter);
        appendValuePrefix(buffer); appendDecimal(buffer, advanced); appendEquals(buffer);
        appendOperator(buffer, 60, start.typeKind); byteBufferAppend(buffer, 32);
        appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]); byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, IrValue(2, 0, 0, loaded, start.typeKind, start.typeName, start.typePointee));
        byteBufferAppend(buffer, 44); byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 37); appendDecimal(buffer, step);
        appendNewline(buffer);
        appendStore(buffer); appendNodeType(buffer, genericArguments, nodes.data[collectionRoot]);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, IrValue(2, 0, 0, advanced, start.typeKind, start.typeName, start.typePointee));
        appendPtr(buffer); appendLocalPrefix(buffer); appendDecimal(buffer, name.start);
        appendNewline(buffer); appendBranch(buffer, conditionBlock);
        appendBlockLabel(buffer, counter, endBlock);
        return false;
    }
    if (statement.kind == 39) {
        return emitWhen(
            buffer, source, nodes, genericArguments, root, counter);
    }
    if (statement.kind == 33) {
        val initializerRoot = root - 1;
        var initializer = emitExpression(
            buffer, source, nodes, genericArguments,
            initializerRoot, counter);
        val name = nodes.data[statement.subtreeStart];
        var storageKind = initializer.typeKind;
        var storageName = initializer.typeName;
        var storagePointee = initializer.typePointee;
        val afterName = statement.subtreeStart + 1;
        if (afterName < nodes.data[initializerRoot].subtreeStart) {
            val declaredType =
                nodes.data[
                    nodes.data[initializerRoot].subtreeStart - 1];
            storageKind = declaredType.typeKind;
            storageName = declaredType.typeName;
            storagePointee = declaredType.typePointee;
        }
        initializer = emitImplicitIntegerWiden(
            buffer, source, genericArguments, initializer,
            storageKind, storageName, storagePointee, counter);
        appendStore(buffer);
        appendType(
            buffer, genericArguments, storageKind, storageName, storagePointee);
        byteBufferAppend(buffer, 32);
        appendIrValue(buffer, source, initializer);
        appendPtr(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, name.start);
        appendNewline(buffer);
        return false;
    } else {
        if (statement.kind == 34) {
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 32);
            if (statement.aux == 0) {
                byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 118);
                byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 100);
            } else {
                val value = emitExpression(
                    buffer, source, nodes, genericArguments,
                    root - 1, counter);
                var returned = emitImplicitIntegerWiden(
                    buffer, source, genericArguments, value,
                    statement.typeKind, statement.typeName,
                    statement.typePointee, counter);
                if (statement.conversionKind != 0) {
                    val tagged = nextTemporary(counter);
                    appendValuePrefix(buffer);
                    appendDecimal(buffer, tagged);
                    appendEquals(buffer);
                    byteBufferAppend(buffer, 105);
                    byteBufferAppend(buffer, 110);
                    byteBufferAppend(buffer, 115);
                    byteBufferAppend(buffer, 101);
                    byteBufferAppend(buffer, 114);
                    byteBufferAppend(buffer, 116);
                    byteBufferAppend(buffer, 118);
                    byteBufferAppend(buffer, 97);
                    byteBufferAppend(buffer, 108);
                    byteBufferAppend(buffer, 117);
                    byteBufferAppend(buffer, 101);
                    byteBufferAppend(buffer, 32);
                    appendType(
                        buffer, genericArguments, statement.typeKind,
                        statement.typeName, statement.typePointee);
                    byteBufferAppend(buffer, 32);
                    byteBufferAppend(buffer, 117);
                    byteBufferAppend(buffer, 110);
                    byteBufferAppend(buffer, 100);
                    byteBufferAppend(buffer, 101);
                    byteBufferAppend(buffer, 102);
                    byteBufferAppend(buffer, 44);
                    byteBufferAppend(buffer, 32);
                    byteBufferAppend(buffer, 105);
                    byteBufferAppend(buffer, 49);
                    byteBufferAppend(buffer, 32);
                    if (statement.conversionKind == 1) {
                        byteBufferAppend(buffer, 116);
                        byteBufferAppend(buffer, 114);
                        byteBufferAppend(buffer, 117);
                        byteBufferAppend(buffer, 101);
                    } else {
                        byteBufferAppend(buffer, 102);
                        byteBufferAppend(buffer, 97);
                        byteBufferAppend(buffer, 108);
                        byteBufferAppend(buffer, 115);
                        byteBufferAppend(buffer, 101);
                    }
                    byteBufferAppend(buffer, 44);
                    byteBufferAppend(buffer, 32);
                    byteBufferAppend(buffer, 48);
                    appendNewline(buffer);
                    returned = IrValue(
                        2, 0, 0, tagged,
                        statement.typeKind,
                        statement.typeName, statement.typePointee);
                    if (statement.conversionKind == 1) {
                        val withPayload = nextTemporary(counter);
                        appendValuePrefix(buffer);
                        appendDecimal(buffer, withPayload);
                        appendEquals(buffer);
                        byteBufferAppend(buffer, 105);
                        byteBufferAppend(buffer, 110);
                        byteBufferAppend(buffer, 115);
                        byteBufferAppend(buffer, 101);
                        byteBufferAppend(buffer, 114);
                        byteBufferAppend(buffer, 116);
                        byteBufferAppend(buffer, 118);
                        byteBufferAppend(buffer, 97);
                        byteBufferAppend(buffer, 108);
                        byteBufferAppend(buffer, 117);
                        byteBufferAppend(buffer, 101);
                        byteBufferAppend(buffer, 32);
                        appendType(
                            buffer, genericArguments, statement.typeKind,
                            statement.typeName, statement.typePointee);
                        byteBufferAppend(buffer, 32);
                        appendIrValue(buffer, source, returned);
                        byteBufferAppend(buffer, 44);
                        byteBufferAppend(buffer, 32);
                        appendType(
                            buffer, genericArguments, statement.typePointee,
                            statement.typeName, 0);
                        byteBufferAppend(buffer, 32);
                        appendIrValue(buffer, source, value);
                        byteBufferAppend(buffer, 44);
                        byteBufferAppend(buffer, 32);
                        appendDecimal(buffer, 1);
                        appendNewline(buffer);
                        returned = IrValue(
                            2, 0, 0, withPayload,
                            statement.typeKind,
                            statement.typeName, statement.typePointee);
                    }
                }
                byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 32);
                appendType(
                    buffer, genericArguments, returned.typeKind,
                    returned.typeName, returned.typePointee);
                byteBufferAppend(buffer, 32);
                appendIrValue(buffer, source, returned);
            }
            appendNewline(buffer);
            return true;
        } else {
            if (statement.kind == 35) {
                emitExpression(
                    buffer, source, nodes, genericArguments,
                    root - 1, counter);
                return false;
            } else {
                if (statement.kind == 30) {
                    return emitBlock(
                        buffer, source, nodes, genericArguments,
                        root, counter);
                }
                if (statement.kind == 31) {
                    var elseRoot: u64 = 0;
                    var thenRoot = root - 1;
                    if (statement.aux == 1) {
                        elseRoot = thenRoot;
                        thenRoot = expressionChildBefore(nodes, elseRoot);
                    }
                    val conditionRoot =
                        expressionChildBefore(nodes, thenRoot);
                    val condition = emitExpression(
                        buffer, source, nodes, genericArguments,
                        conditionRoot, counter);
                    val thenBlock = nextBlock(counter);
                    val elseBlock = nextBlock(counter);
                    val endBlock = nextBlock(counter);
                    if (statement.aux == 1) {
                        appendConditionalBranch(
                            buffer, source, condition, thenBlock, elseBlock);
                    } else {
                        appendConditionalBranch(
                            buffer, source, condition, thenBlock, endBlock);
                    }
                    appendBlockLabel(buffer, counter, thenBlock);
                    val thenTerminated = emitBlock(
                        buffer, source, nodes, genericArguments,
                        thenRoot, counter);
                    if (!thenTerminated) {
                        appendBranch(buffer, endBlock);
                    }
                    var elseTerminated = false;
                    if (statement.aux == 1) {
                        appendBlockLabel(buffer, counter, elseBlock);
                        elseTerminated = emitBlock(
                            buffer, source, nodes, genericArguments,
                            elseRoot, counter);
                        if (!elseTerminated) {
                            appendBranch(buffer, endBlock);
                        }
                    }
                    if (!thenTerminated) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    if (statement.aux == 0) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    if (!elseTerminated) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    return true;
                }
                if (statement.kind == 32) {
                    val bodyRoot = root - 1;
                    val conditionRoot =
                        expressionChildBefore(nodes, bodyRoot);
                    val conditionBlock = nextBlock(counter);
                    val bodyBlock = nextBlock(counter);
                    val endBlock = nextBlock(counter);
                    appendBranch(buffer, conditionBlock);
                    appendBlockLabel(buffer, counter, conditionBlock);
                    val condition = emitExpression(
                        buffer, source, nodes, genericArguments,
                        conditionRoot, counter);
                    appendConditionalBranch(
                        buffer, source, condition, bodyBlock, endBlock);
                    appendBlockLabel(buffer, counter, bodyBlock);
                    val outerContinueBlock = counter.continueBlock;
                    val outerBreakBlock = counter.breakBlock;
                    counter.continueBlock = conditionBlock;
                    counter.breakBlock = endBlock;
                    val bodyTerminated = emitBlock(
                        buffer, source, nodes, genericArguments,
                        bodyRoot, counter);
                    counter.continueBlock = outerContinueBlock;
                    counter.breakBlock = outerBreakBlock;
                    if (!bodyTerminated) {
                        appendBranch(buffer, conditionBlock);
                    }
                    appendBlockLabel(buffer, counter, endBlock);
                    return false;
                }
            }
        }
    }
    return false;
}

fn parameterRoot(
    nodes: AstList, functionRoot: u64, position: u32): u64 {
    val function = nodes.data[functionRoot];
    var root = functionRoot - 1;
    if (!functionIsExtern(function)) {
        root = nodes.data[root].subtreeStart - 1;
    }
    var remaining = functionParameterCount(function);
    while (remaining >= position) {
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn returnTypeRoot(nodes: AstList, functionRoot: u64): u64 {
    if (functionIsExtern(nodes.data[functionRoot])) {
        return functionRoot - 1;
    }
    return nodes.data[functionRoot - 1].subtreeStart - 1;
}

fn emitterTypeParameterRoot(
    nodes: AstList, functionRoot: u64, position: u32): u64 {
    var root = returnTypeRoot(nodes, functionRoot);
    var parameters =
        functionParameterCount(nodes.data[functionRoot]);
    while (parameters > 0) {
        root = nodes.data[root].subtreeStart - 1;
        parameters = parameters - 1;
    }
    var remaining =
        functionTypeParameterCount(nodes.data[functionRoot]);
    while (remaining >= position) {
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    return root;
}

fn emitterTypeParameterPosition(
    source: Source, nodes: AstList,
    functionRoot: u64, name: u64): u32 {
    val count =
        functionTypeParameterCount(nodes.data[functionRoot]);
    var position: u32 = 1;
    while (position <= count) {
        val root =
            emitterTypeParameterRoot(nodes, functionRoot, position);
        val parameter = nodes.data[root];
        val nameNode = nodes.data[parameter.subtreeStart];
        if (sourceHash(source, nameNode.start, nameNode.end) == name) {
            return position - 1;
        }
        position = position + 1;
    }
    return count;
}

fn substituteEmitterType(
    source: Source, nodes: AstList, functionRoot: u64,
    pattern: TypeValue, arguments: TypeValueList,
    argumentStart: u64, count: u32): TypeValue {
    if (pattern.kind == 15) {
        val inner = substituteEmitterType(
            source, nodes, functionRoot,
            TypeValue(pattern.pointee, pattern.name, 0),
            arguments, argumentStart, count);
        return TypeValue(15, inner.name, inner.kind);
    }
    if (pattern.kind != 14) return pattern;
    val position = emitterTypeParameterPosition(
        source, nodes, functionRoot, pattern.name);
    if (position >= count) return invalidType();
    return arguments.data[argumentStart + position as u64];
}

fn emitVariableAlloca(
    var buffer: ByteBuffer, genericArguments: TypeValueList, nodes: AstList, root: u64) {
    val statement = nodes.data[root];
    val initializerRoot = root - 1;
    val initializer = nodes.data[initializerRoot];
    var storageKind = initializer.typeKind;
    var storageName = initializer.typeName;
    var storagePointee = initializer.typePointee;
    val afterName = statement.subtreeStart + 1;
    if (afterName < initializer.subtreeStart) {
        val declaredType =
            nodes.data[initializer.subtreeStart - 1];
        storageKind = declaredType.typeKind;
        storageName = declaredType.typeName;
        storagePointee = declaredType.typePointee;
    }
    val name = nodes.data[statement.subtreeStart];
    appendValuePrefix(buffer);
    appendLocalPrefix(buffer);
    appendDecimal(buffer, name.start);
    appendEquals(buffer);
    appendAlloca(buffer);
    appendType(
        buffer, genericArguments, storageKind, storageName, storagePointee);
    appendNewline(buffer);
}

fn emitBlockAllocas(
    var buffer: ByteBuffer, genericArguments: TypeValueList, nodes: AstList, blockRoot: u64) {
    val roots = blockStatementRoots(nodes, blockRoot);
    var index: u32 = 0;
    while (index < nodes.data[blockRoot].aux) {
        val root = roots[index as u64];
        val statement = nodes.data[root];
        if (statement.kind == 33) {
            emitVariableAlloca(buffer, genericArguments, nodes, root);
        }
        if (statement.kind == 30) {
            emitBlockAllocas(buffer, genericArguments, nodes, root);
        }
        if (statement.kind == 31) {
            var branchRoot = root - 1;
            if (statement.aux == 1) {
                emitBlockAllocas(buffer, genericArguments, nodes, branchRoot);
                branchRoot = expressionChildBefore(nodes, branchRoot);
            }
            emitBlockAllocas(buffer, genericArguments, nodes, branchRoot);
        }
        if (statement.kind == 32) {
            emitBlockAllocas(buffer, genericArguments, nodes, root - 1);
        }
        if (statement.kind == 38) {
            val bodyRoot = root - 1;
            val collectionRoot = expressionChildBefore(nodes, bodyRoot);
            val name = nodes.data[statement.subtreeStart];
            val collection = nodes.data[collectionRoot];
            var range = collection.kind == 13;
            if (range) {
                range = collection.aux == 87;
                if (collection.aux == 88) range = true;
                if (collection.aux == 93) range = true;
                if (collection.aux == 94) range = true;
            }
            appendValuePrefix(buffer); appendLocalPrefix(buffer);
            appendDecimal(buffer, name.start); appendEquals(buffer);
            appendAlloca(buffer);
            if (range) {
                appendNodeType(buffer, genericArguments, collection);
            } else {
                var elementKind = collection.typePointee;
                if (collection.typeKind == 19) {
                    elementKind = collection.typePointee % 256;
                }
                appendType(
                    buffer, genericArguments,
                    elementKind, collection.typeName, 0);
            }
            appendNewline(buffer);
            if (!range) {
                var indexStorage = statement.start;
                if (statement.aux == 1) {
                    indexStorage = nodes.data[statement.subtreeStart + 1].start;
                }
                appendValuePrefix(buffer); appendLocalPrefix(buffer);
                appendDecimal(buffer, indexStorage); appendEquals(buffer);
                appendAlloca(buffer); appendI64(buffer); appendNewline(buffer);
            }
            emitBlockAllocas(buffer, genericArguments, nodes, bodyRoot);
        }
        if (statement.kind == 39) {
            val branchCount = statement.aux % 65536;
            var branchRoot = root - 1;
            var remaining = branchCount;
            while (remaining > 0) {
                emitBlockAllocas(
                    buffer, genericArguments, nodes, branchRoot - 1);
                branchRoot = nodes.data[branchRoot].subtreeStart - 1;
                remaining = remaining - 1;
            }
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
}

fn emitFunction(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    genericArguments: TypeValueList,
    functionRoot: u64,
    specializationArgumentStart: u64,
    specializationCount: u32): bool {
    val function = nodes.data[functionRoot];
    val name = nodes.data[function.subtreeStart];
    val returnType = nodes.data[returnTypeRoot(nodes, functionRoot)];
    val parameterCount = functionParameterCount(function);
    if (functionIsExtern(function)) {
        byteBufferAppend(buffer, 100);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 99);
        byteBufferAppend(buffer, 108);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 32);
    } else {
        appendDefine(buffer);
    }
    if (functionInfersReturn(function)) {
        var inferred = TypeValue(
            function.typeKind, function.typeName, function.typePointee);
        if (specializationCount > 0) {
            inferred = substituteEmitterType(
                source, nodes, functionRoot, inferred,
                genericArguments,
                specializationArgumentStart, specializationCount);
        }
        appendType(
            buffer, genericArguments,
            inferred.kind, inferred.name, inferred.pointee);
    } else appendNodeType(buffer, genericArguments, returnType);
    appendFunctionOpen(buffer);
    if (function.conversionKind == 1) {
        val receiverType = nodes.data[
            parameterRoot(nodes, functionRoot, 1) - 1];
        val ownerRoot = structRootByName(source, nodes, receiverType.typeName);
        val ownerName = nodes.data[nodes.data[ownerRoot].subtreeStart];
        appendSource(buffer, source, ownerName.start, ownerName.end);
        byteBufferAppend(buffer, 46);
    }
    appendSource(buffer, source, name.start, name.end);
    if (specializationCount > 0) {
        appendSpecializationSuffix(
            buffer, genericArguments,
            specializationArgumentStart, specializationCount);
    }
    byteBufferAppend(buffer, 40);
    var parameterIndex: u32 = 1;
    while (parameterIndex <= parameterCount) {
        if (parameterIndex > 1) {
            byteBufferAppend(buffer, 44);
            byteBufferAppend(buffer, 32);
        }
        val parameter = nodes.data[
            parameterRoot(nodes, functionRoot, parameterIndex)];
        val parameterName = nodes.data[parameter.subtreeStart];
        val parameterType = nodes.data[
            parameterRoot(nodes, functionRoot, parameterIndex) - 1];
        if (parameter.aux == 2) {
            appendType(buffer, genericArguments, 9, 0, parameterType.typeKind);
        } else {
            appendNodeType(buffer, genericArguments, parameterType);
        }
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 37);
        if (parameter.aux != 2) {
            byteBufferAppend(buffer, 97);
            byteBufferAppend(buffer, 114);
            byteBufferAppend(buffer, 103);
            byteBufferAppend(buffer, 46);
        } else {
            appendLocalPrefix(buffer);
        }
        if (parameter.aux == 2) {
            appendDecimal(buffer, parameterName.start);
        } else {
            appendSource(
                buffer, source, parameterName.start, parameterName.end);
        }
        parameterIndex = parameterIndex + 1;
    }
    byteBufferAppend(buffer, 41);
    if (functionIsExtern(function)) {
        appendNewline(buffer);
        return true;
    }
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 123);
    appendNewline(buffer);
    appendEntry(buffer);
    appendNewline(buffer);

    var counter = IrCounter(
        0, 0, 18446744073709551615,
        18446744073709551615, 18446744073709551615);
    parameterIndex = 1;
    while (parameterIndex <= parameterCount) {
        val parameter = nodes.data[
            parameterRoot(nodes, functionRoot, parameterIndex)];
        val parameterName = nodes.data[parameter.subtreeStart];
        if (parameter.aux != 2) {
        val parameterType = nodes.data[
            parameterRoot(nodes, functionRoot, parameterIndex) - 1];
        appendValuePrefix(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, parameterName.start);
        appendEquals(buffer);
        appendAlloca(buffer);
        appendNodeType(buffer, genericArguments, parameterType);
        appendNewline(buffer);
        appendStore(buffer);
        appendNodeType(buffer, genericArguments, parameterType);
        byteBufferAppend(buffer, 32);
        byteBufferAppend(buffer, 37);
        byteBufferAppend(buffer, 97);
        byteBufferAppend(buffer, 114);
        byteBufferAppend(buffer, 103);
        byteBufferAppend(buffer, 46);
        appendSource(
            buffer, source, parameterName.start, parameterName.end);
        appendPtr(buffer);
        appendLocalPrefix(buffer);
        appendDecimal(buffer, parameterName.start);
        appendNewline(buffer);
        }
        parameterIndex = parameterIndex + 1;
    }

    val blockRoot = functionRoot - 1;
    emitBlockAllocas(buffer, genericArguments, nodes, blockRoot);
    val terminated =
        emitBlock(
            buffer, source, nodes, genericArguments,
            blockRoot, counter);
    if (!terminated) {
        var returnsUnit = returnType.typeKind == 1;
        if (returnType.kind == 1 && returnType.aux == 49) returnsUnit = true;
        if (functionInfersReturn(function) && function.typeKind == 1)
            returnsUnit = true;
        if (returnsUnit) {
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 114);
            byteBufferAppend(buffer, 101);
            byteBufferAppend(buffer, 116);
            byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 118);
            byteBufferAppend(buffer, 111);
            byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 100);
            appendNewline(buffer);
        }
    }
    appendFunctionClose(buffer);
    return true;
}

fn emitSpecializedFunction(
    var buffer: ByteBuffer, source: Source,
    var nodes: AstList,
    var genericArguments: TypeValueList,
    functionRoot: u64,
    argumentStart: u64,
    argumentCount: u32) {
    val start = nodes.data[functionRoot].subtreeStart;
    val count = functionRoot - start + 1;
    val saved =
        k_boot_alloc(count * sizeof(AstNode)) as AstNode*;
    val savedArguments =
        k_boot_alloc(
            genericArguments.length * sizeof(TypeValue)) as TypeValue*;
    var argumentIndex: u64 = 0;
    while (argumentIndex < genericArguments.length) {
        savedArguments[argumentIndex] =
            genericArguments.data[argumentIndex];
        argumentIndex = argumentIndex + 1;
    }
    var offset: u64 = 0;
    while (offset < count) {
        saved[offset] = nodes.data[start + offset];
        var node = nodes.data[start + offset];
        if (node.typeKind == 14) {
            val concrete = substituteEmitterType(
                source, nodes, functionRoot,
                TypeValue(
                    node.typeKind, node.typeName, node.typePointee),
                genericArguments, argumentStart, argumentCount);
            node.typeKind = concrete.kind;
            node.typeName = concrete.name;
            node.typePointee = concrete.pointee;
        }
        if (node.typeKind == 15) {
            if (node.typePointee == 14) {
                val concrete = substituteEmitterType(
                    source, nodes, functionRoot,
                    TypeValue(
                        node.typeKind, node.typeName, node.typePointee),
                    genericArguments, argumentStart, argumentCount);
                node.typeKind = concrete.kind;
                node.typeName = concrete.name;
                node.typePointee = concrete.pointee;
            }
        }
        if (node.kind == 16) {
            var genericIndex: u32 = 0;
            while (genericIndex < node.genericArgumentCount) {
                val listIndex =
                    node.genericArgumentStart +
                    genericIndex as u64;
                val pattern =
                    genericArguments.data[listIndex];
                if (pattern.kind == 14) {
                    genericArguments.data[listIndex] =
                        substituteEmitterType(
                            source, nodes, functionRoot,
                            pattern, genericArguments,
                            argumentStart, argumentCount);
                }
                genericIndex = genericIndex + 1;
            }
        }
        nodes.data[start + offset] = node;
        offset = offset + 1;
    }
    emitFunction(
        buffer, source, nodes, genericArguments,
        functionRoot, argumentStart, argumentCount);
    offset = 0;
    while (offset < count) {
        nodes.data[start + offset] = saved[offset];
        offset = offset + 1;
    }
    argumentIndex = 0;
    while (argumentIndex < genericArguments.length) {
        genericArguments.data[argumentIndex] =
            savedArguments[argumentIndex];
        argumentIndex = argumentIndex + 1;
    }
    k_boot_free(savedArguments as unit*);
    k_boot_free(saved as unit*);
}

fn callCalleeRoot(nodes: AstList, callRoot: u64): u64 {
    val call = nodes.data[callRoot];
    var cursor = callRoot - 1;
    var remaining = call.aux % 65536;
    while (remaining > 0) {
        cursor = expressionChildBefore(nodes, cursor);
        remaining = remaining - 1;
    }
    remaining = call.aux / 65536;
    while (remaining > 0) {
        cursor = expressionChildBefore(nodes, cursor);
        remaining = remaining - 1;
    }
    return cursor;
}

fn firstStatementRoot(nodes: AstList, blockRoot: u64): u64 {
    val block = nodes.data[blockRoot];
    var roots =
        k_boot_alloc((block.aux as u64) * sizeof(u64)) as u64*;
    var root = blockRoot - 1;
    var remaining = block.aux;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    val result = roots[0];
    k_boot_free(roots as unit*);
    return result;
}

fn emitSimpleFunction(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    functionRoot: u64): bool {
    val function = nodes.data[functionRoot];
    if (functionParameterCount(function) != 0) return false;
    if (functionTypeParameterCount(function) != 0) return false;
    val returnTypeRoot = nodes.data[functionRoot - 1].subtreeStart - 1;
    if (nodes.data[returnTypeRoot].aux != 35) return false;
    val name = nodes.data[function.subtreeStart];
    val blockRoot = functionRoot - 1;
    if (nodes.data[blockRoot].aux != 1) return false;
    val statementRoot = firstStatementRoot(nodes, blockRoot);
    val statement = nodes.data[statementRoot];
    if (statement.kind != 34) return false;
    if (statement.aux != 1) return false;
    val literal = nodes.data[statementRoot - 1];
    if (literal.kind != 11) return false;
    if (literal.aux != 2) return false;

    appendDefine(buffer);
    appendI32(buffer);
    appendFunctionOpen(buffer);
    appendSource(buffer, source, name.start, name.end);
    appendEmptyParameters(buffer);
    appendEntry(buffer);
    appendReturnI32(buffer);
    appendSource(buffer, source, literal.start, literal.end);
    appendFunctionClose(buffer);
    return true;
}

fn emitStruct(
    var buffer: ByteBuffer, source: Source,
    nodes: AstList, genericArguments: TypeValueList, structureRoot: u64) {
    val structure = nodes.data[structureRoot];
    val name = nodes.data[structure.subtreeStart];
    byteBufferAppend(buffer, 37);
    byteBufferAppend(buffer, 115);
    appendDecimal(
        buffer, sourceHash(source, name.start, name.end));
    appendEquals(buffer);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 123);
    val fieldCount = structFieldCount(structure);
    var index: u32 = 0;
    while (index < fieldCount) {
        if (index > 0) {
            byteBufferAppend(buffer, 44);
        }
        byteBufferAppend(buffer, 32);
        val fieldRoot =
            fieldRootAt(nodes, structureRoot, index);
        appendNodeType(buffer, genericArguments, nodes.data[fieldRoot - 1]);
        index = index + 1;
    }
    if (fieldCount > 0) byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 125);
    appendNewline(buffer);
}

struct StructSpecializationRequest(
    structureRoot: u64, argumentStart: u64, argumentCount: u32)

struct StructSpecializationRequestList(
    data: StructSpecializationRequest*, length: u64, capacity: u64)

fn structSpecializationRequestListNew(): StructSpecializationRequestList {
    return StructSpecializationRequestList(
        k_boot_alloc(
            8 * sizeof(StructSpecializationRequest))
            as StructSpecializationRequest*,
        0, 8);
}

fn structSpecializationRequestListAppend(
    var list: StructSpecializationRequestList,
    value: StructSpecializationRequest) {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data =
            k_boot_alloc(
                capacity * sizeof(StructSpecializationRequest))
                as StructSpecializationRequest*;
        var index: u64 = 0;
        while (index < list.length) {
            data[index] = list.data[index];
            index = index + 1;
        }
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn structSpecializationRequestListFree(list: StructSpecializationRequestList) {
    k_boot_free(list.data as unit*);
}

fn structSpecializationRequestExists(
    requests: StructSpecializationRequestList,
    arguments: TypeValueList,
    structureRoot: u64,
    argumentStart: u64,
    argumentCount: u32): bool {
    var index: u64 = 0;
    while (index < requests.length) {
        val request = requests.data[index];
        if (request.structureRoot == structureRoot) {
            if (specializationArgumentsEqual(
                    arguments,
                    request.argumentStart, request.argumentCount,
                    argumentStart, argumentCount)) {
                return true;
            }
        }
        index = index + 1;
    }
    return false;
}

fn structArgumentsAreConcrete(
    arguments: TypeValueList, start: u64, count: u32): bool {
    var index: u32 = 0;
    while (index < count) {
        if (arguments.data[start + index as u64].kind == 14) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

fn emitSpecializedStruct(
    var buffer: ByteBuffer, source: Source,
    nodes: AstList, genericArguments: TypeValueList,
    structureRoot: u64, argumentStart: u64, argumentCount: u32) {
    val structure = nodes.data[structureRoot];
    val name = nodes.data[structure.subtreeStart];
    byteBufferAppend(buffer, 37);
    byteBufferAppend(buffer, 115);
    appendDecimal(
        buffer, sourceHash(source, name.start, name.end));
    appendStructSpecializationSuffix(buffer, genericArguments, argumentStart, argumentCount);
    appendEquals(buffer);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 123);
    val fieldCount = structFieldCount(structure);
    var index: u32 = 0;
    while (index < fieldCount) {
        if (index > 0) {
            byteBufferAppend(buffer, 44);
        }
        byteBufferAppend(buffer, 32);
        val fieldRoot =
            fieldRootAt(nodes, structureRoot, index);
        val fieldTypeNode = nodes.data[fieldRoot - 1];
        var fieldType = TypeValue(fieldTypeNode.typeKind, fieldTypeNode.typeName, fieldTypeNode.typePointee);
        fieldType = substituteStructEmitterType(
            source, nodes, structureRoot, fieldType,
            genericArguments, argumentStart, argumentCount);
        appendType(
            buffer, genericArguments,
            fieldType.kind, fieldType.name, fieldType.pointee);
        index = index + 1;
    }
    if (fieldCount > 0) byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 125);
    appendNewline(buffer);
}

struct SpecializationRequest(
    functionRoot: u64, argumentStart: u64, argumentCount: u32)

struct SpecializationRequestList(
    data: SpecializationRequest*, length: u64, capacity: u64)

fn specializationRequestListNew(): SpecializationRequestList {
    return SpecializationRequestList(
        k_boot_alloc(
            8 * sizeof(SpecializationRequest))
            as SpecializationRequest*,
        0, 8);
}

fn specializationRequestListAppend(
    var list: SpecializationRequestList,
    value: SpecializationRequest) {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data =
            k_boot_alloc(
                capacity * sizeof(SpecializationRequest))
                as SpecializationRequest*;
        var index: u64 = 0;
        while (index < list.length) {
            data[index] = list.data[index];
            index = index + 1;
        }
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    list.data[list.length] = value;
    list.length = list.length + 1;
}

fn specializationRequestListFree(list: SpecializationRequestList) {
    k_boot_free(list.data as unit*);
}

fn specializationArgumentsEqual(
    arguments: TypeValueList,
    leftStart: u64, leftCount: u32,
    rightStart: u64, rightCount: u32): bool {
    if (leftCount != rightCount) return false;
    var index: u32 = 0;
    while (index < leftCount) {
        if (
            !typeEquals(
                arguments.data[leftStart + index as u64],
                arguments.data[rightStart + index as u64], arguments
            )
        ) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

fn specializationRequestExists(
    requests: SpecializationRequestList,
    arguments: TypeValueList,
    functionRoot: u64,
    argumentStart: u64,
    argumentCount: u32): bool {
    var index: u64 = 0;
    while (index < requests.length) {
        val request = requests.data[index];
        if (request.functionRoot == functionRoot) {
            if (specializationArgumentsEqual(
                    arguments,
                    request.argumentStart, request.argumentCount,
                    argumentStart, argumentCount)) {
                return true;
            }
        }
        index = index + 1;
    }
    return false;
}

fn callArgumentsAreConcrete(
    call: AstNode, arguments: TypeValueList): bool {
    if (call.genericArgumentCount == 0) return false;
    var index: u32 = 0;
    while (index < call.genericArgumentCount) {
        if (arguments.data[
                call.genericArgumentStart + index as u64].kind == 14) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

fn emitModule(
    source: Source, nodes: AstList,
    var genericArguments: TypeValueList): ByteBuffer {
    var buffer = byteBufferNew();
    appendModuleHeader(buffer);
    appendPrintDeclaration(buffer);
    appendPanicDeclaration(buffer);
    var literalIndex: u64 = 0;
    while (literalIndex < nodes.length) {
        val literal = nodes.data[literalIndex];
        if (literal.kind == 11 && literal.typeKind == 10) appendStringGlobal(buffer, source, literal, literalIndex);
        literalIndex = literalIndex + 1;
    }
    appendNewline(buffer);
    val programRoot = nodes.length - 1;
    val program = nodes.data[programRoot];
    val roots =
        k_boot_alloc((program.aux as u64) * sizeof(u64)) as u64*;
    var root = programRoot - 1;
    var remaining = program.aux;
    while (remaining > 0) {
        roots[remaining as u64 - 1] = root;
        root = nodes.data[root].subtreeStart - 1;
        remaining = remaining - 1;
    }
    var index: u32 = 0;
    while (index < program.aux) {
        root = roots[index as u64];
        if (nodes.data[root].kind == 43) {
            if (structTypeParameterCount(nodes.data[root]) == 0) {
                emitStruct(buffer, source, nodes, genericArguments, root);
            }
        }
        index = index + 1;
    }
    
    var structRequests = structSpecializationRequestListNew();
    var nodeIndex: u64 = 0;
    while (nodeIndex < nodes.length) {
        val node = nodes.data[nodeIndex];
        if (node.typeKind == 8) {
            val start = node.typePointee % 65536;
            val count = node.typePointee / 65536;
            if (count > 0) {
                if (structArgumentsAreConcrete(genericArguments, start as u64, count)) {
                    val structureRoot = structRootByName(source, nodes, node.typeName);
                    if (structureRoot != nodes.length) {
                        if (
                            !structSpecializationRequestExists(
                                structRequests, genericArguments,
                                structureRoot, start as u64, count
                            )
                        ) {
                            structSpecializationRequestListAppend(
                                structRequests,
                                StructSpecializationRequest(
                                    structureRoot, start as u64, count));
                        }
                    }
                }
            }
        }
        nodeIndex = nodeIndex + 1;
    }
    
    var structReqIndex: u64 = 0;
    while (structReqIndex < structRequests.length) {
        val request = structRequests.data[structReqIndex];
        emitSpecializedStruct(
            buffer, source, nodes, genericArguments,
            request.structureRoot, request.argumentStart, request.argumentCount);
        structReqIndex = structReqIndex + 1;
    }
    structSpecializationRequestListFree(structRequests);
    
    appendNewline(buffer);
    index = 0;
    while (index < program.aux) {
        root = roots[index as u64];
        if (nodes.data[root].kind == 41) {
            if (functionTypeParameterCount(nodes.data[root]) == 0) {
                emitFunction(
                    buffer, source, nodes, genericArguments,
                    root, 0, 0);
            }
        } else {
            if (nodes.data[root].kind == 43) {
                var methodRoot = root - 1;
                var methods = emitterStructMethodCount(nodes.data[root]);
                while (methods > 0) {
                    emitFunction(
                        buffer, source, nodes, genericArguments,
                        methodRoot, 0, 0);
                    methodRoot = nodes.data[methodRoot].subtreeStart - 1;
                    methods = methods - 1;
                }
            }
        }
        index = index + 1;
    }
    var requests = specializationRequestListNew();
    var callIndex: u64 = 0;
    while (callIndex < nodes.length) {
        val call = nodes.data[callIndex];
        if (call.kind == 16) {
            if (callArgumentsAreConcrete(call, genericArguments)) {
                val calleeRoot = callCalleeRoot(nodes, callIndex);
                val callee = nodes.data[calleeRoot];
                val functionRoot =
                    functionRootByName(
                        source, nodes,
                        sourceHash(
                            source, callee.start, callee.end));
                if (functionRoot != nodes.length) {
                    if (
                        !specializationRequestExists(
                            requests, genericArguments,
                            functionRoot,
                            call.genericArgumentStart,
                            call.genericArgumentCount
                        )
                    ) {
                        specializationRequestListAppend(
                            requests,
                            SpecializationRequest(
                                functionRoot,
                                call.genericArgumentStart,
                                call.genericArgumentCount));
                    }
                }
            }
        }
        callIndex = callIndex + 1;
    }
    var requestIndex: u64 = 0;
    while (requestIndex < requests.length) {
        val request = requests.data[requestIndex];
        val functionStart =
            nodes.data[request.functionRoot].subtreeStart;
        var nestedIndex = functionStart;
        while (nestedIndex < request.functionRoot) {
            val nestedCall = nodes.data[nestedIndex];
            if (nestedCall.kind == 16) {
            if (nestedCall.genericArgumentCount > 0) {
                val calleeRoot =
                    callCalleeRoot(nodes, nestedIndex);
                val callee = nodes.data[calleeRoot];
                val nestedFunctionRoot =
                    functionRootByName(
                        source, nodes,
                        sourceHash(
                            source, callee.start, callee.end));
                if (nestedFunctionRoot != nodes.length) {
                    val concreteStart = genericArguments.length;
                    var nestedArgument: u32 = 0;
                    while (nestedArgument <
                            nestedCall.genericArgumentCount) {
                        val pattern = genericArguments.data[
                            nestedCall.genericArgumentStart +
                            nestedArgument as u64];
                        val concrete = substituteEmitterType(
                            source, nodes, request.functionRoot,
                            pattern, genericArguments,
                            request.argumentStart,
                            request.argumentCount);
                        genericArguments.add(concrete);
                        nestedArgument = nestedArgument + 1;
                    }
                    if (
                        !specializationRequestExists(
                            requests, genericArguments,
                            nestedFunctionRoot, concreteStart,
                            nestedCall.genericArgumentCount
                        )
                    ) {
                        specializationRequestListAppend(
                            requests,
                            SpecializationRequest(
                                nestedFunctionRoot, concreteStart,
                                nestedCall.genericArgumentCount));
                    }
                }
            }
            }
            nestedIndex = nestedIndex + 1;
        }
        requestIndex = requestIndex + 1;
    }
    requestIndex = 0;
    while (requestIndex < requests.length) {
        val request = requests.data[requestIndex];
        emitSpecializedFunction(
            buffer, source, nodes, genericArguments,
            request.functionRoot, request.argumentStart,
            request.argumentCount);
        requestIndex = requestIndex + 1;
    }
    specializationRequestListFree(requests);
    k_boot_free(roots as unit*);
    return buffer;
}
