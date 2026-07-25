extern fn k_boot_write_file(
    path: u8*, pathLength: u64, data: u8*, length: u64): bool;
extern fn k_boot_run(command: u8*, commandLength: u64): i32;

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
    return 1;
}

fn linkLl(
    llPath: u8*, llPathLength: u64,
    clangPath: u8*, clangPathLength: u64,
    stdRuntime: u8*, stdRuntimeLength: u64,
    bootstrapRuntime: u8*, bootstrapRuntimeLength: u64,
    executablePath: u8*, executablePathLength: u64): i32 {
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
