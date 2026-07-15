# 11. Amount calculator is a result-only keypad — rounded at entry, no `Entry`/schema change

Date: 2026-07-15

## Status

Accepted. Sits entirely above the data layer; compatible with the [[Backup]]
format guard of [ADR 0010](0010-backup-file-format-and-restore.md) precisely
because it changes nothing there.

## Context

A [[Amount calculator]] lets the user compute an [[Entry]]'s amount with
`+ − × ÷` and drop the result into the shared amount box (every entry flow —
add, edit, quick-add معاملة, add-contact opening balance — via the one
`EntryFields` widget). Three decisions had genuine alternatives:

1. **Does the derivation get stored?** We could persist the expression
   (`1500 + 300 + 200`) alongside the amount — auto-appended to the description,
   or as a new `Entry` column — so the record shows *how* the number was reached.
2. **Precision.** Division yields non-terminating decimals (`10 / 3 = 3.333…`).
   Store the full `double`, or round at entry?
3. **Non-positive results.** The amount box requires a positive magnitude, but
   `50 − 80 = −30` and `50 − 50 = 0` are reachable. Reject, pass through, or take
   the absolute value?

## Decision

- **Result only — the expression is never stored.** The amount box receives just
  the computed number; the [[Entry]] keeps a plain `double` exactly as if typed.
  Persisting the derivation was **rejected**: it would force a schema migration, a
  **[[Backup]] format version bump** (Slice 13 shipped a newer-version restore
  guard — ADR 0010), and changes to the PDF [[Statement]] columns and the
  [[Running summary]] math — a large blast radius for marginal value. A user who
  wants the breakdown can still type it into the description.
- **Round to 2 decimals at entry.** The result is rounded to the currency's
  2 decimals *before* it lands in the field, so stored data equals displayed data.
  Storing the full `double` was **rejected**: a row would *display* `3.33` while
  the [[Balance]] and [[Statement]] totals silently carried the hidden tail, so a
  column of rounded rows would not sum to the shown total — the "off by a cent"
  bug that erodes trust in a ledger. The rounded value is visible in the sheet
  before commit, so there is no surprise (`10/3 → 3.33`, then `×3 → 9.99`, is
  accepted as inherent to money rounding).
- **Expression *with* precedence, evaluated by a pure module.** The sheet shows
  the whole formula and evaluates it with `× ÷` before `+ −` (a small, pure-Dart,
  unit-tested evaluator — no Flutter dependency, mirroring the app's pure-domain
  pattern). Malformed input is prevented by construction (no double operators, one
  `.` per number, no dangling operator); **division by zero** is the evaluator's
  single guarded case and blocks commit with an explicit message.
- **Non-positive results cannot be committed; no absolute value.** Negatives are
  fine *mid*-calculation; the "Done" action is disabled whenever the current
  result is `≤ 0`, with the amount-box validator as a backstop. Taking the
  absolute value was **rejected**: this is a ledger where [[Direction]] is
  meaningful and explicit, so silently turning `50 − 80` into `+30` could book a
  debt the wrong way round. A wrong sign is the user's cue to check their math or
  flip [[Direction]] themselves.

## Consequences

- **Positive:** the feature is a self-contained UI + pure-evaluator addition with
  **zero** persistence, migration, backup-version, or PDF impact — it cannot
  destabilise the three flows that already share `EntryFields`, nor the restore
  path.
- **Positive:** stored amounts stay equal to displayed amounts, upholding the
  [[Balance]]/[[Statement]] "rows sum to the total" invariant.
- **Negative:** the derivation is lost once the sheet closes — a future
  contributor might "helpfully" add expression persistence. This ADR records that
  the omission is **deliberate** and names the cost (schema + backup-format +
  statement churn) of reversing it.
