module kbootstrap.compiler;

import kbootstrap.*;
import kbootstrap.loader.LoadResult;

extern fn k_boot_write_file(path: u8*, pathLength: u64, data: u8*, length: u64): bool;
extern fn k_boot_run(command: u8*, commandLength: u64): i32;

fn appendRaw(var buffer: ByteBuffer, data: u8*, length: u64) {
    for (i in 0..<length) buffer.add(data[i]);
}

fn appendQuoted(var buffer: ByteBuffer, data: u8*, length: u64) {
    buffer.add(34);
    appendRaw(buffer, data, length);
    buffer.add(34);
}

fn appendVerifyFlags(var buffer: ByteBuffer) {
    buffer.add(32);
    buffer.add(45);
    buffer.add(112);
    buffer.add(97);
    buffer.add(115);
    buffer.add(115);
    buffer.add(101);
    buffer.add(115);
    buffer.add(61);
    buffer.add(118);
    buffer.add(101);
    buffer.add(114);
    buffer.add(105);
    buffer.add(102);
    buffer.add(121);
    buffer.add(32);
    buffer.add(45);
    buffer.add(100);
    buffer.add(105);
    buffer.add(115);
    buffer.add(97);
    buffer.add(98);
    buffer.add(108);
    buffer.add(101);
    buffer.add(45);
    buffer.add(111);
    buffer.add(117);
    buffer.add(116);
    buffer.add(112);
    buffer.add(117);
    buffer.add(116);
    buffer.add(32);
}

fn appendOutputFlag(var buffer: ByteBuffer) {
    buffer.add(32);
    buffer.add(45);
    buffer.add(111);
    buffer.add(32);
}

fn appendEmitLlFlag(var buffer: ByteBuffer) {
    buffer.add(32);
    buffer.add(45);
    buffer.add(45);
    buffer.add(101);
    buffer.add(109);
    buffer.add(105);
    buffer.add(116);
    buffer.add(45);
    buffer.add(108);
    buffer.add(108);
    buffer.add(118);
    buffer.add(109);
    buffer.add(32);
}

fn compilerFailure(kind: u32) {
    var message = byteBufferNew();
    message.add(101); message.add(114);
    message.add(114); message.add(111);
    message.add(114); message.add(58);
    message.add(32); message.add(99);
    message.add(97); message.add(110);
    message.add(110); message.add(111);
    message.add(116); message.add(32);
    when (kind) {
        1 -> {
            message.add(119); message.add(114);
            message.add(105); message.add(116);
            message.add(101); message.add(32);
            message.add(76); message.add(76);
            message.add(86); message.add(77);
            message.add(32); message.add(111);
            message.add(117); message.add(116);
            message.add(112); message.add(117);
            message.add(116);
        }
        2 -> {
            message.add(108); message.add(97);
            message.add(117); message.add(110);
            message.add(99); message.add(104);
            message.add(32); message.add(111);
            message.add(112); message.add(116);
        }
        else -> {
            message.add(108); message.add(97);
            message.add(117); message.add(110);
            message.add(99); message.add(104);
            message.add(32); message.add(99);
            message.add(108); message.add(97);
            message.add(110); message.add(103);
        }
    }
    message.add(10);
    k_boot_stderr(message.data, message.length);
    message.free();
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
            lexed.errorStart, lexed.errorStart + 1
        );
        tokenListFree(lexed.tokens);
        return 2;
    }
    val parsed = parse(lexed.tokens);
    if (!parsed.ok) {
        printDiagnostic(
            source, sourceMap, 1000 + parsed.expectedKind,
            parsed.errorStart, parsed.errorStart + 1
		);
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 2;
    }
    var checked = analyze(source, parsed.nodes);
    if (!checked.ok) {
        printDiagnostic(
            source, sourceMap, checked.category,
            checked.start, checked.end
        );
        checked.genericArguments.free();
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        return 2;
    }
    var resolvedArguments = checked.genericArguments;
    val output = emitModule(source, parsed.nodes, resolvedArguments);
    checked.genericArguments = resolvedArguments;
    var temporaryPath = byteBufferNew();
    appendRaw(temporaryPath, outputPath, outputPathLength);
    temporaryPath.add(46);
    temporaryPath.add(116);
    temporaryPath.add(109);
    temporaryPath.add(112);
    temporaryPath.add(46);
    temporaryPath.add(108);
    temporaryPath.add(108);
    val written = k_boot_write_file(
        temporaryPath.data, temporaryPath.length, output.data, output.length);
    if (!written) {
        compilerFailure(1);
        temporaryPath.free();
        output.free();
        checked.genericArguments.free();
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
    verifyCommand.free();
    if (verified != 0) {
        temporaryPath.free();
        output.free();
        checked.genericArguments.free();
        astListFree(parsed.nodes);
        tokenListFree(lexed.tokens);
        if (verified < 0) {
            compilerFailure(2);
            return 1;
        }
        return 2;
    }
    val published = k_boot_write_file(
        outputPath, outputPathLength, output.data, output.length);
    temporaryPath.free();
    output.free();
    checked.genericArguments.free();
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
    command.add(32);
    appendQuoted(command, llPath, llPathLength);
    command.add(32);
    appendQuoted(command, stdRuntime, stdRuntimeLength);
    command.add(32);
    appendQuoted(command, bootstrapRuntime, bootstrapRuntimeLength);
    appendOutputFlag(command);
    appendQuoted(command, executablePath, executablePathLength);
    val result = k_boot_run(command.data, command.length);
    command.free();
    if (result == 0) return 0;
    if (result < 0) { 
        compilerFailure(3); 
        return 1; 
    }
    return 2;
}

