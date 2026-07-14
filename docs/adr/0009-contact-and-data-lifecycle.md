# 0009 — Contact and data lifecycle: reset, archive, erase

Daftar needed three ways to make ledger data recede — settle one account, set a
person aside, or wipe everything. The guiding principle: **an outstanding debt
never disappears silently**, so destructive power is layered and, except for the
final wipe, reversible.

## Reset account — settle, don't purge

"Reset a contact" appends a single balancing [[Entry]] (opposite direction,
magnitude equal to the current balance) in the **active currency lens**, zeroing
the [[Balance]] while keeping the full history. We rejected **purging** the
contact's entries (destroys the audit trail, needs a bespoke bulk-undo) and a
bookkeeping **reset-point** (an opening-balance marker — more faithful to real
ledgers but far more complex). Settle-as-entry upholds the existing invariant
that a settle *is* just an Entry (CONTEXT.md · Balance), so the PDF statement and
analysis graph need no special case, and undo is simply deleting that one entry.
Scoped to the active lens; disabled when the lens is already settled.

## Archive — set aside fully, soft-gated

Archiving is a **whole-person** state (both currencies) that removes a Contact
from the home list, the grand totals, **and** the analysis graph, into a separate
Archived view. We rejected "declutter the list only" because it leaves header
totals that no longer reconcile with the visible rows. Archiving is
**soft-gated**: permitted with an unsettled balance, but the confirm dialog names
the outstanding amount first, so a live debt never leaves the totals unseen.
Adding an entry to an archived contact **auto-unarchives** them (dealing with
them again makes them active), avoiding a dead-end read-only state.

## Erase all data — irreversible factory reset

A Settings action wipes contacts, entries, [[Profile]], and all settings to a
genuine first-run state (the literal "as if installed for the first time"). We
chose a full factory reset over a data-only clear. Because there is **no
[[Backup]] restore yet** (ADR 0001 is written but unshipped), this is
unrecoverable and is guarded by a **type-to-confirm** (the user types مسح to
enable the button). When Backup ships, Erase should offer an export-first escape
hatch.

## Consequences

- The `contacts` table gains an `archived` flag (schema bump).
- Balance / grand-total / analysis-graph queries must **exclude archived
  contacts' entries**, not merely hide their rows — otherwise an archived
  balance still leaks into `totalsOf(...)` and the cumulative series.
- Erase must reset the in-memory `ThemeController` / `ProfileController` back to
  defaults after dropping the data, so the app reflects first-run state without
  a restart.
