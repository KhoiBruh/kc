# Klang Agent Guide

## Project goal

Klang is an experimental low-level, statically compiled language named **K**.
The compiler is **self-hosted**: `src/bootstrap` contains the entire compiler
written in K, and LLVM is the backend. Work incrementally in small, runnable
vertical slices. Do not add concurrency yet.

Read `docs.md` before changing language behavior. Approved implementation plans
and design history are under `docs/superpowers/`.

## Working rules

- Make the smallest change that implements the requested behavior.
- Do not refactor or rename unrelated code.
- Use TDD for language/compiler behavior: add a focused failing test, observe
  the expected failure, implement, then run the relevant target and CTest.
- All compiler code lives in `src/bootstrap/`; runtime/standard-library code
  belongs in `src/lib/std/` (isolate OS calls in `src/lib/std/platform/`) and
  `src/lib/bootstrap/`.
- The C++ reference compiler was removed from this branch (Phase 3 of C8).
  Its source is preserved on the `kc0-reference` branch; a prebuilt seed
  binary ships with the GitHub release `kc0-seed-v0.1`. Place a copy at
  `tools/kc0.exe` or set `$env:KLANG_KC0` for driver tests and
  `scripts/bootstrap.ps1`.
- Preserve positioned diagnostics and CLI exit codes:
  `0` success, `1` CLI/filesystem/tool invocation failure, `2` source,
  semantic, codegen, or linker diagnostic.
- Git remote: `https://github.com/KhoiBruh/kc`. IDE settings, `out/`,
  `cmake-build-*`, `scripts/`, and `tools/` are gitignored to keep machine
  environment details out of the repository.

## Current architecture

```text
source.k
  -> Lexer (K)
  -> Parser / AST (K)
  -> SemanticAnalyzer (K)
  -> LlvmTextEmitter (K)
     -> textual .ll
     -> opt -passes=verify
     -> clang -> Windows .exe

Bootstrap chain: kc0 (seed binary) -> kc1 -> kc2 -> kc3 -> kc4
Fixed point: kc3.ll == kc4.ll
```

Bootstrap chain: kc0 (seed binary) -> kc1 -> kc2 -> kc3 -> kc4
Fixed point: kc3.ll == kc4.ll
```

- `src/bootstrap/`: the entire compiler — source loading, lexer, parser,
  semantic checking, and textual LLVM emission, written in K.
- `src/lib/std/`: minimal runtime currently linked into native executables.
- `tests/`: `unit/` runtime unit tests, `drivers/` PowerShell scenario scripts
  (including the differential harness), `cases/` self-hosted acceptance `.k`
  programs, `harness/` K driver sources, and `fixtures/` shared fixtures
  (invalid inputs, module graphs).

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
- Owned strings, arrays, nullable owners, generic type parameters, and structs
  with owned `free(self)` are checked as move-only. Owned-string locals and
  resource structs with exact `fn free(self)` receive deterministic automatic
  drop; resource owned parameters are also dropped. Automatic `.copy()` is not
  implemented yet.
- `const` initializers are compile-time expressions: literals, operators,
  casts, and references to previously declared `const` only. Function calls
  (including inside nested expressions or generics) and forward references are
  rejected semantically. Scalar constants are evaluated and folded at
  compile time in declaration order; circular references and division/remainder
  by zero are diagnosed. Non-foldable constants fall back to emitting their
  initializer expression.
- Native code emission is demand-driven: only declarations reachable from a
  non-extern `main` are emitted (functions, structs, enums, constants, and
  generic specializations). Semantic analysis stays whole-program; without a
  `main` entry all declarations are emitted. `mod.k` is not a compilation
  registry.
- Wildcard imports (`import foo.*`) are a permanent name-resolution feature:
  they bring module names into scope but never make the imported module
  reachable. Only declarations actually referenced from the entry point are
  compiled; unused wildcard imports are legal. Import resolution and
  compilation reachability are separate concerns.
- Nullable syntax is only `T?`; postfix `!` unwraps. Nested `T??` is invalid.
- Enum v0.1 is payload-free and non-generic. Variants are comma-separated with
  no trailing comma, accessed as `Enum.Variant`, and use declaration-order
  `u32` tags internally; manual tags and public underlying types are excluded.
- `print` is currently a builtin overload only for a string literal and `i32`.
  It does not add spaces, formatting, or a newline.

## LLVM and toolchain

- Required version: LLVM **22.1.8**.
- Local development package:
  `C:/LLVM`
- CMake package: set the `LLVM` user environment variable to the
  `lib/cmake/llvm` directory (locally
  `C:/LLVM/lib/cmake/llvm`); `CMakePresets.json`
  expands it into `LLVM_DIR` so machine paths stay out of versioned files.
- Clang driver:
  `C:/LLVM/bin/clang.exe`
- The Windows LLVM archive contains a stale Visual Studio 2022 Enterprise DIA
  path. `CMakeLists.txt` deliberately redirects `LLVMDebugInfoPDB` to the
  installed Visual Studio Community `diaguids.lib`; preserve this workaround.
- The prebuilt LLVM libraries use static release CRT. Klang deliberately uses
  `/MT` and `_ITERATOR_DEBUG_LEVEL=0` in Debug as well; changing this causes
  MSVC ABI/linker mismatches.
- Missing optional LibXml2 may appear as a CMake status warning and does not
  block the currently used LLVM components.

## Build and verification

The C++ build now produces only the runtime libraries and the runtime unit
test. Driver tests additionally need a `kc0` seed binary — place one at
`tools/kc0.exe` or configure with `-DKLANG_KC0_EXE=<path>` (see the release
`kc0-seed-v0.1` or the `kc0-reference` branch for sources).

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
while iterating; run all CTest targets only at a milestone boundary. The full
self-hosted loop (chain + fixed point + fixtures) is
`.\scripts\bootstrap.ps1`.

Useful CLI checks (through any stage binary, e.g. `out/bootstrap/kc4.exe`):

```powershell
kc4 --tokens file.k
kc4 --ast file.k
kc4 --check file.k
kc4 --emit-llvm file.k -o file.ll
kc4 file.k -o file.exe
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
- Constrained generic functions and structs with explicit or inferred type
  arguments and demand-driven monomorphization; generic-struct instance methods
  and associated functions capture their enclosing type parameters.
