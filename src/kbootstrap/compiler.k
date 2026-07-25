module kbootstrap.compiler;

import kbootstrap.*;

extern fn k_boot_write_file(
    path: u8*, pathLength: u64, data: u8*, length: u64): bool;
extern fn k_boot_run(command: u8*, commandLength: u64): i32;
extern fn k_boot_stderr(data: u8*, length: u64);

fn appendRaw(
    var buffer: ByteBuffer, data: u8*, length: u64) {
    var index: u64 = 0;
    while (index < length) {
        byteBufferAppend(buffer, data[index]);
        index = index + 1;
    }
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

fn compileToLl(
    sourceData: u8*,
    sourceLength: u64,
    outputPath: u8*,
    outputPathLength: u64,
    optPath: u8*,
    optPathLength: u64): i32 {
    val source = Source(sourceData, sourceLength);
    val lexed = lex(source);
    if (lexed.ok == false) {
        tokenListFree(lexed.tokens);
        return 2;
    }
    val parsed = parse(lexed.tokens);
    if (parsed.ok == false) {
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 2;
    }
    var checked = analyze(source, parsed.nodes);
    if (checked.ok == false) {
        printDiagnostic(source, checked.category, checked.start, checked.end);
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
    if (written == false) {
        byteBufferFree(temporaryPath);
        byteBufferFree(output);
        typeValueListFree(checked.genericArguments);
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 2;
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
        return 2;
    }
    val published = k_boot_write_file(
        outputPath, outputPathLength, output.data, output.length);
    byteBufferFree(temporaryPath);
    byteBufferFree(output);
    typeValueListFree(checked.genericArguments);
    astListFree(parsed.nodes);
    tokenListFree(lexed.tokens);
    if (published) { return 0; }
    return 0;
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
    if (result == 0) { return 0; }
    return 2;
}

fn findLine(source: Source, offset: u64): u64 {
    var line: u64 = 1;
    var index: u64 = 0;
    while (index < offset) {
        if (source.data[index] == 10) { line = line + 1; }
        index = index + 1;
    }
    return line;
}

fn findColumn(source: Source, offset: u64): u64 {
    var col: u64 = 1;
    var index = offset;
    while (index > 0) {
        index = index - 1;
        if (source.data[index] == 10) { return col; }
        col = col + 1;
    }
    return col;
}

fn stderrWrite(data: u8*, length: u64) {
    k_boot_stderr(data, length);
}

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
    if (category == 1) {
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
    } else {
        if (category == 2) {
            byteBufferAppend(buffer, 117); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 107); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 111); byteBufferAppend(buffer, 119);
            byteBufferAppend(buffer, 110); byteBufferAppend(buffer, 32);
            byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 100);
            byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 110);
            byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 102); byteBufferAppend(buffer, 105);
            byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 114);
        } else {
            if (category == 3) {
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
            } else {
                if (category == 4) {
                    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 121);
                    byteBufferAppend(buffer, 112); byteBufferAppend(buffer, 101);
                    byteBufferAppend(buffer, 32); byteBufferAppend(buffer, 109);
                    byteBufferAppend(buffer, 105); byteBufferAppend(buffer, 115);
                    byteBufferAppend(buffer, 109); byteBufferAppend(buffer, 97);
                    byteBufferAppend(buffer, 116); byteBufferAppend(buffer, 99);
                    byteBufferAppend(buffer, 104);
                } else {
                    if (category == 5) {
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
                    } else {
                        if (category == 6) {
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
                        } else {
                            if (category == 7) {
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
                            } else {
                                if (category == 8) {
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
                                } else {
                                    byteBufferAppend(buffer, 101); byteBufferAppend(buffer, 114);
                                    byteBufferAppend(buffer, 114); byteBufferAppend(buffer, 111);
                                    byteBufferAppend(buffer, 114);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fn printDiagnostic(source: Source, category: u32, start: u64, end: u64) {
    var buf = byteBufferNew();
    val lineNum = stderrNumber(findLine(source, start));
    appendRaw(buf, lineNum.data, lineNum.length);
    byteBufferFree(lineNum);
    byteBufferAppend(buf, 58);
    val colNum = stderrNumber(findColumn(source, start));
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
