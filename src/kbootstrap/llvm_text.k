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
    if (node.end - node.start != 5) { return false; }
    if (source.data[node.start] != 112) { return false; }
    if (source.data[node.start + 1] != 114) { return false; }
    if (source.data[node.start + 2] != 105) { return false; }
    if (source.data[node.start + 3] != 110) { return false; }
    return source.data[node.start + 4] == 116;
}

fn appendOperator(
    var buffer: ByteBuffer, kind: u32, typeKind: u32) {
    var floating = typeKind == 17;
    if (typeKind == 18) { floating = true; }
    if (floating) { byteBufferAppend(buffer, 102); }
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
        if (typeKind == 6) { unsigned = true; }
        if (typeKind == 7) { unsigned = true; }
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
        if (typeKind == 6) { unsigned = true; }
        if (typeKind == 7) { unsigned = true; }
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
    if (kind == 1) { byteBufferAppend(buffer, 115); }
    if (kind == 2) { byteBufferAppend(buffer, 122); }
    if (kind <= 2) {
        byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 120);
        byteBufferAppend(buffer, 116); return;
    }
    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
    byteBufferAppend(buffer, 99);
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
    if (kind == 3) { byteBufferAppend(buffer, 115); }
    if (kind == 4) { byteBufferAppend(buffer, 117); }
    var integerToFloat = kind == 3;
    if (kind == 4) { integerToFloat = true; }
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
    appendSix: bool) {
    if (negative) { byteBufferAppend(buffer, 45); }
    appendDecimal(buffer, magnitude);
    if (appendSix) { byteBufferAppend(buffer, 54); }
    byteBufferAppend(buffer, 46); byteBufferAppend(buffer, 48);
}

