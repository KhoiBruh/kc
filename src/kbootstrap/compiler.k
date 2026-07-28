module kbootstrap.compiler;

import kbootstrap.*;
import kbootstrap.loader.LoadResult;

extern fn k_boot_write_file(path: u8*, pathLength: u64, data: u8*, length: u64): bool;
extern fn k_boot_run(command: u8*, commandLength: u64): i32;

fn appendRaw(
    var buffer: ByteBuffer, data: u8*, length: u64) {
    for (i in 0..<length) byteBufferAppend(buffer, data[i]);
}

fn appendQuoted(
    var buffer: ByteBuffer, data: u8*, length: u64) {
    byteBufferAppend(buffer, 34);
    appendRaw(buffer, data, length);
    byteBufferAppend(buffer, 34);
}

fn appendVerifyFlags(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 61);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 114);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 102);
    byteBufferAppend(buffer, 121);
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 100);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 115);
    byteBufferAppend(buffer, 97);
    byteBufferAppend(buffer, 98);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 112);
    byteBufferAppend(buffer, 117);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 32);
}

fn appendOutputFlag(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 111);
    byteBufferAppend(buffer, 32);
}

fn appendEmitLlFlag(var buffer: ByteBuffer) {
    byteBufferAppend(buffer, 32);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 101);
    byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 105);
    byteBufferAppend(buffer, 116);
    byteBufferAppend(buffer, 45);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 108);
    byteBufferAppend(buffer, 118);
    byteBufferAppend(buffer, 109);
    byteBufferAppend(buffer, 32);
}

fn compilerFailure(kind: u32) {
    var message = byteBufferNew();
    byteBufferAppend(message, 101); byteBufferAppend(message, 114);
    byteBufferAppend(message, 114); byteBufferAppend(message, 111);
    byteBufferAppend(message, 114); byteBufferAppend(message, 58);
    byteBufferAppend(message, 32); byteBufferAppend(message, 99);
    byteBufferAppend(message, 97); byteBufferAppend(message, 110);
    byteBufferAppend(message, 110); byteBufferAppend(message, 111);
    byteBufferAppend(message, 116); byteBufferAppend(message, 32);
    when (kind) {
        1 -> {
            byteBufferAppend(message, 119); byteBufferAppend(message, 114);
            byteBufferAppend(message, 105); byteBufferAppend(message, 116);
            byteBufferAppend(message, 101); byteBufferAppend(message, 32);
            byteBufferAppend(message, 76); byteBufferAppend(message, 76);
            byteBufferAppend(message, 86); byteBufferAppend(message, 77);
            byteBufferAppend(message, 32); byteBufferAppend(message, 111);
            byteBufferAppend(message, 117); byteBufferAppend(message, 116);
            byteBufferAppend(message, 112); byteBufferAppend(message, 117);
            byteBufferAppend(message, 116);
        }
        2 -> {
            byteBufferAppend(message, 108); byteBufferAppend(message, 97);
            byteBufferAppend(message, 117); byteBufferAppend(message, 110);
            byteBufferAppend(message, 99); byteBufferAppend(message, 104);
            byteBufferAppend(message, 32); byteBufferAppend(message, 111);
            byteBufferAppend(message, 112); byteBufferAppend(message, 116);
        }
        else -> {
            byteBufferAppend(message, 108); byteBufferAppend(message, 97);
            byteBufferAppend(message, 117); byteBufferAppend(message, 110);
            byteBufferAppend(message, 99); byteBufferAppend(message, 104);
            byteBufferAppend(message, 32); byteBufferAppend(message, 99);
            byteBufferAppend(message, 108); byteBufferAppend(message, 97);
            byteBufferAppend(message, 110); byteBufferAppend(message, 103);
        }
    }
    byteBufferAppend(message, 10);
    k_boot_stderr(message.data, message.length);
    byteBufferFree(message);
}

