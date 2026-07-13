# 1. Local-only storage with manual backup/restore; no cloud sync

Date: 2026-07-13

## Status

Accepted

## Context

The app is a personal debt/IOU ledger. Its data — who owes whom, and how much — is
the kind of financial record users genuinely cannot afford to lose. At the same time,
a core product goal is that the app be "very simple," offline, and private, with data
in a local SQLite database and no server.

These two goals are in tension. Pure local storage means the data lives in exactly one
place: uninstalling the app, losing the phone, or a factory reset destroys every balance
with no way to recover or to prove who owed what.

Options considered:

- **A. Pure local, no backup.** Simplest to build; full data-loss risk.
- **B. Manual export/import backup.** A backup file the user can save off-device
  (Drive, email, etc.) and restore later. No accounts, no network stack, still
  local-first. Recoverable after device loss.
- **C. Automatic cloud sync** (e.g. Google Drive / Firebase). Safest against data loss,
  but introduces authentication, network code, and sync-conflict handling — directly
  at odds with the "very simple" goal, and adds a privacy surface.

## Decision

Adopt **Option B**: local-only SQLite as the source of truth, plus a **manual
backup/restore** feature.

- A "Backup" action exports the full database to a single file surfaced via the Android
  share sheet / file save, so the user can store it wherever they like (Drive, email to
  self, etc.).
- A "Restore" action imports such a file and replaces the local database.
- The app also **auto-writes a rolling local backup** (e.g. on app close, keeping the
  last N) so users who never tap "Backup" still have a recovery point on-device.
- No user accounts, no network calls, no cloud service integration.

## Consequences

- **Positive:** Data is recoverable after device loss without any server, account, or
  network code. The architecture stays offline-first and private. Implementation is
  small (serialize DB → file → share sheet, and the reverse).
- **Positive:** Keeps the door open — cloud sync (Option C) can be layered on later
  without changing the local-first data model.
- **Negative:** Recovery is only as good as the user's discipline in saving backup files
  off-device. A user who never exports and never copies the auto-backup off the phone
  can still lose everything.
- **Negative:** Restore is a full replace, not a merge — restoring an old backup discards
  newer local entries. Merge/sync semantics are explicitly out of scope.
- **Backup file format** (plain SQLite vs. JSON, and whether to encrypt it) is left as a
  follow-up implementation decision.