- Minimal tagged nullable values, `null`, lifting `T` to `T?`, and postfix `!`.
- Integer casts have semantic source/target metadata, positioned constant range
  diagnostics, checked runtime panic lowering, and bootstrap IR/behavior fixtures.
- `f32`/`f64` casts lower through `fpext`, `fptrunc`, `sitofp`, `uitofp`,
  `fptosi`, and `fptoui`; float-to-integer checks reject out-of-range values,
  `NaN`, and infinity before conversion.
- Bootstrap float-cast acceptance covers signed/unsigned extrema, fractional
  lower bounds, `NaN`, infinity, executable behavior, and exact `kc1`-`kc4` IR.
- Logical `&&` and `||` use left-to-right short-circuit CFG lowering with a
  `phi i1` merge in both LLVM emitters; skipped RHS expressions are not evaluated.
- `break` and `continue` target the nearest enclosing loop; both LLVM
  emitters preserve nested-loop targets and semantic analysis rejects them
  outside loops.
- `if`/`else`, `while`, and `for` accept either a block or one statement body;
  newlines are whitespace and dangling `else` binds to the nearest `if`.
- Integer-range `for` is self-hosted: `..` is inclusive and `..<` is exclusive;
  `break`/`continue` target the nearest `while` or `for`.
- Collection `for` is self-hosted for fixed arrays and slices. It accepts
  `(value in collection)` or `(value, index in collection)`; value comes first,
  index is immutable `u64`, and both bindings are immutable.
- Payload-free enums are self-hosted. `Enum.Variant` resolves to a distinct
  enum type and lowers to its declaration-order `u32` tag.
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

- Pattern destructuring is not lowered yet. Expression-valued `when` requires
  a final `else` unless its enum subject is exhaustively covered.
- String mutation and concatenation, other print types, payload enums,
  array/nullable drop glue, and borrow lifetimes are not lowered.
- Bootstrap generic functions and structs support arbitrary ordered
  type-parameter lists; instance methods and associated functions on generic
  structs capture those parameters. Type packs, independently generic methods,
  user-defined traits, and overload resolution remain unsupported.
- Native output currently requires exactly `fn main(): i32`.
- Runtime platform adapter exists only for Windows. Keep the common runtime
  separate so a POSIX adapter can be added later.
- LLVM itself has no stdout instruction. Printing must ultimately call a
  platform API; do not invent a custom LLVM intrinsic merely to hide this.

## Bootstrap compiler

