module kbootstrap.main;

import kbootstrap.compiler.compileToLl;
import kbootstrap.containers.ByteBuffer;
import kbootstrap.loader.loadModules;

struct Argument(data: u8*, length: u64, ok: bool)

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
    if (k_boot_arg_count() < 8) { return 1; }
    val input = readArgument(1);
    val llOutput = readArgument(2);
    val opt = readArgument(3);
    val clang = readArgument(4);
    val stdRuntime = readArgument(5);
    val bootstrapRuntime = readArgument(6);
    val executable = readArgument(7);
    if (input.ok == false) { return 1; }
    if (llOutput.ok == false) { return 1; }
    if (opt.ok == false) { return 1; }
    if (clang.ok == false) { return 1; }
    if (stdRuntime.ok == false) { return 1; }
    if (bootstrapRuntime.ok == false) { return 1; }
    if (executable.ok == false) { return 1; }

    val loaded = loadModules(input.data, input.length);
    if (loaded.ok == false) {
        sourceMapFree(loaded.sourceMap);
        return 2;
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
    k_boot_free(executable.data as unit*);
    k_boot_free(bootstrapRuntime.data as unit*);
    k_boot_free(stdRuntime.data as unit*);
    k_boot_free(clang.data as unit*);
    k_boot_free(opt.data as unit*);
    k_boot_free(llOutput.data as unit*);
    k_boot_free(input.data as unit*);
    return result;
}
