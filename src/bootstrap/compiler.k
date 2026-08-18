module bootstrap.compiler;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;
import bootstrap.containers.StringBuilder;
import bootstrap.lexer.lex;
import bootstrap.ast.AstNode;
import bootstrap.ast.AstKind;
import bootstrap.parser.mod.parse;
import bootstrap.types.TypeValue;
import bootstrap.types.TypeKind;
import bootstrap.types.typeKindFromValue;
import bootstrap.diagnostic.SemanticResult;
import bootstrap.semantic.mod.analyze;
import bootstrap.llvm_text.mod.emitModule;
import bootstrap.loader.LoadResult;
import bootstrap.loader.SourceMapSegment;

extern fn k_boot_write_file(path: u8*, pathLength: u64, data: u8*, length: u64): bool;
extern fn k_boot_run(command: u8*, commandLength: u64): i32;

fn appendQuoted(var buffer: StringBuilder, val bytes: []u8) {
    buffer.append("\"");
    buffer.appendBytes(bytes);
    buffer.append("\"");
}

fn appendVerifyFlags(var buffer: StringBuilder) {
    buffer.append(" -passes=verify -disable-output ");
}

fn appendOutputFlag(var buffer: StringBuilder) {
    buffer.append(" -o ");
}

fn appendEmitLlFlag(var buffer: StringBuilder) {
    buffer.append(" --emit-llvm ");
}

fn compilerFailure(kind: u32) {
    var message = StringBuilder.new();
    defer message.free();

    message.append("error: cannot ");
    when (kind) {
        1 -> message.append("write LLVM output");
        2 -> message.append("launch opt");
        else -> message.append("launch clang");
    }
    message.append("\n");
    k_boot_stderr(message.data, message.length);
}

fn compileToLl(
    sourceData: u8*,
    sourceLength: u64,
    val sourceMap: List<SourceMapSegment>,
    outputPath: u8*,
    outputPathLength: u64,
    optPath: u8*,
    optPathLength: u64
): i32 {
    val source = Source(sourceData, sourceLength);
    val lexed = lex(source);
    defer lexed.tokens.free();
    if (!lexed.ok) {
        printDiagnostic(
            source, sourceMap, 99 + lexed.errorKind,
            lexed.errorStart, lexed.errorStart + 1
        );
        return 2;
    }

    val parsed = parse(lexed.tokens);
    defer parsed.nodes.free();
    if (!parsed.ok) {
        printDiagnostic(
            source, sourceMap, 1000 + parsed.expectedKind,
            parsed.errorStart, parsed.errorStart + 1
		);
        return 2;
    }

    var checked = analyze(source, parsed.nodes);
    if (!checked.ok) {
        printDiagnostic(
            source, sourceMap, checked.category,
            checked.start, checked.end
        );
        return 2;
    }
    var resolvedArguments = checked.genericArguments;
    defer resolvedArguments.free();
    val output = emitModule(source, parsed.nodes, resolvedArguments);
    defer output.free();

    var temporaryPath = StringBuilder.new();
    defer temporaryPath.free();
    temporaryPath.appendBytes(slice(outputPath, outputPathLength));
    temporaryPath.append(".tmp.ll");
    val written = k_boot_write_file(
        temporaryPath.data, temporaryPath.length, output.data, output.length);
    if (!written) {
        compilerFailure(1);
        return 1;
    }
    var verifyCommand = StringBuilder.new();
    defer verifyCommand.free();

    appendQuoted(verifyCommand, slice(optPath, optPathLength));
    appendVerifyFlags(verifyCommand);
    appendQuoted(
        verifyCommand, slice(temporaryPath.data, temporaryPath.length));
    val verified = k_boot_run(verifyCommand.data, verifyCommand.length);
    if (verified != 0) {
        if (verified < 0) {
            compilerFailure(2);
            return 1;
        }
        return 2;
    }
    val published = k_boot_write_file(
        outputPath, outputPathLength, output.data, output.length);
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
    var command = StringBuilder.new();
    defer command.free();
    appendQuoted(command, slice(clangPath, clangPathLength));
    command.append(" ");
    appendQuoted(command, slice(llPath, llPathLength));
    command.append(" ");
    appendQuoted(command, slice(stdRuntime, stdRuntimeLength));
    command.append(" ");
    appendQuoted(command, slice(bootstrapRuntime, bootstrapRuntimeLength));
    appendOutputFlag(command);
    appendQuoted(command, slice(executablePath, executablePathLength));
    val result = k_boot_run(command.data, command.length);
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
    for (index in offset>..sourceStart) {
        if (source.data[index] == 10) return col;
        col++;
    }
    return col;
}

fn stderrNumber(value: u64): StringBuilder {
    var buf = StringBuilder.new();
    var v = value;
    if (v == 0) {
        buf.add(48);
    } else {
        while (v > 0) {
            buf.add(48 + (v % 10) as u8);
            v /= 10;
        }
    }
    
    val half = buf.length / 2;
    for (i in 0..<half) {
        val j = buf.length - i - 1;
        val tmp = buf.data[i];
        buf.data[i] = buf.data[j];
        buf.data[j] = tmp;
    }

    return buf;
}

fn appendErrorMessage(var buffer: StringBuilder, category: u32) {
    if (category >= 1000) {
        buffer.append("expected '");
        val kind = category - 1000;
        when (kind) {
            1 -> buffer.append("identifier");
            50 -> buffer.append("(");
            51 -> buffer.append(")");
            52 -> buffer.append("{");
            53 -> buffer.append("}");
            54 -> buffer.append("[");
            55 -> buffer.append("]");
            56 -> buffer.append(",");
            57 -> buffer.append(":");
            58 -> buffer.append(";");
            59 -> buffer.append(".");
            67 -> buffer.append("=");
            else -> buffer.append("token");
        }
        buffer.append("'");
    } else {
        when (category) {
            100 -> buffer.append("unterminated string");
            101 -> buffer.append("invalid character");
            1 -> buffer.append("duplicate declaration");
            2 -> buffer.append("unknown identifier");
            3 -> buffer.append("argument count mismatch");
            4 -> buffer.append("type mismatch");
            5 -> buffer.append("return type mismatch");
            6 -> buffer.append("condition must be bool");
            7 -> buffer.append("cannot assign to immutable");
            8 -> buffer.append("invalid member access");
            else -> buffer.append("error");
        }
    }
}

fn printDiagnostic(
    source: Source, val sourceMap: List<SourceMapSegment>,
    category: u32, start: u64, end: u64
) {
    var buf = StringBuilder.new();
    defer buf.free();
    var sourceStart: u64 = 0;
    for (i in 0..<sourceMap.length) {
        val segment = sourceMap.data[i];
        val total = segment.sourceStart + segment.sourceLength;
        if (start in segment.sourceStart..total) {
			buf.appendBytes(slice(segment.path, segment.pathLength));
			buf.append(":");
			sourceStart = segment.sourceStart;
            break;
        }
    }
    
    val lineNum = stderrNumber(findLine(source, sourceStart, start));
    defer lineNum.free();
    buf.appendBytes(slice(lineNum.data, lineNum.length));
    buf.append(":");
    val colNum = stderrNumber(findColumn(source, sourceStart, start));
    defer colNum.free();
    buf.appendBytes(slice(colNum.data, colNum.length));
    buf.append(": ");
    buf.append("error: ");
    appendErrorMessage(buf, category);
    buf.append("\n");
    k_boot_stderr(buf.data, buf.length);
}
