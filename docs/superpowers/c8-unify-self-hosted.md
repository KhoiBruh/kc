# C8 — Consolidate on the Self-Hosted Compiler

**Status:** Draft — awaiting approval
**Created:** 2026-08-23
**Scope:** Compiler architecture. No language-semantics changes in this plan.

---

## 1. Problem

Klang currently maintains two complete compiler implementations that must stay
behaviorally identical:

| Implementation | Location | Role |
| --- | --- | --- |
| C++ reference | `src/lang` (frontend), `src/codegen` (LLVM emission) | Builds `kc0`; defines current behavior |
| Self-hosted K | `src/bootstrap/**.k` | Builds `kc1`–`kc4`; proves the language can compile itself |

Costs of the duplication:

* Every language feature lands twice, in two languages, against two ASTs.
* Parity is enforced only through acceptance fixtures; subtle gaps surface late
  and expensively (three surfaced during the 2026-08 cleanup week alone — see
  the parity ledger in §4).
* The C++ frontend is dead weight the moment the K chain is trustworthy, but it
  cannot simply be deleted until parity is provable, not assumed.

## 2. Goal

Make the **self-hosted K compiler the single source of truth**:

1. `scripts/bootstrap.ps1` (`kc0 → kc1 → … → kc4`, fixed-point check) becomes
   the primary development loop.
2. New language features land **only** in `src/bootstrap`.
3. `src/lang` + `src/codegen` are frozen (bug-fix only), then removed once the
   ledger is empty for one full release cycle.

### Non-goals

* Any change to language semantics or diagnostics wording beyond what closing a
  divergence requires.
* POSIX runtime support (separate effort; platform adapter seam already exists).
* Making the two emitters produce byte-identical IR — they are different
  programs; only behavior must match.

## 3. Target architecture (end state)

```
K sources (src/bootstrap)
        │  compiled by previous stage
        ▼
   kc(N-1) ──► kc(N) ──► user programs (.ll → opt → clang → .exe)

kc0 (C++) exists only to seed kc1 from scratch; it is not part of the
development loop and eventually disappears from the repository.
```

Seed policy (decision needed, see §7): either commit a seed `kc1` binary per
release tag, or keep `kc0` in-tree purely as a seed builder.

## 4. Phase 0 — Parity ledger + differential harness (no behavior change)

**Status: complete (2026-08-23).** Ledger seeded with D1–D3; differential
harness merged as `tests/drivers/DifferentialTests.ps1` (CTest name
`k_differential_tests`), comparing exit codes, stdout, and stderr of every
`tests/cases/*.k` program built through both pipelines; IR hashes recorded
informationally. First run surfaced D4/D5, both fixed. Ledger has no
untriaged rows.

Create `docs/superpowers/c8-parity-ledger.md`. Seeded entries from the
2026-08 session (each reproduced and verified):

* **D1 — method call on a constructor temporary inside an expression-bodied
  function.** `fn f() => AstView(nodes).walk(x);` builds under `kc0` but the
  self-hosted semantic checker rejects it ("type mismatch"). Workaround today:
  bind to a local first. Decision needed: extend kc1 semantic to accept, or
  codify rejection and update kc0 + style rules.
* **D2 — `when` expression arm-type unification.** kc1 requires all arms to
  share one type (first-arm typing; literal arms default to `i32`), rejecting
  mixed literal/`u64`-call arms that kc0 accepts. Today's convention: keep arms
  uniform and rely on implicit widening at `return`.
* **D3 — checked integer-cast lowering strategy.** kc0 compares the original
  value against target-type bounds directly; kc1 uses a value round-trip
  (`trunc/sext/zext` back + `icmp eq`). Both are valid; emitted IR text
  necessarily differs. Record as intentional; never gate on cross-emitter IR
  equality.

Harness work (tests only):

* Extend the acceptance driver: for every fixture, run the program through the
  kc0 pipeline **and** the kcN pipeline; assert equal exit codes, equal stdout,
  equal stderr diagnostics text. IR-hash equality is recorded informationally,
  never asserted across emitters.
* The ledger gains an entry for every new divergence discovered by the harness;
  a phase-1 commit closes it.

**Exit criteria:** harness runs in CI (both Debug and Release); ledger has no
untriaged rows.

## 5. Phase 1 — Close behavioral divergences (TDD, one commit each)

Each ledger row becomes a focused failing test first, then a fix in exactly one
implementation:

* If kc1 is wrong → fix `src/bootstrap/semantic/**` or `llvm_text/**`.
* If kc0 is wrong or kc1's behavior is preferable → change `src/lang` /
  `src/codegen`, and note the canonical behavior in `docs.md`.

Constraints carried over from AGENTS.md: positioned diagnostics preserved, CLI
exit codes `0/1/2` preserved, bootstrap diagnostic-parity fixtures updated in
the same commit.

## 6. Phase 2 — Invert the development flow

* AGENTS.md is rewritten: feature work targets `src/bootstrap` + fixtures only;
  touching `src/lang`/`src/codegen` requires a stated reason.
* `scripts/bootstrap.ps1` gains a clean-room mode: wipe stage artifacts, seed
  from the agreed source (see §7), and require the full fixed-point plus
  fixture suite to pass without invoking the C++ compiler anywhere except the
  seed step.
* Performance guard: self-compile wall time per stage recorded per release
  (baseline 2026-08-23: ~0.83 s/stage, Debug, this machine).

## 7. Phase 3 — Freeze, then remove

1. Freeze: `src/lang` + `src/codegen` accept only toolchain-breaking fixes;
   README marks them as reference-only.
2. After one full release cycle with an empty ledger and green inverted-flow
   CI: delete both directories, drop `kc0` targets from CMake, update
   AGENTS.md architecture diagram and build instructions.
3. Repository then ships: K sources + seed policy artifact + scripts.

## 8. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Silent diagnostics drift | Differential harness gates every PR; ledger reviewed at milestones |
| Chain-depth cost during development | Per-stage timing logged; currently sub-second and unchanged by recent refactors |
| Broken seed blocks all development | Seed policy keeps a known-good seed artifact per release tag |
| Scope creep into runtime/platform work | Explicit non-goal; platform adapter seam untouched |

## 9. Decisions requested

1. Approve the overall direction (bootstrap as sole compiler).
2. Seed policy: committed seed binary per release vs. keep `kc0` in-tree as
   seed builder until Phase 3 deletion.
3. For D1/D2: match kc0 behavior in kc1, or promote kc1's stricter rules to
   canonical (requires updating `docs.md` and any affected code)?
