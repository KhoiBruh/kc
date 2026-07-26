# Klang Agent Guide

## Project goal

Klang is an experimental low-level, statically compiled language named **K**.
The compiler CLI is `kc`, source files use `.k`, and LLVM is the backend.
Work incrementally in small, runnable vertical slices. Do not add concurrency yet.

Read `docs.md` before changing language behavior. Approved implementation plans
and design history are under `docs/superpowers/`.

## Working rules

- Make the smallest change that implements the requested behavior.
- Do not refactor or rename unrelated code.
- Use TDD for language/compiler behavior: add a focused failing test, observe
  the expected failure, implement, then run the relevant target and CTest.
- Keep `src/lang/` independent of LLVM, Windows APIs, and the runtime.
- LLVM-dependent code belongs in `src/codegen/`.
- Standard-library/runtime code belongs in `src/lib/std/`; isolate OS calls in
  `src/lib/std/platform/`.
- Preserve positioned diagnostics and CLI exit codes:
  `0` success, `1` CLI/filesystem/tool invocation failure, `2` source,
  semantic, codegen, or linker diagnostic.
- Git remote: `https://github.com/KhoiBruh/kc`. IDE settings, `out/`,
  `cmake-build-*`, and `scripts/` are gitignored to keep machine environment
  details out of the repository.

## Current architecture

```text
source.k
  -> Lexer
  -> Parser / AST
  -> SemanticAnalyzer
  -> LlvmCodegen
  -> LLVM Module
     -> textual .ll
     -> NativeEmitter / TargetMachine -> COFF .obj
     -> ClangLinker -> Windows .exe
```

- `src/lang/`: source model, tokens, lexer, AST, parser, semantic types/checker.
- `src/codegen/LlvmCodegen.*`: lowers the supported typed AST to verified IR.
- `src/codegen/NativeEmitter.*`: configures the host target and emits objects.
- `src/codegen/ClangLinker.*`: invokes the configured Clang driver.
- `src/cli/main.cpp`: `kc` modes and diagnostic/output handling.
- `src/lib/std/`: minimal runtime currently linked into native executables.
- `tests/`: dependency-free test executables and `.k` acceptance fixtures.

## Established K language decisions

- Semicolons are mandatory after variable declarations, `return`, and
  expression statements.
- Omitted function return type means `unit`; explicit `: unit` is allowed.
- `()` is the unit literal, but a unit function exits with `return;`.
  `return ();` is invalid.
- Default numeric literal types are `i32` and `f64`.
- Arrays use `T[n]`; omitted size `T[]` is inferred from an array literal.
  `val empty: i32[] = [];` is valid; `val empty = [];` is invalid.
- Slices use `[]T`.
- Data-only structs may omit the empty body: `struct Player(name: string)`;
  the equivalent `struct Player(name: string) {}` remains valid.
- Locals use `val` or `var`. Owned and mutable-borrow parameters are assignable;
  `val` and immutable-borrow parameters are not.
- Owned strings, arrays, and resource-owning structs are intended to be
  move-only with explicit `.copy()`; this is not implemented yet.
- Nullable syntax is only `T?`; postfix `!` unwraps. Nested `T??` is invalid.
- `print` is currently a builtin overload only for a string literal and `i32`.
  It does not add spaces, formatting, or a newline.

## LLVM and toolchain

- Required version: LLVM **22.1.8**.
- Local development package:
  `C:/Users/Admin/tools/llvm-22.1.8`
- CMake package: set the `KLANG_LLVM_DIR` user environment variable to the
  `lib/cmake/llvm` directory (locally
  `C:/Users/Admin/tools/llvm-22.1.8/lib/cmake/llvm`); `CMakePresets.json`
  expands it into `LLVM_DIR` so machine paths stay out of versioned files.
- Clang driver:
  `C:/Users/Admin/tools/llvm-22.1.8/bin/clang.exe`
- The Windows LLVM archive contains a stale Visual Studio 2022 Enterprise DIA
  path. `CMakeLists.txt` deliberately redirects `LLVMDebugInfoPDB` to the
  installed Visual Studio Community `diaguids.lib`; preserve this workaround.
- The prebuilt LLVM libraries use static release CRT. Klang deliberately uses
  `/MT` and `_ITERATOR_DEBUG_LEVEL=0` in Debug as well; changing this causes
  MSVC ABI/linker mismatches.