fn appendFloatCastBound(
    var buffer: ByteBuffer, sourceKind: u32, targetKind: u32,
    lower: bool) {
    if (lower) {
        if (targetKind == 3) {
            var magnitude: u64 = 2147483649;
            if (sourceKind == 17) { magnitude = 2147483648; }
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
struct IrCounter(value: u64, block: u64, currentBlock: u64)

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
    if (kind == 3) { appendI32(buffer); }
    if (kind == 4) {
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 54);
        byteBufferAppend(buffer, 52);
    }
    if (kind == 5) {
        byteBufferAppend(buffer, 105);
        byteBufferAppend(buffer, 56);
    }
    if (kind == 6) { appendI32(buffer); }
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
        byteBufferAppend(buffer, 112);
        byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 114);
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
    if (kind == 11) { appendI32(buffer); }
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

fn emitterStructTypeParameterRoot(
    source: Source, nodes: AstList, structureRoot: u64, position: u32): u64 {
    val structure = nodes.data[structureRoot];
    var root = structureRoot - 1;
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
        if (position >= count) { return invalidType(); }
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
    var root = structureRoot - 1;
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
    if (kind == 2) { return 1; }
    if (kind == 5) { return 1; }
    if (kind == 3) { return 4; }
    if (kind == 6) { return 4; }
    if (kind == 11) { return 4; }
    if (kind == 17) { return 4; }
    if (kind == 4) { return 8; }
    if (kind == 7) { return 8; }
    if (kind == 9) { return 8; }
    if (kind == 10) { return 8; }
    if (kind == 18) { return 8; }
    if (kind == 13) { return 8; }
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
    if (kind == 1) { return 0; }
    if (kind == 2) { return 1; }
    if (kind == 5) { return 1; }
    if (kind == 3) { return 4; }
    if (kind == 6) { return 4; }
    if (kind == 11) { return 4; }
    if (kind == 17) { return 4; }
    if (kind == 4) { return 8; }
    if (kind == 7) { return 8; }
    if (kind == 9) { return 8; }
    if (kind == 10) { return 8; }
    if (kind == 18) { return 8; }
    if (kind == 13) { return 16; }
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
    if (typeKind == 6) { unsigned = true; }
    if (typeKind == 7) { unsigned = true; }
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
            if (value.typeKind == 17) { inclusive = true; }
        }
        byteBufferAppend(buffer, 103);
        if (inclusive) { byteBufferAppend(buffer, 101); }
        else { byteBufferAppend(buffer, 116); }
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
        return IrValue(
            1, node.start, node.end, 0,
            node.typeKind, node.typeName, node.typePointee);
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
            if (isFloatType(TypeValue(
                    node.typeKind, node.typeName, node.typePointee))) {
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
        return operand;
    }
    if (node.kind == 10) {
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
        val left = emitExpression(
            buffer, source, nodes, genericArguments,
            leftRoot, counter);
        var logical = node.aux == 83;
        if (node.aux == 84) { logical = true; }
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
            if (node.aux == 83) { byteBufferAppend(buffer, 48); }
            else { byteBufferAppend(buffer, 49); }
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
        val right = emitExpression(
            buffer, source, nodes, genericArguments,
            rightRoot, counter);
        val temporary = nextTemporary(counter);
        appendValuePrefix(buffer);
        appendDecimal(buffer, temporary);
        appendEquals(buffer);
        var comparison = false;
        if (node.aux == 66) { comparison = true; }
        if (node.aux == 67) { comparison = true; }
        if (node.aux >= 79) {
            if (node.aux <= 82) { comparison = true; }
        }
        if (comparison) {
            appendComparison(buffer, node.aux, left.typeKind);
        } else {
            appendOperator(buffer, node.aux, node.typeKind);
        }
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
        val right = emitExpression(
            buffer, source, nodes, genericArguments,
            rightRoot, counter);
        val target = emitAddress(
            buffer, source, nodes, genericArguments,
            leftRoot, counter);
        val targetNode = nodes.data[leftRoot];
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
        if (node.typeKind == value.typeKind) { return value; }
        if (node.typeKind == 9) { return value; }
        if (value.typeKind == 9) { return value; }
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
            if (isIntegerType(sourceType)) {
                opcode = 4;
                if (integerTypeIsSigned(sourceType)) { opcode = 3; }
            } else {
                if (isIntegerType(targetType)) {
                    opcode = 6;
                    if (integerTypeIsSigned(targetType)) { opcode = 5; }
                } else {
                    if (node.typeKind == 17) { opcode = 2; }
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
        val sourceWidth = integerTypeWidth(sourceType);
        val targetWidth = integerTypeWidth(targetType);
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
                if (integerTypeIsSigned(sourceType)) { opcode = 1; }
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
                if (integerTypeIsSigned(targetType)) { reverseOpcode = 1; }
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
                var sourceSigned = integerTypeIsSigned(sourceType);
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
                    if (sourceWidth == 32) { appendDecimal(buffer, 2147483647); }
                    else { appendDecimal(buffer, 9223372036854775807); }
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
        val objectRoot = root - 1;
        val objectNode = nodes.data[objectRoot];
        val structureRoot =
            structRootByName(
                source, nodes, objectNode.typeName);
        val structure = nodes.data[structureRoot];
        val start = objectNode.typePointee % 65536;
        val count = objectNode.typePointee / 65536;
        
        var addressable = objectNode.kind == 10;
        if (objectNode.kind == 17) { addressable = true; }
        if (objectNode.kind == 18) { addressable = true; }
        if (objectNode.kind == 12) {
            if (objectNode.aux == 62) { addressable = true; }
        }
        if (addressable == false) {
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
        val argumentCount = node.aux % 65536;
        val explicitTypeCount = node.aux / 65536;
        val arguments =
            k_boot_alloc(
                (argumentCount as u64) * sizeof(u64)) as u64*;
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
        val calleeHash =
            sourceHash(source, callee.start, callee.end);
        val functionRoot =
            functionRootByName(source, nodes, calleeHash);
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
                if (parameter.aux == 2) { byReference = true; }
            }
            if (byReference) {
                values[index as u64] = emitAddress(
                    buffer, source, nodes, genericArguments,
                    arguments[index as u64], counter);
            } else {
                values[index as u64] = emitExpression(
                    buffer, source, nodes, genericArguments,
                    arguments[index as u64], counter);
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
            appendSource(
                buffer, source, callee.start, callee.end);
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
        if (isPrint) { return IrValue(3, 0, 0, 0, 1, 0, 0); }
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
        if (terminated == false) {
            terminated = emitStatement(
                buffer, source, nodes, genericArguments,
                roots[index as u64], counter);
        }
        index = index + 1;
    }
    k_boot_free(roots as unit*);
    return terminated;
}

fn emitStatement(
    var buffer: ByteBuffer,
    source: Source,
    nodes: AstList,
    genericArguments: TypeValueList,
    root: u64,
    var counter: IrCounter): bool {
    val statement = nodes.data[root];
    if (statement.kind == 33) {
        val initializerRoot = root - 1;
        val initializer = emitExpression(
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
                var returned = value;
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
                    if (thenTerminated == false) {
                        appendBranch(buffer, endBlock);
                    }
                    var elseTerminated = false;
                    if (statement.aux == 1) {
                        appendBlockLabel(buffer, counter, elseBlock);
                        elseTerminated = emitBlock(
                            buffer, source, nodes, genericArguments,
                            elseRoot, counter);
                        if (elseTerminated == false) {
                            appendBranch(buffer, endBlock);
                        }
                    }
                    if (thenTerminated == false) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    if (statement.aux == 0) {
                        appendBlockLabel(buffer, counter, endBlock);
                        return false;
                    }
                    if (elseTerminated == false) {
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
                    val bodyTerminated = emitBlock(
                        buffer, source, nodes, genericArguments,
                        bodyRoot, counter);
                    if (bodyTerminated == false) {
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
    if (functionIsExtern(function) == false) {
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
    if (pattern.kind != 14) { return pattern; }
    val position = emitterTypeParameterPosition(
        source, nodes, functionRoot, pattern.name);
    if (position >= count) { return invalidType(); }
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
    appendNodeType(buffer, genericArguments, returnType);
    appendFunctionOpen(buffer);
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

    var counter = IrCounter(0, 0, 18446744073709551615);
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
    if (terminated == false) {
        if (returnType.typeKind == 1) {
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
    if (functionParameterCount(function) != 0) { return false; }
    if (functionTypeParameterCount(function) != 0) { return false; }
    val returnTypeRoot = nodes.data[functionRoot - 1].subtreeStart - 1;
    if (nodes.data[returnTypeRoot].aux != 35) { return false; }
    val name = nodes.data[function.subtreeStart];
    val blockRoot = functionRoot - 1;
    if (nodes.data[blockRoot].aux != 1) { return false; }
    val statementRoot = firstStatementRoot(nodes, blockRoot);
    val statement = nodes.data[statementRoot];
    if (statement.kind != 34) { return false; }
    if (statement.aux != 1) { return false; }
    val literal = nodes.data[statementRoot - 1];
    if (literal.kind != 11) { return false; }
    if (literal.aux != 2) { return false; }

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
    if (fieldCount > 0) { byteBufferAppend(buffer, 32); }
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
    if (fieldCount > 0) { byteBufferAppend(buffer, 32); }
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
    if (leftCount != rightCount) { return false; }
    var index: u32 = 0;
    while (index < leftCount) {
        if (typeEquals(
                arguments.data[leftStart + index as u64],
                arguments.data[rightStart + index as u64], arguments) == false) {
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
    if (call.genericArgumentCount == 0) { return false; }
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
                        if (structSpecializationRequestExists(
                                structRequests, genericArguments,
                                structureRoot, start as u64, count) == false) {
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
                    if (specializationRequestExists(
                            requests, genericArguments,
                            functionRoot,
                            call.genericArgumentStart,
                            call.genericArgumentCount) == false) {
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
                        typeValueListAppend(
                            genericArguments, concrete);
                        nestedArgument = nestedArgument + 1;
                    }
                    if (specializationRequestExists(
                            requests, genericArguments,
                            nestedFunctionRoot, concreteStart,
                            nestedCall.genericArgumentCount) == false) {
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
