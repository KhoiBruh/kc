# kc — the K programming language

K is an experimental low-level, statically compiled language. The compiler is
**self-hosted**: `src/bootstrap` contains the entire compiler (lexer, parser,
semantic analyzer, and textual LLVM emitter) written in K itself, and LLVM is
the backend.

## Repository layout

| Path | Contents |
| --- | --- |
| `src/bootstrap/` | The self-hosted compiler, written in K |
| `src/lib/std/`, `src/lib/bootstrap/` | Runtime libraries linked into generated executables |
| `tests/cases/` | End-to-end acceptance programs (run through every bootstrap stage) |
| `tests/fixtures/` | Invalid inputs and module-graph fixtures |
| `tests/drivers/` | PowerShell scenario scripts (acceptance, differential harness) |
| `tests/harness/` | K driver sources used by the drivers |
| `tests/unit/` | Runtime unit tests |
| `docs.md` | Language design document (Vietnamese) |
| `docs/superpowers/` | Implementation plans (C8 consolidation) and parity ledger |

## Branch model

* **`main`** — self-hosted development trunk. The C++ reference compiler has
  been removed from this branch.
* **`kc0-reference`** — frozen snapshot of the C++ reference compiler
  (`kc0`). Build it there when a new seed binary is needed.
* Tag **`kc0-seed-v0.1`** / [Release](https://github.com/KhoiBruh/kc/releases/tag/kc0-seed-v0.1)
  — prebuilt `kc0-windows-x64.exe` used as the bootstrap seed.

## Development loop

```powershell
# Configure + build runtimes + run driver tests (needs a kc0 seed, see below)
.\scripts\dev.ps1 all

# Full clean-room self-hosted loop: wipe artifacts, seed kc1 via kc0,
# build kc2–kc4, verify fixed point (kc3.ll == kc4.ll), log timings,
# then run the fixture/parity suite.
.\scripts\bootstrap.ps1
```

`scripts/dev.ps1` and `scripts/bootstrap.ps1` are intentionally untracked
(`scripts/` is gitignored); keep local copies.

### Providing the kc0 seed binary

Driver tests and `bootstrap.ps1` need a `kc0.exe`. Resolution order:
1. explicit `-Kc0Path` / `-Kc0` parameter,
2. `$env:KLANG_KC0`,
3. `tools/kc0.exe` in the repository root.

Sources: check out `kc0-reference` and build, or download the prebuilt
`kc0-windows-x64.exe` from the release above. For CMake-driven tests,
configure with `-DKLANG_KC0_EXE=C:/path/to/kc0.exe`.

## Toolchain

* LLVM **22.1.8** (`opt`, `clang`) — locally at `C:/LLVM`.
* MSVC (x64) with C++20 for the two runtime static libraries.
* Windows is currently the only supported target.

See `AGENTS.md` for working rules and `docs/superpowers/c8-unify-self-hosted.md`
for the consolidation plan and parity ledger.