fn compileToLl(
    sourceData: u8*,
    sourceLength: u64,
    sourceMap: SourceMap,
    outputPath: u8*,
    outputPathLength: u64,
    optPath: u8*,
    optPathLength: u64
): i32 {
    val source = Source(sourceData, sourceLength);
    val lexed = lex(source);
    if (!lexed.ok) {
        printDiagnostic(
            source, sourceMap, 99 + lexed.errorKind,
            lexed.errorStart, lexed.errorStart + 1);
        tokenListFree(lexed.tokens);
        return 2;
    }
    val parsed = parse(lexed.tokens);
    if (!parsed.ok) {
        printDiagnostic(
            source, sourceMap, 1000 + parsed.expectedKind,
            parsed.errorStart, parsed.errorStart + 1);
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 2;
    }
    var checked = analyze(source, parsed.nodes);
    if (!checked.ok) {
        printDiagnostic(
            source, sourceMap, checked.category, checked.start, checked.end);
        typeValueListFree(checked.genericArguments);
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 2;
    }
    var resolvedArguments = checked.genericArguments;
    val output =
        emitModule(source, parsed.nodes, resolvedArguments);
    checked.genericArguments = resolvedArguments;
    var temporaryPath = byteBufferNew();
    appendRaw(temporaryPath, outputPath, outputPathLength);
    byteBufferAppend(temporaryPath, 46);
    byteBufferAppend(temporaryPath, 116);
    byteBufferAppend(temporaryPath, 109);
    byteBufferAppend(temporaryPath, 112);
    byteBufferAppend(temporaryPath, 46);
    byteBufferAppend(temporaryPath, 108);
    byteBufferAppend(temporaryPath, 108);
    val written = k_boot_write_file(
        temporaryPath.data, temporaryPath.length, output.data, output.length);
    if (!written) {
        compilerFailure(1);
        byteBufferFree(temporaryPath);
        byteBufferFree(output);
        typeValueListFree(checked.genericArguments);
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 1;
    }
    var verifyCommand = byteBufferNew();
    appendQuoted(verifyCommand, optPath, optPathLength);
    appendVerifyFlags(verifyCommand);
    appendQuoted(
        verifyCommand, temporaryPath.data, temporaryPath.length);
    val verified =
        k_boot_run(verifyCommand.data, verifyCommand.length);
    byteBufferFree(verifyCommand);
    if (verified != 0) {
        byteBufferFree(temporaryPath);
        byteBufferFree(output);
        typeValueListFree(checked.genericArguments);
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        if (verified < 0) { compilerFailure(2); return 1; }
        return 2;
    }
    val published = k_boot_write_file(
        outputPath, outputPathLength, output.data, output.length);
    byteBufferFree(temporaryPath);
    byteBufferFree(output);
    typeValueListFree(checked.genericArguments);
    astListFree(parsed.nodes);
    tokenListFree(lexed.tokens);
    if (published) return 0;
    compilerFailure(1);
    return 1;
}

fn linkLl(
    llPath: u8*, llPathLength: u64,
    clangPath: u8*, clangPathLength: u64,
    stdRuntime: u8*, stdRuntimeLength: u64,
    bootstrapRuntime: u8*, bootstrapRuntimeLength: u64,
    executablePath: u8*, executablePathLength: u64
): i32 {
    var command = byteBufferNew();
    appendQuoted(command, clangPath, clangPathLength);
    byteBufferAppend(command, 32);
    appendQuoted(command, llPath, llPathLength);
    byteBufferAppend(command, 32);
    appendQuoted(command, stdRuntime, stdRuntimeLength);
    byteBufferAppend(command, 32);
    appendQuoted(command, bootstrapRuntime, bootstrapRuntimeLength);
    appendOutputFlag(command);
    appendQuoted(command, executablePath, executablePathLength);
    val result = k_boot_run(command.data, command.length);
    byteBufferFree(command);
    if (result == 0) return 0;
    if (result < 0) { compilerFailure(3); return 1; }
    return 2;
}

fn findLine(source: Source, sourceStart: u64, offset: u64): u64 {
    var line: u64 = 1;
    for (i in sourceStart..<offset) if (source.data[i] == 10) line = line + 1;
    return line;
}

fn findColumn(source: Source, sourceStart: u64, offset: u64): u64 {
    var col: u64 = 1;
    var index = offset;
    while (index > sourceStart) {
        index = index - 1;
        if (source.data[index] == 10) return col;
        col = col + 1;
    }
    return col;
}

fn stderrWrite(data: u8*, length: u64) => k_boot_stderr(data, length);

fn stderrNumber(value: u64): ByteBuffer {
    var buf = byteBufferNew();
    if (value == 0) {
        byteBufferAppend(buf, 48);
        return buf;
    }
    val start = buf.length;
    var v = value;
    while (v > 0) {
        byteBufferAppend(buf, 48 + (v % 10) as u8);
        v = v / 10;
    }
    var i = start;
    var j = buf.length - 1;
    while (i < j) {
        val tmp = buf.data[i];
        buf.data[i] = buf.data[j];
        buf.data[j] = tmp;
        i = i + 1;
        j = j - 1;
    }
    return buf;
}

