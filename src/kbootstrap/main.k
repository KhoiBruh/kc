module kbootstrap.main;

import kbootstrap.compiler.compileToLl;
import kbootstrap.containers.ByteBuffer;
import kbootstrap.loader.loadModules;

struct Argument(data: u8*, length: u64, ok: bool)

fn mainError(kind: u32) {
    var message = byteBufferNew();
    byteBufferAppend(message, 101); byteBufferAppend(message, 114);
    byteBufferAppend(message, 114); byteBufferAppend(message, 111);
    byteBufferAppend(message, 114); byteBufferAppend(message, 58);
    byteBufferAppend(message, 32);
    if (kind == 1) {
        byteBufferAppend(message, 101); byteBufferAppend(message, 120);
        byteBufferAppend(message, 112); byteBufferAppend(message, 101);
        byteBufferAppend(message, 99); byteBufferAppend(message, 116);
        byteBufferAppend(message, 101); byteBufferAppend(message, 100);
        byteBufferAppend(message, 32); byteBufferAppend(message, 55);
        byteBufferAppend(message, 32); byteBufferAppend(message, 97);
        byteBufferAppend(message, 114); byteBufferAppend(message, 103);
        byteBufferAppend(message, 117); byteBufferAppend(message, 109);
        byteBufferAppend(message, 101); byteBufferAppend(message, 110);
        byteBufferAppend(message, 116); byteBufferAppend(message, 115);
    } else {
        byteBufferAppend(message, 99); byteBufferAppend(message, 97);
        byteBufferAppend(message, 110); byteBufferAppend(message, 110);
        byteBufferAppend(message, 111); byteBufferAppend(message, 116);
        byteBufferAppend(message, 32); byteBufferAppend(message, 108);
        byteBufferAppend(message, 111); byteBufferAppend(message, 97);
        byteBufferAppend(message, 100); byteBufferAppend(message, 32);
        byteBufferAppend(message, 105); byteBufferAppend(message, 110);
        byteBufferAppend(message, 112); byteBufferAppend(message, 117);
        byteBufferAppend(message, 116);
    }
    byteBufferAppend(message, 10);
    k_boot_stderr(message.data, message.length);
    byteBufferFree(message);
}

fn freeArgument(argument: Argument) {
    if (argument.ok) { k_boot_free(argument.data as unit*); }
}

fn freeArguments(
    input: Argument, llOutput: Argument, opt: Argument, clang: Argument,
    stdRuntime: Argument, bootstrapRuntime: Argument, executable: Argument) {
    freeArgument(executable); freeArgument(bootstrapRuntime);
    freeArgument(stdRuntime); freeArgument(clang); freeArgument(opt);
    freeArgument(llOutput); freeArgument(input);
}

fn readArgument(index: i32): Argument {
    val placeholder = k_boot_alloc(1);
    var data = placeholder as u8*;
    var length: u64 = 0;
    if (k_boot_arg(index, &data, &length)) {
        k_boot_free(placeholder);
        return Argument(data, length, true);
    }
    k_boot_free(placeholder);
    return Argument(data, 0, false);
}

fn main(): i32 {
    if (k_boot_arg_count() != 8) { mainError(1); return 1; }
    val input = readArgument(1);
    val llOutput = readArgument(2);
    val opt = readArgument(3);
    val clang = readArgument(4);
    val stdRuntime = readArgument(5);
    val bootstrapRuntime = readArgument(6);
    val executable = readArgument(7);
    var argumentsOk = true;
    if (input.ok == false) { argumentsOk = false; }
    if (llOutput.ok == false) { argumentsOk = false; }
    if (opt.ok == false) { argumentsOk = false; }
    if (clang.ok == false) { argumentsOk = false; }
    if (stdRuntime.ok == false) { argumentsOk = false; }
    if (bootstrapRuntime.ok == false) { argumentsOk = false; }
    if (executable.ok == false) { argumentsOk = false; }
    if (argumentsOk == false) {
        mainError(1);
        freeArguments(
            input, llOutput, opt, clang, stdRuntime, bootstrapRuntime, executable);
        return 1;
    }

    val loaded = loadModules(input.data, input.length);
    if (loaded.ok == false) {
        sourceMapFree(loaded.sourceMap);
        if (loaded.failureKind == 1) { mainError(2); }
        freeArguments(
            input, llOutput, opt, clang, stdRuntime, bootstrapRuntime, executable);
        return loaded.failureKind;
    }

    var result = compileToLl(
        loaded.source.data, loaded.source.length, loaded.sourceMap,
        llOutput.data, llOutput.length,
        opt.data, opt.length);
    if (result == 0) {
        result = linkLl(
            llOutput.data, llOutput.length, clang.data, clang.length,
            stdRuntime.data, stdRuntime.length,
            bootstrapRuntime.data, bootstrapRuntime.length,
            executable.data, executable.length);
    }
    k_boot_free(loaded.source.data as unit*);
    sourceMapFree(loaded.sourceMap);
    freeArguments(
        input, llOutput, opt, clang, stdRuntime, bootstrapRuntime, executable);
    return result;
}
