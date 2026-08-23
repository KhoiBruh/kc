# C8 Parity Ledger

Known behavioral divergences between the C++ reference compiler (`kc0`) and the
self-hosted K compiler (`kc1`–`kc4`). Each row is closed by a phase-1 commit
that fixes exactly one side and adds a focused test.

Status values: `open` · `fixed-kc1` · `fixed-kc0` · `intentional`

| ID | Summary | kc0 behavior | kc1 behavior | Status | Discovered |
| --- | --- | --- | --- | --- | --- |
| D1 | Method call on a constructor temporary inside an expression-bodied function (`fn f() => AstView(n).walk();`) | Builds | Rejected by semantic ("type mismatch") | open | 2026-08-23, AstView refactor |
| D2 | `when` expression arm-type unification with mixed literal / call arms | Accepts | Requires uniform arm types (first-arm typing; literals default `i32`) | open | 2026-08-23, types.k conversion |
| D3 | Checked integer-cast lowering strategy | Direct range check against target-type bounds | Value round-trip (`trunc/sext/zext` back + `icmp eq`, panic on mismatch) | intentional | 2026-08-23, cast_widening_checks fixture |

Rules:

* New divergences found by the differential harness or by hand enter this table
  before any fix is written.
* Closing a row requires: a focused failing test first, then a one-sided fix,
  then green acceptance in both Debug and Release.
* Rows marked `intentional` must also be described in `docs.md` if they are
  user-visible.
