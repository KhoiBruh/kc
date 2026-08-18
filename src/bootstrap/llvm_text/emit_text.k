module bootstrap.llvm_text.emit_text;

import bootstrap.*;
import bootstrap.token.TokenKind;

fn appendDecimal(var buffer: StringBuilder, value: u64) {
    val digits = k_boot_alloc(20) as u8*;
    var remaining = value;
    var length: u64 = 0;
    if (remaining == 0) {
        buffer.append("0");
    } else {
        while (remaining > 0) {
            digits[length] = (remaining % 10) as u8 + 48;
            remaining /= 10;
            length++;
        }
        for (index in length>..0) buffer.add(digits[index]);
    }
    k_boot_free(digits as unit*);
}

fn appendSource(
    var buffer: StringBuilder, source: Source, start: u64, end: u64) {
    for (offset in start..<end) {
        buffer.add(source.data[offset]);
    }
}

fn appendDefine(var buffer: StringBuilder) {
    buffer.append("define ");
}

fn appendI32(var buffer: StringBuilder) => buffer.append("i32");

fn appendFunctionOpen(var buffer: StringBuilder) => buffer.append(" @");

fn appendEmptyParameters(var buffer: StringBuilder) => buffer.append("() {\n");

fn appendEntry(var buffer: StringBuilder) => buffer.append("entry:\n  ");

fn appendReturnI32(var buffer: StringBuilder) {
    buffer.append("ret ");
    appendI32(buffer);
    buffer.append(" ");
}

fn appendFunctionClose(var buffer: StringBuilder) => buffer.append("\n}\n");

fn appendValuePrefix(var buffer: StringBuilder) => buffer.append("  %");

fn appendEquals(var buffer: StringBuilder) => buffer.append(" = ");

fn appendLoad(var buffer: StringBuilder) => buffer.append("load ");

fn appendStore(var buffer: StringBuilder) {
    buffer.append("  store ");
}

fn appendPtr(var buffer: StringBuilder) {
    buffer.append(", ptr %");
}

fn appendAlloca(var buffer: StringBuilder) => buffer.append("alloca ");

fn appendCall(var buffer: StringBuilder) => buffer.append("call ");

fn appendPrintDeclaration(var buffer: StringBuilder) {
    buffer.append("declare void @k_std_print_i32(i32)\n\n");
    appendPrintBytesDeclaration(buffer);
}
fn appendPrintBytesDeclaration(var buffer: StringBuilder) {
    buffer.append("declare void @k_std_print_bytes(ptr, i64)\n\n");
}

fn appendPanicDeclaration(var buffer: StringBuilder) {
    buffer.append("declare void @k_boot_panic(ptr, i64)\n\n");
}

fn appendModuleHeader(var buffer: StringBuilder) {
    buffer.append("target datalayout = \"e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128\"\ntarget triple = \"x86_64-pc-windows-msvc\"\n\n");
}

fn sourceNodeIsPrint(source: Source, node: AstNode): bool {
    if (node.end - node.start != 5) return false;
    if (source.data[node.start] != 112) return false;
    if (source.data[node.start + 1] != 114) return false;
    if (source.data[node.start + 2] != 105) return false;
    if (source.data[node.start + 3] != 110) return false;
    return source.data[node.start + 4] == 116;
}

fn appendOperator(var buffer: StringBuilder, kind: u32, typeKind: u32) {
    var floating = typeKind == TypeKind.F32.value;
    if (typeKind == TypeKind.F64.value) floating = true;
    if (floating) buffer.append("f");
    if (kind == TokenKind.Plus.value) {
        buffer.append("add");
    }
    if (kind == TokenKind.Minus.value) {
        buffer.append("sub");
    }
    if (kind == TokenKind.Star.value) {
        buffer.append("mul");
    }
    if (kind == TokenKind.Slash.value) {
        if (floating) {
            buffer.append("di");
            buffer.append("v"); return;
        }
        var unsigned = typeKind == TypeKind.U8.value;
        if (typeKind == TypeKind.U32.value) unsigned = true;
        if (typeKind == TypeKind.U64.value) unsigned = true;
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("div");
    }
    if (kind == TokenKind.Percent.value) {
        if (floating) {
            buffer.append("re");
            buffer.append("m"); return;
        }
        var unsigned = typeKind == TypeKind.U8.value;
        if (typeKind == TypeKind.U32.value) unsigned = true;
        if (typeKind == TypeKind.U64.value) unsigned = true;
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("rem");
    }
}

fn appendNewline(var buffer: StringBuilder) => buffer.append("\n");

fn appendCastOpcode(var buffer: StringBuilder, kind: u32) {
    when (kind) {
        1 -> buffer.append("s");
        2 -> buffer.append("z");
        else -> {
            buffer.append("trunc");
            return;
        }
    }
    buffer.append("ext");
}

