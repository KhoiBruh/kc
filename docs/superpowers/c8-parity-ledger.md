# C8 Parity Ledger

Known behavioral divergences between the C++ reference compiler (`kc0`) and the
self-hosted K compiler (`kc1`–`kc4`). Each row is closed by a phase-1 commit
that fixes exactly one side and adds a focused test.

Status values: `open` · `fixed-kc1` · `fixed-kc0` · `intentional`

| ID | Summary | kc0 behavior | kc1 behavior | Status | Discovered |
| --- | --- | --- | --- | --- | --- |
| D1 | Method call on a constructor temporary inside an expression-bodied function (`fn f() => AstView(n).walk();`) | Builds | Rejected by semantic ("type mismatch") | fixed-kc1 (2026-08-23) | 2026-08-23, AstView refactor |
| D2 | `when` expression arm-type unification with mixed literal / call arms | Accepts | Requires uniform arm types (first-arm typing; literals default `i32`) | fixed-kc0 (2026-08-23, rule standardized) | 2026-08-23, types.k conversion |
| D3 | Checked integer-cast lowering strategy | Direct range check against target-type bounds | Value round-trip (`trunc/sext/zext` back + `icmp eq`, panic on mismatch) | intentional | 2026-08-23, cast_widening_checks fixture |
| D4 | Cast-panic diagnostics: `k_boot_panic` called with null message | Emits named global with "integer/float cast out of range" (25/23 bytes) | Emits `ptr null, i64 0` — silent exit 2 | fixed-kc1 (2026-08-23) | 2026-08-23, differential harness |
| D5 | Slice indexing of non-local collections (`view.bytes[1]`, const-slice `PREFIX[0]`) | Supported (value path) | Required a local collection; rejected | fixed-kc0 (2026-08-23) | 2026-08-23, differential harness |

Closure notes:

* **D1 (fixed in kc1).** Root cause: the self-hosted semantic inferred the
  receiver expression twice for instance-method calls (once for the receiver
  type, once in the argument loop); the second inference re-ran
  `markExpressionMoved` on an already-moved parameter and rejected it. Fix:
  constructor calls now stamp their result type onto the AST node
  (`inferExpressionType` short-circuits stamped `CALL` nodes) and the argument
  loop reuses the already-computed receiver `TypeValue`. Emission additionally
  needed `registerDropRequests` so auto-dropped resource parameters register
  their `List<T>.free` specializations before body emission. Regression case:
  `tests/cases/temporary_receiver_method.k`.
* **D2 (fixed in kc0, rule standardized).** Canonical rule adopted from kc1:
  a value-form `when` takes the type of its first arm; every later arm must be
  accepted by that type (narrow-to-wide integer widening only); integer
  literal arms default to `i32`; no context-expected typing propagates into
  arms. kc0 dropped the blanket numeric-pair exemption and stopped propagating
  the context-expected type into arm analysis (`Semantic.cpp` when-expression
  block); the five bootstrap sites that relied on context typing now bind the
  `when` result and convert explicitly. Regression fixture:
  `tests/fixtures/bootstrap-semantic-when-common-type.k` (acceptance
  invalid list). Rule documented in `docs.md`, `when` expression section.
* **D4 (fixed in kc1).** `appendCastPanic` emitted `k_boot_panic(ptr null,
  i64 0)` — programs panicked with exit 2 but printed nothing. Now emits two
  module globals (`integer cast out of range` / `float cast out of range`)
  selected per cast path, with a GEP'd pointer + exact length. Found by the
  differential harness (stderr mismatch on panic fixtures).
* **D5 (fixed in kc0).** Slice indexing required the collection to be a local
  variable; member-field slices (`view.bytes[1]`) and constant slices
  (`PREFIX[0]`) were rejected. `emitIndexPointer` now falls back to a value
  path: `emitExpr` produces the `{ptr, len}` slice for any non-local object,
  then bounds-check + GEP as usual. Found by the differential harness.

Rules:

* New divergences found by the differential harness or by hand enter this table
  before any fix is written.
* Closing a row requires: a focused failing test first, then a one-sided fix,
  then green acceptance in both Debug and Release.
* Rows marked `intentional` must also be described in `docs.md` if they are
  user-visible.