Module/import self-hosting is complete for the current contract.
Bootstrap diagnostics and CLI parity are complete for the current contract.
Integer-cast self-hosting is complete for the approved integer matrix.
Float-cast self-hosting is complete for the approved `f32`/`f64` matrix.
Payload-free enum self-hosting is complete for the current contract.
Static move-ownership self-hosting is complete for the current contract.

- `src/bootstrap/` contains the K implementation of source loading, lexer,
  flat AST, parser, semantic checking, textual LLVM emission, and the driver.
- The K module loader resolves symbol imports to `.k`, wildcard imports to
  `mod.k`, loads dependencies first, and de-duplicates canonical paths.
- Bootstrap source-map segments preserve each canonical path and translate
  lexer, parser, semantic, and import diagnostics to original file positions.
- Bootstrap lexer/parser diagnostics preserve an error kind or expected token;
  do not regress them to generic `invalid source` or `error` messages.
- Bootstrap CLI requires exactly seven arguments after the executable. Argument,
  filesystem, and process-launch failures return `1`; source, verification, and
  linker diagnostics return `2`.
- Bootstrap CLI emits stable stderr for argument, input-load, output-write, and
  process-launch failures, and frees all acquired argument buffers on early exit.
- Bootstrap CLI rejects entries without a `.k` suffix and empty output, tool, or
  runtime paths before source loading or process launch.
- Bootstrap acceptance requires stable CLI failure messages exactly once across
  `kc1` through `kc4`, plus exact semantic diagnostic parity.
- Bootstrap stages compile `src/bootstrap/main.k` as a real module graph.
- Run `.\scripts\bootstrap.ps1` for the clean-room development loop: it wipes
  `out/bootstrap/`, seeds `kc1` via `kc0`, builds `kc2`–`kc4`, verifies the
  fixed point (`kc3.ll` == `kc4.ll`), logs per-stage wall time to
  `out/bootstrap/timings.txt` (baseline ~35–50 s/stage Release; warn >120 s),
    then runs the fixture/parity suite. `-SkipNativeBuild`, `-NoCleanRoom`, and
    `-SkipSuite` scope individual runs; `-Kc0Path`/`$env:KLANG_KC0` select the
    seed binary.
- Development flow (C8 Phase 3): feature work lands only in `src/bootstrap`,
  `tests/cases`, and `docs.md`. The C++ reference compiler is removed from
  this branch — its source lives on `kc0-reference`; never reintroduce it
  here. Behavior changes require an acceptance fixture plus a differential
  harness pass (`k_differential_tests`).
- Scalar functions, control flow, raw pointers, casts, indexing, structs,
  generic functions and structs (including generic-struct instance methods and
  associated functions), and minimal nullable values emit typed LLVM text
  directly from K.
- `src/bootstrap/list.k` provides generic `List<T>` through
  `List<T>.new()` and `add`/`free` methods; loader-only `ByteBuffer` and
  `SymbolTable` remain dedicated containers. `StringBuilder` provides primary
  `append(string)`, low-level `add(u8)`/`appendBytes`, and deep-copy `toString()`
  with deterministic drop for both the builder and resulting owned string;
  LLVM text, compiler command/diagnostic construction, and main CLI messages use it.
- Statement-form `when` is self-hosted with first-match semantics, an optional
  final `else`, and block or single-statement branch bodies.
- Expression-valued `when` is self-hosted for return/initializer contexts; each
  arm is an expression terminated by `;`. A final `else` may be omitted for an
  exhaustively covered enum subject.
- A value arm may be a scoped block whose final expression omits `;` and
  supplies the arm value.
- Payload-free enum declarations, variant lookup, enum parameters/returns,
  `u32` tag emission, and exhaustive enum `when` are self-hosted.
- Ownership state and use-after-move diagnostics are self-hosted for strings,
  arrays, nullable owners, generic values, owned calls/returns, and structs with
  owned `free(self)`. Owned-string locals, resource-struct locals, and resource
  owned parameters use runtime drop flags and unwind through the existing
  defer paths; terminating branches do not poison ownership on continuing paths.
- `kc0` seeds `kc1` only. `kc1` builds `kc2`, `kc2` builds `kc3`, and `kc3`
  builds `kc4` without invoking the C++ compiler.

## Recommended next milestone

Continue replacing numeric ASCII runs in bootstrap text emission with
`StringBuilder.append(string)`, keeping byte APIs only for encoding and raw data.