fn appendFloatCastOpcode(var buffer: StringBuilder, kind: u32) {
    if (kind == 1) {
        buffer.append("fpex");
        buffer.append("t"); return;
    }
    if (kind == 2) {
        buffer.append("fptrun");
        buffer.append("c"); return;
    }
    if (kind == 3) buffer.append("s");
    if (kind == 4) buffer.append("u");
    var integerToFloat = kind == 3;
    if (kind == 4) integerToFloat = true;
    if (integerToFloat) {
        buffer.append("itof");
        buffer.append("p"); return;
    }
    buffer.append("fpto");
    if (kind == 5) {
        buffer.append("si");
    } else {
        buffer.append("ui");
    }
}

fn appendFloatIntegerConstant(
    var buffer: StringBuilder, negative: bool, magnitude: u64,
    appendSix: bool
) {
    if (negative) buffer.append("-");
    appendDecimal(buffer, magnitude);
    if (appendSix) buffer.append("6");
    buffer.append(".0");
}

fn appendFloatCastBound(
    var buffer: StringBuilder, sourceKind: u32, targetKind: u32,
    lower: bool
) {
    if (lower) {
        if (targetKind == TypeKind.I32.value) {
            var magnitude: u64 = 2147483649;
            if (sourceKind == TypeKind.F32.value) magnitude = 2147483648;
            appendFloatIntegerConstant(buffer, true, magnitude, false);
            return;
        }
        if (targetKind == TypeKind.I64.value) {
            appendFloatIntegerConstant(
                buffer, true, 9223372036854775808, false);
            return;
        }
        appendFloatIntegerConstant(buffer, true, 1, false);
        return;
    }
    if (targetKind == TypeKind.I32.value) {
        appendFloatIntegerConstant(buffer, false, 2147483648, false);
    } else {
        if (targetKind == TypeKind.I64.value) {
            appendFloatIntegerConstant(
                buffer, false, 9223372036854775808, false);
        } else {
            if (targetKind == TypeKind.U8.value) {
                appendFloatIntegerConstant(buffer, false, 256, false);
            }
            if (targetKind == TypeKind.U32.value) {
                appendFloatIntegerConstant(buffer, false, 4294967296, false);
            }
            if (targetKind == TypeKind.U64.value) {
                appendFloatIntegerConstant(
                    buffer, false, 1844674407370955161, true);
            }
        }
    }
}

fn appendCastPanic(var buffer: StringBuilder) {
    buffer.append("  call void @k_boot_panic(ptr null, i64 0)");
    appendNewline(buffer);
    buffer.append("  unreachabl");
    buffer.append("e"); appendNewline(buffer);
}

fn appendLocalPrefix(var buffer: StringBuilder) {
    buffer.append("local.");
}

fn appendOwnedStringDeclarations(var buffer: StringBuilder) {
    buffer.append("declare ptr @k_std_alloc(i64)\ndeclare void @k_std_free(ptr)\n\n");
}

fn appendDropFlagName(var buffer: StringBuilder, storage: u64) {
    appendLocalPrefix(buffer);
    appendDecimal(buffer, storage);
    buffer.append(".drop");
}

fn appendI64(var buffer: StringBuilder) {
    buffer.append("i64");
}

fn appendGetElementPtr(var buffer: StringBuilder) {
    buffer.append("getelementptr");
}

fn appendInsertValue(var buffer: StringBuilder) {
    buffer.append("insertvalue");
}

fn appendExtractValue(var buffer: StringBuilder) {
    buffer.append("extractvalue");
}

fn appendUndef(var buffer: StringBuilder) {
    buffer.append("undef");
}

fn appendUnreachable(var buffer: StringBuilder) {
    buffer.append("unreachable");
}

fn appendComparison(
    var buffer: StringBuilder, kind: u32, typeKind: u32) {
    buffer.append("icmp ");
    if (kind == TokenKind.EqualEqual.value) {
        buffer.append("eq");
    }
    if (kind == TokenKind.BangEqual.value) {
        buffer.append("ne");
    }
    var unsigned = typeKind == TypeKind.U8.value;
    if (typeKind == TypeKind.U32.value) unsigned = true;
    if (typeKind == TypeKind.U64.value) unsigned = true;
    if (typeKind == TypeKind.Enum.value) unsigned = true;
    if (kind == TokenKind.Less.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("lt");
    }
    if (kind == TokenKind.LessEqual.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("le");
    }
    if (kind == TokenKind.Greater.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("gt");
    }
    if (kind == TokenKind.GreaterEqual.value) {
        if (unsigned) {
            buffer.append("u");
        } else {
            buffer.append("s");
        }
        buffer.append("ge");
    }
}