fn findLine(source: Source, sourceStart: u64, offset: u64): u64 {
    var line: u64 = 1;
    for (i in sourceStart..<offset) if (source.data[i] == 10) line++;
    return line;
}

fn findColumn(source: Source, sourceStart: u64, offset: u64): u64 {
    var col: u64 = 1;
    var index = offset;
    while (index > sourceStart) {
        index--;
        if (source.data[index] == 10) return col;
        col++;
    }
    return col;
}

fn stderrWrite(data: u8*, length: u64) => k_boot_stderr(data, length);

fn stderrNumber(value: u64): ByteBuffer {
    var buf = byteBufferNew();
    if (value == 0) {
        buf.add(48);
        return buf;
    }
    val start = buf.length;
    var v = value;
    while (v > 0) {
        buf.add(48 + (v % 10) as u8);
        v /= 10;
    }
    var i = start;
    var j = buf.length - 1;
    while (i < j) {
        val tmp = buf.data[i];
        buf.data[i] = buf.data[j];
        buf.data[j] = tmp;
        i++;
        j--;
    }
    return buf;
}

fn appendErrorMessage(var buffer: ByteBuffer, category: u32) {
    if (category >= 1000) {
        buffer.add(101); buffer.add(120);
        buffer.add(112); buffer.add(101);
        buffer.add(99); buffer.add(116);
        buffer.add(101); buffer.add(100);
        buffer.add(32); buffer.add(39);
        val kind = category - 1000;
        when (kind) {
            1 -> {
                buffer.add(105); buffer.add(110);
                buffer.add(100); buffer.add(101);
                buffer.add(110); buffer.add(116);
                buffer.add(105); buffer.add(102);
                buffer.add(105); buffer.add(101);
                buffer.add(114);
            }
            50 -> buffer.add(40);
            51 -> buffer.add(41);
            52 -> buffer.add(123);
            53 -> buffer.add(125);
            54 -> buffer.add(91);
            55 -> buffer.add(93);
            56 -> buffer.add(44);
            57 -> buffer.add(58);
            58 -> buffer.add(59);
            59 -> buffer.add(46);
            67 -> buffer.add(61);
            else -> {
                buffer.add(116); buffer.add(111);
                buffer.add(107); buffer.add(101);
                buffer.add(110);
            }
        }
        buffer.add(39);
    } else {
        when (category) {
            100 -> {
                buffer.add(117); buffer.add(110);
                buffer.add(116); buffer.add(101);
                buffer.add(114); buffer.add(109);
                buffer.add(105); buffer.add(110);
                buffer.add(97); buffer.add(116);
                buffer.add(101); buffer.add(100);
                buffer.add(32); buffer.add(115);
                buffer.add(116); buffer.add(114);
                buffer.add(105); buffer.add(110);
                buffer.add(103);
            }
            101 -> {
                buffer.add(105); buffer.add(110);
                buffer.add(118); buffer.add(97);
                buffer.add(108); buffer.add(105);
                buffer.add(100); buffer.add(32);
                buffer.add(99); buffer.add(104);
                buffer.add(97); buffer.add(114);
                buffer.add(97); buffer.add(99);
                buffer.add(116); buffer.add(101);
                buffer.add(114);
            }
            1 -> {
                buffer.add(100); buffer.add(117);
                buffer.add(112); buffer.add(108);
                buffer.add(105); buffer.add(99);
                buffer.add(97); buffer.add(116);
                buffer.add(101); buffer.add(32);
                buffer.add(100); buffer.add(101);
                buffer.add(99); buffer.add(108);
                buffer.add(97); buffer.add(114);
                buffer.add(97); buffer.add(116);
                buffer.add(105); buffer.add(111);
                buffer.add(110);
            }
            2 -> {
                buffer.add(117); buffer.add(110);
                buffer.add(107); buffer.add(110);
                buffer.add(111); buffer.add(119);
                buffer.add(110); buffer.add(32);
                buffer.add(105); buffer.add(100);
                buffer.add(101); buffer.add(110);
                buffer.add(116); buffer.add(105);
                buffer.add(102); buffer.add(105);
                buffer.add(101); buffer.add(114);
            }
            3 -> {
                buffer.add(97); buffer.add(114);
                buffer.add(103); buffer.add(117);
                buffer.add(109); buffer.add(101);
                buffer.add(110); buffer.add(116);
                buffer.add(32); buffer.add(99);
                buffer.add(111); buffer.add(117);
                buffer.add(110); buffer.add(116);
                buffer.add(32); buffer.add(109);
                buffer.add(105); buffer.add(115);
                buffer.add(109); buffer.add(97);
                buffer.add(116); buffer.add(99);
                buffer.add(104);
            }
            4 -> {
                buffer.add(116); buffer.add(121);
                buffer.add(112); buffer.add(101);
                buffer.add(32); buffer.add(109);
                buffer.add(105); buffer.add(115);
                buffer.add(109); buffer.add(97);
                buffer.add(116); buffer.add(99);
                buffer.add(104);
            }
            5 -> {
                buffer.add(114); buffer.add(101);
                buffer.add(116); buffer.add(117);
                buffer.add(114); buffer.add(110);
                buffer.add(32); buffer.add(116);
                buffer.add(121); buffer.add(112);
                buffer.add(101); buffer.add(32);
                buffer.add(109); buffer.add(105);
                buffer.add(115); buffer.add(109);
                buffer.add(97); buffer.add(116);
                buffer.add(99);
            }
            6 -> {
                buffer.add(99); buffer.add(111);
                buffer.add(110); buffer.add(100);
                buffer.add(105); buffer.add(116);
                buffer.add(105); buffer.add(111);
                buffer.add(110); buffer.add(32);
                buffer.add(109); buffer.add(117);
                buffer.add(115); buffer.add(116);
                buffer.add(32); buffer.add(98);
                buffer.add(101); buffer.add(32);
                buffer.add(98); buffer.add(111);
                buffer.add(111); buffer.add(108);
            }
            7 -> {
                buffer.add(99); buffer.add(97);
                buffer.add(110); buffer.add(110);
                buffer.add(111); buffer.add(116);
                buffer.add(32); buffer.add(97);
                buffer.add(115); buffer.add(115);
                buffer.add(105); buffer.add(103);
                buffer.add(110); buffer.add(32);
                buffer.add(116); buffer.add(111);
                buffer.add(32); buffer.add(105);
                buffer.add(109); buffer.add(109);
                buffer.add(117); buffer.add(116);
                buffer.add(97); buffer.add(98);
                buffer.add(108); buffer.add(101);
            }
            8 -> {
                buffer.add(105); buffer.add(110);
                buffer.add(118); buffer.add(97);
                buffer.add(108); buffer.add(105);
                buffer.add(100); buffer.add(32);
                buffer.add(109); buffer.add(101);
                buffer.add(109); buffer.add(98);
                buffer.add(101); buffer.add(114);
                buffer.add(32); buffer.add(97);
                buffer.add(99); buffer.add(99);
                buffer.add(101); buffer.add(115);
                buffer.add(115);
            }
            else -> {
                buffer.add(101); buffer.add(114);
                buffer.add(114); buffer.add(111);
                buffer.add(114);
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
    var found = false;
    for (i in 0..<sourceMap.length) {
        val segment = sourceMap.data[i];
        if (!found) {
            val total = segment.sourceStart + segment.sourceLength;
            if (start in segment.sourceStart..total) {
				appendRaw(buf, segment.path, segment.pathLength);
				buf.add(58);
				sourceStart = segment.sourceStart;
				found = true;
            }
        }
    }
    
    val lineNum = stderrNumber(findLine(source, sourceStart, start));
    appendRaw(buf, lineNum.data, lineNum.length);
    lineNum.free();
    buf.add(58);
    val colNum = stderrNumber(findColumn(source, sourceStart, start));
    appendRaw(buf, colNum.data, colNum.length);
    colNum.free();
    buf.add(58);
    buf.add(32);
    buf.add(101);
    buf.add(114);
    buf.add(114);
    buf.add(111);
    buf.add(114);
    buf.add(58);
    buf.add(32);
    appendErrorMessage(buf, category);
    buf.add(10);
    k_boot_stderr(buf.data, buf.length);
    buf.free();
}