fn appendErrorMessage(var buffer: ByteBuffer, category: u32) {
    if (category >= 1000) {
        byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 120);
        byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 101);
        byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 116);
        byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 100);
        byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 39);
        val kind = category - 1000;
        when (kind) {
            1 -> {
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 102);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 114);
            }
            50 -> byteBufferAppend(buffer, 40);
            51 -> byteBufferAppend(buffer, 41);
            52 -> byteBufferAppend(buffer, 123);
            53 -> byteBufferAppend(buffer, 125);
            54 -> byteBufferAppend(buffer, 91);
            55 -> byteBufferAppend(buffer, 93);
            56 -> byteBufferAppend(buffer, 44);
            57 -> byteBufferAppend(buffer, 58);
            58 -> byteBufferAppend(buffer, 59);
            59 -> byteBufferAppend(buffer, 46);
            67 -> byteBufferAppend(buffer, 61);
            else -> {
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 107); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 110);
            }
        }
        byteBufferAppend(buffer, 39);
    } else {
        when (category) {
            100 -> {
                byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 109);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 100);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 115);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 103);
            }
            101 -> {
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 118); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 104);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 114);
            }
            1 -> {
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 117);
                byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 108);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 108);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 110);
            }
            2 -> {
                byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 107); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 119);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 100);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 114);
            }
            3 -> {
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 103); byteBufferAppend(buffer, 117);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 117);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 109);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 115);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 104);
            }
            4 -> {
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 121);
                byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 109);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 115);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 104);
            }
            5 -> {
                byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 117);
                byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 121); byteBufferAppend(buffer, 112);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 109);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 99);
            }
            6 -> {
                byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 100);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 117);
                byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 98);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 98); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 108);
            }
            7 -> {
                byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 115); byteBufferAppend(buffer, 115);
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 103);
                byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 109);
                byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 116);
                byteBufferAppend(buffer, 97); byteBufferAppend(buffer, 98);
                byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 101);
            }
            8 -> {
                byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 110);
                byteBufferAppend(buffer, 118); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 108); byteBufferAppend(buffer, 105);
                byteBufferAppend(buffer, 100); byteBufferAppend(buffer, 32);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 101);
                byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 98);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 97);
                byteBufferAppend(buffer, 99); byteBufferAppend(buffer, 99);
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 115);
                byteBufferAppend(buffer, 115);
            }
            else -> {
                byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 114);
                byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 111);
                byteBufferAppend(buffer, 114);
            }
        }
    }
}

fn printDiagnostic(
    source: Source, sourceMap: SourceMap,
    category: u32, start: u64, end: u64
) {
    var buf = byteBufferNew();
    var sourceStart: u64 = 0;
    var segmentIndex: u64 = 0;
    var found = false;
    while (segmentIndex < sourceMap.length) {
        val segment = sourceMap.data[segmentIndex];
        if (!found) {
            if (start >= segment.sourceStart) {
                if (start <= segment.sourceStart + segment.sourceLength) {
                    appendRaw(buf, segment.path, segment.pathLength);
                    byteBufferAppend(buf, 58);
                    sourceStart = segment.sourceStart;
                    found = true;
                }
            }
        }
        segmentIndex = segmentIndex + 1;
    }
    val lineNum = stderrNumber(findLine(source, sourceStart, start));
    appendRaw(buf, lineNum.data, lineNum.length);
    byteBufferFree(lineNum);
    byteBufferAppend(buf, 58);
    val colNum = stderrNumber(findColumn(source, sourceStart, start));
    appendRaw(buf, colNum.data, colNum.length);
    byteBufferFree(colNum);
    byteBufferAppend(buf, 58);
    byteBufferAppend(buf, 32);
    byteBufferAppend(buf, 101);
    byteBufferAppend(buf, 114);
    byteBufferAppend(buf, 114);
    byteBufferAppend(buf, 111);
    byteBufferAppend(buf, 114);
    byteBufferAppend(buf, 58);
    byteBufferAppend(buf, 32);
    appendErrorMessage(buf, category);
    byteBufferAppend(buf, 10);
    k_boot_stderr(buf.data, buf.length);
    byteBufferFree(buf);
}