- Missing optional LibXml2 may appear as a CMake status warning and does not
  block the currently used LLVM components.

## Build and verification

Preferred agent commands automatically enter the Visual Studio developer
environment:

```powershell
.\scripts\dev.ps1 configure
.\scripts\dev.ps1 build
.\scripts\dev.ps1 test
.\scripts\dev.ps1 all
.\scripts\dev.ps1 all -Configuration Release
```

Run `.\scripts\dev.ps1` without arguments to open an interactive DevShell at the project root.

Before completion, also configure/build/test `x64-release`. Run targeted tests
while iterating; run all CTest targets only at a milestone boundary.

Useful CLI checks:

```powershell
kc --tokens file.k
kc --ast file.k
kc --check file.k
kc --emit-llvm file.k -o file.ll
kc --emit-obj file.k -o file.obj
kc file.k -o file.exe
```

Validate artifacts with LLVM 22 tools:

```powershell
llvm-as file.ll -o file.bc
opt -passes=verify -disable-output file.ll
llvm-readobj --file-headers file.obj
```

## Implemented backend subset

- Function declarations and bodies with numeric/bool/unit signatures.
- Numeric parameters, `val` locals, numeric literals, identifier loads.
- Numeric unary and arithmetic operators.
- User function calls, mutable locals, assignment, comparisons, `if`/`else`,
  and `while`.
- Raw pointer types, explicit pointer casts, dereference, and unchecked raw
  pointer indexing.
- `extern fn` C ABI declarations, `sizeof(T)`, and true mutable-borrow lowering
  for `var` parameters.
- Fixed structs, fixed arrays, array-to-slice conversion, field/index access,
  and bounds-checked array/slice indexing.
- Constrained generic functions with explicit or inferred type arguments and
  demand-driven monomorphization.
- Minimal tagged nullable values, `null`, lifting `T` to `T?`, and postfix `!`.
- `return`.
- Windows x64 textual IR, COFF object, and executable output.
- Builtin `print("literal")` and `print(i32)`.
- The Windows runtime uses `GetStdHandle` + `WriteFile`, performs its own
  stack-buffer `i32` conversion, and does not use `printf`, `sprintf`,
  iostream, or a formatting library.
- The Windows bootstrap runtime provides allocation, binary file I/O, current
  directory and canonical UTF-8 paths, child process execution, stderr, and
  bounds-check panic through a narrow C ABI.

## Important current limitations

- Numeric casts, logical short-circuiting, `when`, `for`, `break`, and
  `continue` are not lowered yet.
- String variables, escape decoding in codegen, concatenation, other print
  types, enums, and ownership are not lowered.
- Bootstrap generic functions and structs support arbitrary ordered
  type-parameter lists. Type packs, user-defined traits, and overload
  resolution remain unsupported.
- Native output currently requires exactly `fn main(): i32`.
- Runtime platform adapter exists only for Windows. Keep the common runtime
  separate so a POSIX adapter can be added later.
- LLVM itself has no stdout instruction. Printing must ultimately call a
  platform API; do not invent a custom LLVM intrinsic merely to hide this.

## Bootstrap compiler

- `src/kbootstrap/` contains the K implementation of source loading, lexer,
  flat AST, parser, semantic checking, textual LLVM emission, and the driver.
- The K module loader resolves symbol imports to `.k`, wildcard imports to
  `mod.k`, loads dependencies first, and de-duplicates canonical paths.
- Bootstrap source-map segments preserve each canonical path and translate
  lexer, parser, semantic, and import diagnostics to original file positions.
- Bootstrap stages compile `src/kbootstrap/main.k` as a real module graph;
  `manifest.txt` only verifies that every compiler source remains reachable.
- Run `.\scripts\bootstrap.ps1` to build `kc1` through `kc4` and perform a
  fixed-point check under `out/bootstrap/`.
- Scalar functions, control flow, raw pointers, casts, indexing, structs,
  generic functions and structs, and minimal nullable values emit typed LLVM
  text directly from K.
- `kc0` seeds `kc1` only. `kc1` builds `kc2`, `kc2` builds `kc3`, and `kc3`
  builds `kc4` without invoking the C++ compiler.

## Recommended next milestone

Add focused bootstrap acceptance fixtures for import cycles, the depth-64
boundary, and lexer/parser errors inside dependencies. Keep the existing
de-duplication semantics for cycles and require positioned parity on `kc1`–`kc4`.
