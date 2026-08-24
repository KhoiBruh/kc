module bootstrap.main;

import bootstrap.compiler.compileToLl;
import bootstrap.containers.StringBuilder;
import bootstrap.loader.loadModules;

struct Argument(data: u8*, length: u64, ok: bool)

fn mainError(kind: u32) {
    var message = StringBuilder.new();
    defer message.free();
    message.append("error: ");

    if (kind == 1) {
        message.append("expected 7 arguments");
    } else {
        message.append("cannot load input");
    }

    message.append("\n");
    k_boot_stderr(message.data, message.length);
}

fn mainPathError(kind: u32) {
    var message = StringBuilder.new();
    defer message.free();
    message.append("error: ");
    when (kind) {
        1 -> message.append("input must use .k extension");
        else -> message.append("paths must not be empty");
    }
    message.append("\n");
    k_boot_stderr(message.data, message.length);
}

fn hasKExtension(argument: Argument): bool {
    if (argument.length < 2) return false;
    if (argument.data[argument.length - 2] != 46) return false;
    return argument.data[argument.length - 1] == 107;
}

fn freeArgument(argument: Argument) {
    if (argument.ok) k_boot_free(argument.data as unit*);
}

fn freeArguments(
    input: Argument, llOutput: Argument, opt: Argument, clang: Argument,
    stdRuntime: Argument, bootstrapRuntime: Argument, executable: Argument
) {
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
    if (k_boot_arg_count() != 8) {
        mainError(1); 
        return 1;
    }
    val input = readArgument(1);
    val llOutput = readArgument(2);
    val opt = readArgument(3);
    val clang = readArgument(4);
    val stdRuntime = readArgument(5);
    val bootstrapRuntime = readArgument(6);
    val executable = readArgument(7);

    var argumentsOk = true;
    if (!input.ok) argumentsOk = false;
    if (!llOutput.ok) argumentsOk = false;
    if (!opt.ok) argumentsOk = false;
    if (!clang.ok) argumentsOk = false;
    if (!stdRuntime.ok) argumentsOk = false;
    if (!bootstrapRuntime.ok) argumentsOk = false;
    if (!executable.ok) argumentsOk = false;

    if (!argumentsOk) {
        mainError(1);
        freeArguments(input, llOutput, opt, clang, stdRuntime, bootstrapRuntime, executable);
        return 1;
    }
    if (!hasKExtension(input)) {
        mainPathError(1);
        freeArguments(input, llOutput, opt, clang, stdRuntime, bootstrapRuntime, executable);
        return 1;
    }

    var pathsOk = true;
    if (llOutput.length == 0) pathsOk = false;
    if (opt.length == 0) pathsOk = false;
    if (clang.length == 0) pathsOk = false;
    if (stdRuntime.length == 0) pathsOk = false;
    if (bootstrapRuntime.length == 0) pathsOk = false;
    if (executable.length == 0) pathsOk = false;

    if (!pathsOk) {
        mainPathError(2);
        freeArguments(
            input, llOutput, opt, clang,
            stdRuntime, bootstrapRuntime, executable
		);

        return 1;
    }

    val loaded = loadModules(input.data, input.length);
    if (!loaded.ok) {
        val failureKind = loaded.failureKind;
        k_boot_free(loaded.sourceMap.data as unit*);
        if (failureKind == 1) mainError(2);
        freeArguments(
            input, llOutput, opt, clang,
            stdRuntime, bootstrapRuntime, executable
        );

        return failureKind;
    }

    var result = compileToLl(
        loaded.source.data, loaded.source.length, loaded.sourceMap,
        llOutput.data, llOutput.length,
        opt.data, opt.length
    );

    if (result == 0) {
        result = linkLl(
            llOutput.data, llOutput.length, clang.data, clang.length,
            stdRuntime.data, stdRuntime.length,
            bootstrapRuntime.data, bootstrapRuntime.length,
            executable.data, executable.length
        );
    }

    k_boot_free(loaded.source.data as unit*);
    sourceMapFree(loaded.sourceMap);
    freeArguments(
		input, llOutput, opt, clang,
		stdRuntime, bootstrapRuntime, executable
	);

    return result;
}
