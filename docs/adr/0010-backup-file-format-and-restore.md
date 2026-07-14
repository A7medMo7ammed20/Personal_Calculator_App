# 10. Backup file format: whole-database copy, unencrypted; full-replace restore

Date: 2026-07-14

## Status

Accepted. Closes the follow-up decision that [ADR 0001](0001-local-only-storage-with-manual-backup.md)
deferred ("backup file format — plain SQLite vs. JSON, and whether to encrypt it —
is left as a follow-up implementation decision"). Delivers slice #13; leaves the
[[Erase all data]] "export-first" hatch to slice #25 (ADR 0009), which reuses the
pieces built here.

## Context

The [[Backup]] feature needs a concrete file format, an encryption stance, and a
restore procedure. Three genuine forks:

1. **Format** — a whole-database **SQLite file copy**, or a hand-written **JSON**
   export of each table.
2. **Encryption** — encrypt the file, or leave it plaintext.
3. **Restore** — how to swap the database under a running app without leaving
   stale in-memory state or a half-written database.

Constraints that shaped the answers: the app is deliberately "very simple",
offline, local-only (ADR 0001); settings and [[Profile]] already live **inside**
the same database file; balances are **derived** from `REAL` [[Entry]] amounts, so
any re-serialisation is a chance for them to drift; and `min_sdk_android: 21`
reaches devices whose bundled SQLite predates 3.27.

## Decision

- **Format: copy the whole database file.** Not JSON. A byte-for-byte copy
  reproduces [[Contact]]s, [[Entry]] rows, and [[Balance]]s exactly (criterion:
  "restoring a backup taken on another install reproduces the same Contacts,
  Entries, and balances"), and carries settings + profile along **for free**
  because they share the file. JSON was rejected: it means hand-serialising every
  table, keeping that in sync as the schema grows, and re-serialising `REAL`
  amounts — more code and more ways for a balance to drift, buying only
  human-readability that a local-first app does not need.

- **Snapshot mechanism: close → copy → reopen.** Not `VACUUM INTO` (needs SQLite
  ≥ 3.27, absent on Android 10 and older within our `min_sdk` 21 range) and not a
  live file copy (risks copying mid-journal state). A **closed** database's file
  is a fully checkpointed, consistent snapshot on every Android version; copying
  it is trivial and portable. The same primitive serves both the manual export and
  the [[Auto-backup]] ring.

- **Encryption: none (v1).** The file is plaintext, with an export-time hint to
  store it somewhere private. Encryption was rejected for v1 because it fights the
  feature's own purpose — recovery after a **lost phone**: a device-keystore key
  dies with the phone (backup unrestorable elsewhere), and a user passphrase adds
  a *second* forget-it-and-lose-everything failure mode to the safety net. An
  **optional** passphrase may be added later; the door is left open.

- **Restore: full replace, validated before the swap.** Restoring **discards** all
  current data in favour of the backup (never a merge — ADR 0001). The incoming
  file is opened in a temporary location and checked first: it must be a valid
  Daftar database (expected tables) with `user_version ≤` the current
  `schemaVersion`. A foreign/corrupt file, or one from a **newer** app version, is
  **refused before anything is replaced** (avoids SQLite's downgrade error and a
  half-swapped live database). Immediately before the swap, the current data is
  snapshotted into the [[Auto-backup]] ring, so an accidental restore is itself
  undoable. Gated by a **single confirm dialog** — not the type-to-confirm
  reserved for the irreversible [[Erase all data]] — because a restore is a
  deliberate, recoverable act. Restoring an **older** backup is fine: reopening at
  the current version runs the existing idempotent migrations forward.

- **Seamless reload after the swap.** One shared helper: reopen the database
  (`AppDatabase.close()` nulls the cached handle, so the next `open()` reads the
  new file), reload every controller (`Theme`/`Profile`/`Currency`/`Locale`) via
  the **same code path used at startup**, then remount the app root via a key bump
  (~20 lines, no new package) so no screen keeps stale rows. Slice #25's
  [[Erase all data]] reuses this exact helper after it drops the data.

- **Auto-backup: on background, if changed.** A rolling ring in app-private
  storage (keep the last few), written when the app is backgrounded
  (`AppLifecycleState.paused` — reliably delivered, unlike `detached`) and only if
  a write happened since the last snapshot (an in-memory dirty flag set by the
  write paths). Surfaced in-app as a dated "restore from auto-backup" list — the
  on-device **undo**. These snapshots **die on uninstall**, so they complement,
  never replace, a manual export off-device.

- **Two new dependencies:** `share_plus` (export via the OS share sheet) and
  `file_picker` (restore-from-file). Both only hand off to the OS — no network —
  consistent with [ADR 0008](0008-external-app-deep-links.md).

## Consequences

- **Positive:** highest-fidelity backup with the least code; settings/profile
  round-trip for free; auto-backup and manual export share one snapshot primitive;
  restoring an older backup migrates forward automatically.
- **Positive:** the export helper and the post-swap reload helper are built to be
  reused by slice #25 (Erase's export-first hatch and its post-wipe reload).
- **Negative:** the backup file is **opaque** (a binary `.db`, not inspectable) and
  **unencrypted** — plaintext financial data sits wherever the user stores it
  (documented; the export hint warns the user).
- **Negative:** a backup from a **newer** schema cannot be restored into an older
  app install — deliberately refused with a clear message rather than corrupting.
- **Negative:** close→copy→reopen briefly closes the live database; acceptable
  because export is a user-initiated Settings action and auto-backup fires while
  the app is already backgrounded.
- **Follow-up:** an optional passphrase-encrypted backup remains open for a later
  slice; when [[Erase all data]] (#25) ships it should call the export helper for
  its escape hatch.
