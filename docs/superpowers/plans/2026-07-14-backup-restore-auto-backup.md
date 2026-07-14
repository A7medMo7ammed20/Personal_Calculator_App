# Backup / restore + auto-backup (Slice #13) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Daftar a local-only Backup (export a whole-database file to the OS share sheet), Restore (validated full-replace of the live database), and an on-device Auto-backup ring that makes an accidental Restore/Erase undoable.

**Architecture:** A new data-layer `BackupService` orchestrates over the existing `AppDatabase` using the **close → copy file → reopen** primitive (ADR 0010): the same primitive serves the manual export and the rolling auto-backup ring. Restore validates a candidate file in a temporary read-only handle *before* touching the live database, snapshots the current data into the ring, then swaps. A shared **reload helper** in `app.dart` reopens the database (via the same startup controller-`load()` path) and remounts the app root with a key bump, so no screen keeps stale rows; slice #25's Erase reuses it. Platform hand-off (share sheet, file picker) sits behind injectable callbacks (`onShareBackup`, `onPickBackupFile`) that mirror the existing `onSharePdf` seam. Auto-backup fires on `AppLifecycleState.paused` guarded by an in-memory dirty flag set by the write paths.

**Tech Stack:** Flutter, Dart, `sqflite` / `sqflite_common_ffi` (tests), `share_plus` (export), `file_picker` (restore-from-file), `intl` (dated list), Flutter `gen-l10n` (ARB → `AppLocalizations`).

## Global Constraints

- **Local-only, no network, no account** — no cloud, no network call anywhere (ADR 0001, ADR 0008). New deps only hand off to the OS.
- **New dependencies: `share_plus` and `file_picker` only.** Do NOT add `path_provider`; derive the app-private backups directory from `getDatabasesPath()`.
- **Format: whole-database file copy, unencrypted.** Never JSON, never re-serialise amounts (ADR 0010). No encryption in v1.
- **Snapshot mechanism: close → copy → reopen.** Never `VACUUM INTO` (needs SQLite ≥ 3.27, absent under `min_sdk_android: 21`), never a live-file copy.
- **Restore: full replace, validated before the swap.** A foreign/corrupt file, or one whose `user_version > AppDatabase.schemaVersion`, is refused **before the live database is touched**. Restoring an **older** backup is supported (reopen at current version runs migrations forward). Gated by a **single confirm dialog** — NOT the type-to-confirm reserved for Erase all data.
- **Auto-backup ring: keep the last `N = 5`** (a fixed constant, not a Settings knob). Written on `AppLifecycleState.paused` and only if the in-memory dirty flag is set (a write happened since the last snapshot).
- **`AppDatabase.schemaVersion` is currently `5`; no schema change** in this slice. Settings and Profile already live inside the database file and ride the copy for free.
- **Bilingual + RTL:** every new user-facing string is added to BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`; Arabic renders RTL.
- **Test philosophy:** assert external behaviour only (round-trip reproduces the ledger; a bad file is refused without harming live data; the ring keeps only N) — never internal call sequences. `BackupService` tests use **real temp-file paths** (`Directory.systemTemp.createTemp`), NOT `inMemoryDatabasePath` — the mechanism is a file copy and `:memory:` has no file to copy.
- **Commit style:** conventional commits, `(#26)` suffix, matching recent history (e.g. `feat: … (#25)`).

---

## File Structure

**Created:**
- `lib/data/backup_service.dart` — `BackupService` (export / restore / autoBackup / listAutoBackups), `RestoreResult` enum, `AutoBackupEntry` model.
- `lib/data/backup_dirty_flag.dart` — `BackupDirtyFlag` (in-memory mark/reset).
- `lib/presentation/backup/auto_backup_observer.dart` — `AutoBackupObserver` lifecycle widget (paused + dirty → onBackground).
- `lib/presentation/settings/backup_restore_section.dart` — `BackupRestoreSection` widget + `BackupSectionConfig` (the Settings UI + dialogs).
- `test/data/backup_service_test.dart`
- `test/data/backup_dirty_flag_test.dart`
- `test/presentation/auto_backup_observer_test.dart`
- `test/presentation/backup_restore_section_test.dart`
- `test/presentation/app_reload_test.dart` (full-app erase/restore reload integration)

**Modified:**
- `lib/data/app_database.dart` — expose `factory` getter + `resolvedPath()`.
- `lib/data/contact_repository.dart`, `lib/data/entry_repository.dart`, `lib/data/settings_repository.dart`, `lib/data/profile_repository.dart` — optional `BackupDirtyFlag` marks writes.
- `lib/app.dart` — Stateful; shared `_reloadApp` + key-bump remount + `_showMessage`; wrap in `AutoBackupObserver`; refactor `_eraseAllData`; new optional backup fields; build `BackupSectionConfig`.
- `lib/presentation/home/home_screen.dart` — thread `BackupSectionConfig? backup` to Settings.
- `lib/presentation/settings/settings_screen.dart` — render `BackupRestoreSection` when a config is supplied.
- `lib/main.dart` — create dirty flag + `BackupService` + platform callbacks, wire everything.
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` — new strings.
- `pubspec.yaml` — add `share_plus`, `file_picker`.
- `test/widget_test.dart` — update if `DebtLedgerApp` construction changes (only if needed).

---

## Task 1: AppDatabase — expose `factory` + `resolvedPath()`

`BackupService` needs the live database file path (to copy it) and the same `DatabaseFactory` the app opened with (to validate a candidate file). Add both without changing `open()`'s behaviour.

**Files:**
- Modify: `lib/data/app_database.dart`
- Test: `test/data/app_database_test.dart`

**Interfaces:**
- Produces: `DatabaseFactory get factory` and `Future<String> resolvedPath()` on `AppDatabase`.

- [ ] **Step 1: Write the failing test** — append to `test/data/app_database_test.dart`:

```dart
  test('resolvedPath returns the injected path', () async {
    final appDb = AppDatabase(factory: databaseFactoryFfi, path: '/tmp/x.db');
    expect(await appDb.resolvedPath(), '/tmp/x.db');
  });

  test('factory getter returns the injected factory', () {
    final appDb = AppDatabase(factory: databaseFactoryFfi, path: '/tmp/x.db');
    expect(identical(appDb.factory, databaseFactoryFfi), isTrue);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/app_database_test.dart`
Expected: FAIL — `The getter 'factory'/'resolvedPath' isn't defined`.

- [ ] **Step 3: Implement** — in `lib/data/app_database.dart`, add the getter and refactor path resolution:

```dart
  /// The factory the app opened with — reused to validate candidate backup
  /// files against the same SQLite engine (see BackupService).
  DatabaseFactory get factory => _factory;

  /// The absolute path of the live database file (same resolution `open` uses).
  Future<String> resolvedPath() async =>
      _path ?? p.join(await _factory.getDatabasesPath(), _defaultFileName);
```

Then change `open()` to reuse it:

```dart
    final dbPath = await resolvedPath();
    final db = await _factory.openDatabase(
```

(Delete the old inline `final dbPath = _path ?? p.join(...)` line.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/app_database_test.dart`
Expected: PASS (all tests, including the pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add lib/data/app_database.dart test/data/app_database_test.dart
git commit -m "feat: expose AppDatabase.factory and resolvedPath for backups (#26)"
```

---

## Task 2: `BackupService.export()`

Produce a consistent whole-database snapshot file (close → copy → reopen) to hand to the share sheet.

**Files:**
- Create: `lib/data/backup_service.dart`
- Test: `test/data/backup_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.factory`, `AppDatabase.resolvedPath()`, `AppDatabase.close()`, `AppDatabase.open()`.
- Produces:
  - `class BackupService({required AppDatabase appDatabase, required Directory backupsDir, DateTime Function() clock = DateTime.now, int retain = 5})`
  - `Future<File> export()` — returns a `.db` file named `daftar-backup-<yyyy-MM-dd-HHmmss>.db` inside `backupsDir`.

- [ ] **Step 1: Write the failing test** — create `test/data/backup_service_test.dart`:

```dart
import 'dart:io';

import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('daftar_backup_');
  });
  tearDown(() => tmp.delete(recursive: true));

  // A real temp-file AppDatabase (the mechanism is a file copy; :memory: has no
  // file). Each call makes a fresh db path under [tmp].
  AppDatabase dbAt(String name) =>
      AppDatabase(factory: databaseFactoryFfi, path: p.join(tmp.path, name));

  BackupService serviceFor(AppDatabase db) => BackupService(
        appDatabase: db,
        backupsDir: Directory(p.join(tmp.path, 'backups')),
      );

  test('export produces a Daftar database file that carries the rows', () async {
    final appDb = dbAt('live.db');
    addTearDown(appDb.close);
    final db = await appDb.open();
    final id = await db.insert('contacts', {'name': 'Ali'});
    await db.insert('entries', {
      'contact_id': id, 'amount': 100.0, 'direction': 'owedToMe',
      'currency': 'SAR', 'created_at': 0,
    });

    final file = await serviceFor(appDb).export();

    expect(await file.exists(), isTrue);
    expect(p.basename(file.path), startsWith('daftar-backup-'));
    expect(file.path, endsWith('.db'));

    // The copy is a real, queryable Daftar database with the same row.
    final copy = await databaseFactoryFfi.openDatabase(file.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    addTearDown(copy.close);
    expect((await copy.query('contacts')).single['name'], 'Ali');

    // The live database still works after export (reopened).
    expect((await (await appDb.open()).query('contacts')).length, 1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/backup_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../backup_service.dart'`.

- [ ] **Step 3: Implement** — create `lib/data/backup_service.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_database.dart';

/// Orchestrates local-only backups over [AppDatabase] using the close → copy →
/// reopen primitive (ADR 0010). One primitive serves the manual export and the
/// rolling auto-backup ring. No network, no encryption (v1).
class BackupService {
  BackupService({
    required this.appDatabase,
    required this.backupsDir,
    this.clock = DateTime.now,
    this.retain = 5,
  });

  final AppDatabase appDatabase;
  final Directory backupsDir;
  final DateTime Function() clock;
  final int retain;

  static const String _autoPrefix = 'auto-';
  static const String _exportPrefix = 'daftar-backup-';

  /// Manual export: a consistent snapshot file to hand to the share sheet.
  Future<File> export() async {
    await backupsDir.create(recursive: true);
    final name = '$_exportPrefix${_stamp(clock())}.db';
    final dest = File(p.join(backupsDir.path, name));
    await _snapshotTo(dest.path);
    return dest;
  }

  /// Close the live database (checkpoints WAL into a consistent file), copy that
  /// file to [destPath], then reopen so the app keeps working.
  Future<void> _snapshotTo(String destPath) async {
    final livePath = await appDatabase.resolvedPath();
    await appDatabase.close();
    try {
      await File(livePath).copy(destPath);
    } finally {
      await appDatabase.open(); // reopen even if the copy threw
    }
  }

  /// `2026-07-14-153012` — sortable, human-readable, filename-safe.
  String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/backup_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/backup_service.dart test/data/backup_service_test.dart
git commit -m "feat: BackupService.export snapshots the whole database to a file (#26)"
```

---

## Task 3: Auto-backup ring — `autoBackup()` + rotation + `listAutoBackups()`

A rolling ring of on-device snapshots, keeping only the last `retain` (N = 5), surfaced as a dated list.

**Files:**
- Modify: `lib/data/backup_service.dart`
- Test: `test/data/backup_service_test.dart`

**Interfaces:**
- Produces:
  - `Future<File> autoBackup()` — writes `auto-<millisSinceEpoch>.db`, then rotates to keep the newest `retain`.
  - `Future<List<AutoBackupEntry>> listAutoBackups()` — newest-first.
  - `class AutoBackupEntry { final File file; final DateTime createdAt; }`

- [ ] **Step 1: Write the failing test** — append to `test/data/backup_service_test.dart`:

```dart
  test('autoBackup keeps only the last N snapshots (ring rotation)', () async {
    final appDb = dbAt('live.db');
    addTearDown(appDb.close);
    await appDb.open();

    // A clock that advances one second per call, so each snapshot is a distinct
    // file (the timestamp is the filename).
    var t = DateTime(2026, 1, 1, 0, 0, 0);
    final service = BackupService(
      appDatabase: appDb,
      backupsDir: Directory(p.join(tmp.path, 'backups')),
      clock: () => t = t.add(const Duration(seconds: 1)),
      retain: 5,
    );

    for (var i = 0; i < 7; i++) {
      await service.autoBackup();
    }

    final list = await service.listAutoBackups();
    expect(list.length, 5); // 7 written, oldest 2 evicted
    // Newest first: strictly descending timestamps.
    for (var i = 0; i < list.length - 1; i++) {
      expect(list[i].createdAt.isAfter(list[i + 1].createdAt), isTrue);
    }
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/backup_service_test.dart -n "ring rotation"`
Expected: FAIL — `autoBackup`/`listAutoBackups` not defined.

- [ ] **Step 3: Implement** — add to `lib/data/backup_service.dart` (inside the class, plus the model at file scope):

```dart
  /// Snapshot the current database into the ring, then evict all but the newest
  /// [retain]. The filename carries the timestamp so the ring is self-describing.
  Future<File> autoBackup() async {
    await backupsDir.create(recursive: true);
    final name = '$_autoPrefix${clock().millisecondsSinceEpoch}.db';
    final dest = File(p.join(backupsDir.path, name));
    await _snapshotTo(dest.path);
    await _rotate();
    return dest;
  }

  Future<void> _rotate() async {
    final all = await listAutoBackups(); // newest first
    for (final stale in all.skip(retain)) {
      if (await stale.file.exists()) await stale.file.delete();
    }
  }

  /// The auto-backup ring, newest first. Parses the timestamp from the filename.
  Future<List<AutoBackupEntry>> listAutoBackups() async {
    if (!await backupsDir.exists()) return const [];
    final entries = <AutoBackupEntry>[];
    for (final f in await backupsDir.list().toList()) {
      if (f is! File) continue;
      final name = p.basename(f.path);
      if (!name.startsWith(_autoPrefix) || !name.endsWith('.db')) continue;
      final millis = int.tryParse(
          name.substring(_autoPrefix.length, name.length - '.db'.length));
      if (millis == null) continue;
      entries.add(AutoBackupEntry(
        file: f,
        createdAt: DateTime.fromMillisecondsSinceEpoch(millis),
      ));
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }
```

At the bottom of the file (top-level):

```dart
/// One entry in the auto-backup ring: the snapshot file and when it was taken.
class AutoBackupEntry {
  const AutoBackupEntry({required this.file, required this.createdAt});
  final File file;
  final DateTime createdAt;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/backup_service_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/backup_service.dart test/data/backup_service_test.dart
git commit -m "feat: BackupService auto-backup ring keeps last N snapshots (#26)"
```

---

## Task 4: `BackupService.restore()` — validated full-replace + round-trip + snapshot-before-swap

Validate the candidate file in a temporary read-only handle, snapshot the current data into the ring (so the restore is itself undoable), then swap. Leaves the database **closed** — the caller's reload helper reopens it.

**Files:**
- Modify: `lib/data/backup_service.dart`
- Test: `test/data/backup_service_test.dart`

**Interfaces:**
- Produces:
  - `enum RestoreResult { success, notABackup, newerVersion, failure }`
  - `Future<RestoreResult> restore(File file)`

- [ ] **Step 1: Write the failing test** — append to `test/data/backup_service_test.dart`:

```dart
  test('round-trip: export from A restores exactly into B', () async {
    // Seed database A.
    final a = dbAt('a.db');
    addTearDown(a.close);
    final da = await a.open();
    final aliId = await da.insert('contacts', {'name': 'Ali'});
    await da.insert('entries', {
      'contact_id': aliId, 'amount': 300.0, 'direction': 'owedToMe',
      'currency': 'YER', 'created_at': 111,
    });
    await da.insert('settings', {'key': 'accent', 'value': 'plum'});
    await da.insert('settings', {'key': 'profile_name', 'value': 'Ahmed'});
    final file = await serviceFor(a).export();

    // Restore into an empty database B.
    final b = dbAt('b.db');
    addTearDown(b.close);
    await b.open();
    final result = await serviceFor(b).restore(file);

    expect(result, RestoreResult.success);
    final db = await b.open(); // reopen reads the swapped file
    expect((await db.query('contacts')).single['name'], 'Ali');
    final entry = (await db.query('entries')).single;
    expect(entry['amount'], 300.0);
    expect(entry['currency'], 'YER');
    expect(
      (await db.query('settings', where: 'key = ?', whereArgs: ['accent']))
          .single['value'],
      'plum',
    );
    expect(
      (await db.query('settings', where: 'key = ?', whereArgs: ['profile_name']))
          .single['value'],
      'Ahmed',
    );
  });

  test('restore snapshots the current data into the ring before swapping', () async {
    final a = dbAt('a.db');
    addTearDown(a.close);
    await (await a.open()).insert('contacts', {'name': 'FromBackup'});
    final file = await serviceFor(a).export();

    final b = dbAt('b.db');
    addTearDown(b.close);
    await (await b.open()).insert('contacts', {'name': 'CurrentB'});
    final service = serviceFor(b);

    await service.restore(file);

    // The pre-swap snapshot of B is now the newest ring entry.
    final ring = await service.listAutoBackups();
    expect(ring, isNotEmpty);
    final snap = await databaseFactoryFfi.openDatabase(ring.first.file.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    addTearDown(snap.close);
    expect((await snap.query('contacts')).single['name'], 'CurrentB');
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/backup_service_test.dart -n "round-trip"`
Expected: FAIL — `restore`/`RestoreResult` not defined.

- [ ] **Step 3: Implement** — add to `lib/data/backup_service.dart`. First the import at the top:

```dart
import 'package:sqflite/sqflite.dart' show OpenDatabaseOptions, Database;
```

Then the method + enum:

```dart
  /// Full-replace restore (ADR 0010). Validates [file] in a temporary read-only
  /// handle FIRST — a foreign/corrupt file or a newer-schema backup is refused
  /// before the live database is touched. On success it snapshots the current
  /// data into the ring (so the restore is undoable), then swaps the file in and
  /// leaves the database CLOSED for the caller's reload helper to reopen.
  Future<RestoreResult> restore(File file) async {
    final verdict = await _validate(file);
    if (verdict != RestoreResult.success) return verdict;

    await autoBackup(); // snapshot current data before the swap
    final livePath = await appDatabase.resolvedPath();
    await appDatabase.close();
    // Remove stale WAL/SHM sidecars so the swapped-in file reopens cleanly.
    for (final suffix in const ['-wal', '-shm']) {
      final side = File('$livePath$suffix');
      if (await side.exists()) await side.delete();
    }
    await file.copy(livePath);
    return RestoreResult.success;
  }

  /// Opens [file] read-only and checks it is a Daftar database no newer than us.
  Future<RestoreResult> _validate(File file) async {
    if (!await file.exists()) return RestoreResult.notABackup;
    Database? probe;
    try {
      probe = await appDatabase.factory.openDatabase(
        file.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final version = Sqflite.firstIntValue(
              await probe.rawQuery('PRAGMA user_version')) ??
          0;
      if (version > AppDatabase.schemaVersion) return RestoreResult.newerVersion;
      final tables = (await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('contacts','entries','settings')",
      ))
          .map((r) => r['name'] as String)
          .toSet();
      if (!tables.containsAll(const {'contacts', 'entries', 'settings'})) {
        return RestoreResult.notABackup;
      }
      return RestoreResult.success;
    } catch (_) {
      return RestoreResult.notABackup; // not a SQLite file at all
    } finally {
      await probe?.close();
    }
  }
```

Add `Sqflite` to the sqflite import (it provides `firstIntValue`): change the import to

```dart
import 'package:sqflite/sqflite.dart' show OpenDatabaseOptions, Database, Sqflite;
```

And the enum at file scope:

```dart
/// The outcome of a restore attempt (ADR 0010). Only [success] touches the live
/// database; every other value leaves it exactly as it was.
enum RestoreResult { success, notABackup, newerVersion, failure }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/backup_service_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/backup_service.dart test/data/backup_service_test.dart
git commit -m "feat: BackupService.restore validates then full-replaces the database (#26)"
```

---

## Task 5: restore rejects a foreign/corrupt file (live data untouched)

**Files:**
- Test: `test/data/backup_service_test.dart`

**Interfaces:**
- Consumes: `restore`, `RestoreResult.notABackup`.

- [ ] **Step 1: Write the failing test** — append:

```dart
  test('restore refuses a non-Daftar file and leaves live data untouched', () async {
    final b = dbAt('b.db');
    addTearDown(b.close);
    await (await b.open()).insert('contacts', {'name': 'Keep me'});

    final garbage = File(p.join(tmp.path, 'notes.txt'));
    await garbage.writeAsString('this is not a database');

    final result = await serviceFor(b).restore(garbage);

    expect(result, RestoreResult.notABackup);
    // Live data survived — the file was refused before any swap.
    expect((await (await b.open()).query('contacts')).single['name'], 'Keep me');
  });
```

- [ ] **Step 2: Run to verify it fails or passes**

Run: `flutter test test/data/backup_service_test.dart -n "refuses a non-Daftar"`
Expected: PASS immediately (Task 4 already implements `_validate`). If it FAILS, fix `_validate`'s catch/table check until it passes. This task exists to lock the behaviour with its own regression test.

- [ ] **Step 3: (only if Step 2 failed) adjust `_validate`** so a non-SQLite file returns `notABackup`. No change expected.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/backup_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/data/backup_service_test.dart lib/data/backup_service.dart
git commit -m "test: restore refuses a foreign file without harming live data (#26)"
```

---

## Task 6: restore refuses a newer-schema backup

**Files:**
- Test: `test/data/backup_service_test.dart`

**Interfaces:**
- Consumes: `restore`, `RestoreResult.newerVersion`.

- [ ] **Step 1: Write the failing test** — append:

```dart
  test('restore refuses a backup from a newer app version', () async {
    // A valid-looking Daftar db but with user_version one past ours.
    final newerPath = p.join(tmp.path, 'newer.db');
    final newer = await databaseFactoryFfi.openDatabase(
      newerPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion + 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE contacts (id INTEGER PRIMARY KEY, name TEXT)');
          await db.execute('CREATE TABLE entries (id INTEGER PRIMARY KEY)');
          await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
        },
      ),
    );
    await newer.close();

    final b = dbAt('b.db');
    addTearDown(b.close);
    await (await b.open()).insert('contacts', {'name': 'Keep me'});

    final result = await serviceFor(b).restore(File(newerPath));

    expect(result, RestoreResult.newerVersion);
    expect((await (await b.open()).query('contacts')).single['name'], 'Keep me');
  });
```

- [ ] **Step 2: Run to verify** (Task 4 already implements the version check)

Run: `flutter test test/data/backup_service_test.dart -n "newer app version"`
Expected: PASS. If FAIL, ensure `_validate` reads `PRAGMA user_version` and returns `newerVersion` before the table check.

- [ ] **Step 3: (only if Step 2 failed) fix `_validate`.** No change expected.

- [ ] **Step 4: Run the whole file**

Run: `flutter test test/data/backup_service_test.dart`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add test/data/backup_service_test.dart lib/data/backup_service.dart
git commit -m "test: restore refuses a newer-schema backup (#26)"
```

---

## Task 7: `BackupDirtyFlag` + wire into the write paths

An in-memory flag set by every data write, so auto-backup can skip when nothing changed (story #19). Injected as an optional named param into the four repositories — existing constructions (which pass nothing) keep compiling and are unaffected.

**Files:**
- Create: `lib/data/backup_dirty_flag.dart`
- Modify: `lib/data/contact_repository.dart`, `lib/data/entry_repository.dart`, `lib/data/settings_repository.dart`, `lib/data/profile_repository.dart`
- Test: `test/data/backup_dirty_flag_test.dart`

**Interfaces:**
- Produces:
  - `class BackupDirtyFlag { bool get isDirty; void mark(); void reset(); }`
  - `ContactRepository(this._appDb, {BackupDirtyFlag? dirty})` (and the same optional `{BackupDirtyFlag? dirty}` on `EntryRepository`, `SettingsRepository`, `ProfileRepository`).

- [ ] **Step 1: Write the failing test** — create `test/data/backup_dirty_flag_test.dart`:

```dart
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_dirty_flag.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late BackupDirtyFlag dirty;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    dirty = BackupDirtyFlag();
  });
  tearDown(() => appDb.close());

  test('starts clean and mark/reset flip the flag', () {
    expect(dirty.isDirty, isFalse);
    dirty.mark();
    expect(dirty.isDirty, isTrue);
    dirty.reset();
    expect(dirty.isDirty, isFalse);
  });

  test('a contact write marks the flag dirty', () async {
    final repo = ContactRepository(appDb, dirty: dirty);
    await repo.add(const Contact(name: 'Ali'));
    expect(dirty.isDirty, isTrue);
  });

  test('a settings write marks the flag dirty', () async {
    final repo = SettingsRepository(appDb, dirty: dirty);
    await repo.setAccent(AccentTheme.plum);
    expect(dirty.isDirty, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/backup_dirty_flag_test.dart`
Expected: FAIL — `backup_dirty_flag.dart` missing; `dirty:` named arg undefined.

- [ ] **Step 3: Implement.** Create `lib/data/backup_dirty_flag.dart`:

```dart
/// An in-memory "data changed since the last snapshot" flag (ADR 0010). The
/// write paths [mark] it; the lifecycle auto-backup checks it and [reset]s it,
/// so backgrounding without edits writes no snapshot (story #19). Not persisted
/// — it only guards the on-device ring within a single app run.
class BackupDirtyFlag {
  bool _dirty = false;
  bool get isDirty => _dirty;
  void mark() => _dirty = true;
  void reset() => _dirty = false;
}
```

In `lib/data/contact_repository.dart` — add the field and mark every write:

```dart
  ContactRepository(this._appDb, {BackupDirtyFlag? dirty}) : _dirty = dirty;
  final BackupDirtyFlag? _dirty;
```

(Add `import 'backup_dirty_flag.dart';`.) At the end of `add`, `setArchived`, `update`, `delete` — after the DB call, add `_dirty?.mark();`. For `add`, mark before `return`:

```dart
  Future<Contact> add(Contact contact) async {
    final db = await _appDb.open();
    final id = await db.insert(table, _toRow(contact));
    _dirty?.mark();
    return contact.copyWith(id: id);
  }
```

In `lib/data/entry_repository.dart` — same pattern: `EntryRepository(this._appDb, {BackupDirtyFlag? dirty}) : _dirty = dirty;` + `final BackupDirtyFlag? _dirty;` + `import 'backup_dirty_flag.dart';`; mark in `add`, `update`, `delete`.

In `lib/data/settings_repository.dart` — `SettingsRepository(this._appDb, {BackupDirtyFlag? dirty}) : _dirty = dirty;` + field + import; mark once in the private `_set`:

```dart
  Future<void> _set(String key, String value) async {
    final db = await _appDb.open();
    await db.insert(table, {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _dirty?.mark();
  }
```

In `lib/data/profile_repository.dart` — same: constructor `{BackupDirtyFlag? dirty}`, field, import, and `_dirty?.mark();` at the end of its `_set`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/backup_dirty_flag_test.dart`
Expected: PASS. Then `flutter test test/data/` — the existing repo tests still pass (they construct repos without `dirty:`).

- [ ] **Step 5: Commit**

```bash
git add lib/data/backup_dirty_flag.dart lib/data/contact_repository.dart lib/data/entry_repository.dart lib/data/settings_repository.dart lib/data/profile_repository.dart test/data/backup_dirty_flag_test.dart
git commit -m "feat: mark a dirty flag on data writes for auto-backup gating (#26)"
```

---

## Task 8: `AutoBackupObserver` — snapshot on background if dirty

A tiny lifecycle widget: on `AppLifecycleState.paused`, if the dirty flag is set, reset it and fire `onBackground` (which the app wires to `BackupService.autoBackup`). Isolated so it is unit-testable without pumping the whole app.

**Files:**
- Create: `lib/presentation/backup/auto_backup_observer.dart`
- Test: `test/presentation/auto_backup_observer_test.dart`

**Interfaces:**
- Consumes: `BackupDirtyFlag`.
- Produces: `class AutoBackupObserver extends StatefulWidget` with `{required BackupDirtyFlag dirtyFlag, required Future<void> Function() onBackground, required Widget child}`.

- [ ] **Step 1: Write the failing test** — create `test/presentation/auto_backup_observer_test.dart`:

```dart
import 'package:debt_ledger/data/backup_dirty_flag.dart';
import 'package:debt_ledger/presentation/backup/auto_backup_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('snapshots on paused only when dirty, once per dirty span', (
    tester,
  ) async {
    final dirty = BackupDirtyFlag();
    var calls = 0;

    await tester.pumpWidget(AutoBackupObserver(
      dirtyFlag: dirty,
      onBackground: () async => calls++,
      child: const SizedBox(),
    ));

    // Clean → paused does nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, 0);

    // Dirty → paused snapshots once and clears the flag.
    dirty.mark();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, 1);
    expect(dirty.isDirty, isFalse);

    // Backgrounding again without a new write does nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, 1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/auto_backup_observer_test.dart`
Expected: FAIL — `auto_backup_observer.dart` missing.

- [ ] **Step 3: Implement** — create `lib/presentation/backup/auto_backup_observer.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/backup_dirty_flag.dart';

/// Fires [onBackground] when the app is backgrounded (`AppLifecycleState.paused`
/// — reliably delivered, unlike `detached`) and only if [dirtyFlag] is set, then
/// clears the flag. This is the auto-backup trigger (ADR 0010): no snapshot when
/// nothing changed since the last one (story #19).
class AutoBackupObserver extends StatefulWidget {
  const AutoBackupObserver({
    super.key,
    required this.dirtyFlag,
    required this.onBackground,
    required this.child,
  });

  final BackupDirtyFlag dirtyFlag;
  final Future<void> Function() onBackground;
  final Widget child;

  @override
  State<AutoBackupObserver> createState() => _AutoBackupObserverState();
}

class _AutoBackupObserverState extends State<AutoBackupObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && widget.dirtyFlag.isDirty) {
      widget.dirtyFlag.reset();
      widget.onBackground();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/presentation/auto_backup_observer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/backup/auto_backup_observer.dart test/presentation/auto_backup_observer_test.dart
git commit -m "feat: AutoBackupObserver snapshots on background when dirty (#26)"
```

---

## Task 9: Shared reload helper + key-bump remount in `app.dart`

Convert `DebtLedgerApp` to Stateful. Add the shared reload helper (`_reloadApp`: reload the four controllers via the startup path, reset the dirty flag, bump a generation key so the whole navigator remounts with no stale rows), a root `scaffoldMessengerKey` + `_showMessage` (so a restore's success message survives the remount), wrap the app in `AutoBackupObserver`, and refactor `_eraseAllData` to route through `_reloadApp`. New backup fields are optional so focused tests are unaffected.

**Files:**
- Modify: `lib/app.dart`
- Test: `test/presentation/app_reload_test.dart`

**Interfaces:**
- Consumes: `BackupService`, `BackupDirtyFlag`, `AutoBackupObserver`, controller `load()`s, `AppDatabase.eraseAll()`.
- Produces: `DebtLedgerApp` gains optional `this.backupService`, `this.dirtyFlag`, `this.onShareBackup` (`Future<void> Function(File)`), `this.onPickBackupFile` (`Future<File?> Function()`). Internally builds a `BackupSectionConfig` (Task 11) passed to `HomeScreen(backup: ...)`.

- [ ] **Step 1: Write the failing test** — create `test/presentation/app_reload_test.dart`. It boots the full app against ffi + a real temp DB, seeds a contact, then erases via Settings and asserts the remounted home is empty (exercises `_reloadApp` + key-bump). (This replaces relying on `widget_test.dart` for reload coverage.)

```dart
import 'dart:io';

import 'package:debt_ledger/app.dart';
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_dirty_flag.dart';
import 'package:debt_ledger/data/backup_service.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/locale/locale_controller.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('erase reloads and remounts to an empty home', (tester) async {
    final tmp = await Directory.systemTemp.createTemp('daftar_app_');
    addTearDown(() => tmp.delete(recursive: true));
    final appDb = AppDatabase(
        factory: databaseFactoryFfiNoIsolate, path: p.join(tmp.path, 'live.db'));
    addTearDown(appDb.close);
    final dirty = BackupDirtyFlag();
    final settings = SettingsRepository(appDb, dirty: dirty);
    final contacts = ContactRepository(appDb, dirty: dirty);
    final entries = EntryRepository(appDb, dirty: dirty);
    await contacts.add(const Contact(name: 'Ali'));

    final theme = ThemeController(settings);
    final profile = ProfileController(ProfileRepository(appDb, dirty: dirty));
    final currency = CurrencyController(settings);
    final locale = LocaleController(settings);
    await theme.load();
    await profile.load();
    await currency.load();
    await locale.load();

    await tester.pumpWidget(DebtLedgerApp(
      appDatabase: appDb,
      contactRepository: contacts,
      entryRepository: entries,
      themeController: theme,
      profileController: profile,
      currencyController: currency,
      localeController: locale,
      backupService: BackupService(
          appDatabase: appDb, backupsDir: Directory(p.join(tmp.path, 'backups'))),
      dirtyFlag: dirty,
      onShareBackup: (_) async {},
      onPickBackupFile: () async => null,
    ));
    await tester.pumpAndSettle(); // splash → home

    expect(find.text('Ali'), findsOneWidget);

    // Open Settings → Erase all data → type-to-confirm.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('erase-all-data')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('erase-confirm-field')), 'ERASE');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('erase-confirm')));
    await tester.pumpAndSettle();

    // Remounted home no longer shows the erased contact.
    expect(find.text('Ali'), findsNothing);
  });
}
```

> Note: the exact overflow-menu label ("Settings") and the erase keys come from `settings_screen.dart` / `home_screen.dart` (English default locale). If the menu item is an icon or differently-labelled, adjust the finder — the erase keys (`erase-all-data`, `erase-confirm-field`, `erase-confirm`) are stable.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/app_reload_test.dart`
Expected: FAIL — `DebtLedgerApp` has no `backupService`/`dirtyFlag`/`onShareBackup`/`onPickBackupFile` params.

- [ ] **Step 3: Implement** — rewrite `lib/app.dart` as Stateful. Key changes:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

import 'branding/daftar_splash.dart';
import 'data/app_database.dart';
import 'data/backup_dirty_flag.dart';
import 'data/backup_service.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'presentation/backup/auto_backup_observer.dart';
import 'presentation/currency/currency_controller.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/locale/locale_controller.dart';
import 'presentation/profile/profile_controller.dart';
import 'presentation/settings/backup_restore_section.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_controller.dart';

class DebtLedgerApp extends StatefulWidget {
  const DebtLedgerApp({
    super.key,
    required this.appDatabase,
    required this.contactRepository,
    required this.entryRepository,
    required this.themeController,
    required this.profileController,
    required this.currencyController,
    required this.localeController,
    this.backupService,
    this.dirtyFlag,
    this.onShareBackup,
    this.onPickBackupFile,
  });

  final AppDatabase appDatabase;
  final ContactRepository contactRepository;
  final EntryRepository entryRepository;
  final ThemeController themeController;
  final ProfileController profileController;
  final CurrencyController currencyController;
  final LocaleController localeController;
  final BackupService? backupService;
  final BackupDirtyFlag? dirtyFlag;
  final Future<void> Function(File file)? onShareBackup;
  final Future<File?> Function()? onPickBackupFile;

  @override
  State<DebtLedgerApp> createState() => _DebtLedgerAppState();
}

class _DebtLedgerAppState extends State<DebtLedgerApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  int _generation = 0;

  /// Shared reload helper (ADR 0010): reopen the database implicitly by reloading
  /// every controller via the SAME code path used at startup, clear the dirty
  /// flag, then bump [_generation] so the navigator remounts with no stale rows.
  /// Reused by Erase all data (#25) and by Restore.
  Future<void> _reloadApp() async {
    await widget.themeController.load();
    await widget.profileController.load();
    await widget.currencyController.load();
    await widget.localeController.load();
    widget.dirtyFlag?.reset();
    if (mounted) setState(() => _generation++);
  }

  Future<void> _eraseAllData() async {
    await widget.appDatabase.eraseAll();
    await _reloadApp();
  }

  void _showMessage(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  BackupSectionConfig? get _backupConfig {
    final service = widget.backupService;
    final share = widget.onShareBackup;
    final pick = widget.onPickBackupFile;
    if (service == null || share == null || pick == null) return null;
    return BackupSectionConfig(
      service: service,
      onShare: share,
      onPickFile: pick,
      onRestored: _reloadApp,
      showMessage: _showMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = ListenableBuilder(
      listenable: Listenable.merge([widget.themeController, widget.localeController]),
      builder: (context, _) => MaterialApp(
        scaffoldMessengerKey: _messengerKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: Brightness.light, seed: widget.themeController.seed),
        darkTheme: buildAppTheme(brightness: Brightness.dark, seed: widget.themeController.seed),
        themeMode: widget.themeController.themeMode,
        locale: widget.localeController.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, supported) {
          if (locales != null) {
            for (final device in locales) {
              for (final option in supported) {
                if (option.languageCode == device.languageCode) return option;
              }
            }
          }
          return const Locale('en');
        },
        home: KeyedSubtree(
          key: ValueKey(_generation),
          child: _generation == 0
              ? Builder(
                  builder: (context) => DaftarSplash(
                    onDone: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => _home()),
                    ),
                  ),
                )
              : _home(), // remount lands straight on home (no splash replay)
        ),
      ),
    );

    final dirty = widget.dirtyFlag;
    final service = widget.backupService;
    if (dirty == null || service == null) return app;
    return AutoBackupObserver(
      dirtyFlag: dirty,
      onBackground: service.autoBackup,
      child: app,
    );
  }

  Widget _home() => HomeScreen(
        repository: widget.contactRepository,
        entryRepository: widget.entryRepository,
        currencyController: widget.currencyController,
        themeController: widget.themeController,
        profileController: widget.profileController,
        localeController: widget.localeController,
        onEraseAllData: _eraseAllData,
        backup: _backupConfig,
      );
}
```

> `HomeScreen(backup: ...)` and `BackupSectionConfig` do not exist until Tasks 10–11. To keep this task compilable on its own, you may temporarily omit the `backup:` argument and the `_backupConfig`/`BackupSectionConfig` import, then add them in Task 11. If executing strictly task-by-task, add a `// TODO(#26): backup config` placeholder returning `null` and remove it in Task 11. Prefer implementing Tasks 10–11 immediately after so the import resolves.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/presentation/app_reload_test.dart` and `flutter test test/widget_test.dart`
Expected: PASS. (If `widget_test.dart` constructs `DebtLedgerApp`, it still compiles — the new params are optional.)

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart test/presentation/app_reload_test.dart
git commit -m "feat: shared reload helper + key-bump remount, reused by erase (#26)"
```

---

## Task 10: Localization strings (English + Arabic)

Add every new user-facing string to both ARB files, then regenerate `AppLocalizations`. Placed before the UI task so the getters exist when the section consumes them.

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Generated: `lib/l10n/gen/app_localizations*.dart` (via `flutter gen-l10n`)

**Interfaces:**
- Produces `AppLocalizations` getters: `settingsBackup`, `backupExport`, `backupExportHint`, `backupRestoreFromFile`, `backupRestoreFromAuto`, `backupRestoreTitle`, `backupRestoreMessage`, `backupRestoreConfirm`, `backupNoAutoBackups`, `backupAutoBackupsTitle`, `backupCancel` (reuse existing `cancel`), `restoreSuccess`, `restoreNotABackup`, `restoreNewerVersion`, `restoreFailed`, `exportSuccess`, `exportFailed`.

- [ ] **Step 1: Add English strings** — in `lib/l10n/app_en.arb`, before the closing `}`, add (keep valid JSON — add a comma to the current last entry):

```json
  "settingsBackup": "Backup & restore",
  "@settingsBackup": { "description": "Settings section header for backup/restore/auto-backup (#26)." },
  "backupExport": "Export backup",
  "@backupExport": { "description": "Action that exports the whole database to a shareable file (#26)." },
  "backupExportHint": "This file isn't encrypted — store it somewhere private.",
  "@backupExportHint": { "description": "Export-time reminder the backup file is plaintext (#26, story 17)." },
  "backupRestoreFromFile": "Restore from file",
  "@backupRestoreFromFile": { "description": "Action that restores from a picked backup file (#26)." },
  "backupRestoreFromAuto": "Restore from auto-backup",
  "@backupRestoreFromAuto": { "description": "Action that opens the dated on-device auto-backup list (#26)." },
  "backupRestoreTitle": "Restore backup?",
  "@backupRestoreTitle": { "description": "Confirm dialog title before a full-replace restore (#26)." },
  "backupRestoreMessage": "This replaces all current data with the backup. Your current data is saved to an auto-backup first, so you can undo this.",
  "@backupRestoreMessage": { "description": "Confirm dialog body warning restore is a full replace (#26, story 8/9)." },
  "backupRestoreConfirm": "Restore",
  "@backupRestoreConfirm": { "description": "Confirm button label for the restore dialog (#26)." },
  "backupNoAutoBackups": "No auto-backups yet",
  "@backupNoAutoBackups": { "description": "Shown when the auto-backup ring is empty (#26)." },
  "backupAutoBackupsTitle": "Restore from auto-backup",
  "@backupAutoBackupsTitle": { "description": "Title of the dated auto-backup picker (#26, story 12)." },
  "restoreSuccess": "Data restored",
  "@restoreSuccess": { "description": "Success message after a restore (#26, story 20)." },
  "restoreNotABackup": "That file isn't a Daftar backup",
  "@restoreNotABackup": { "description": "Refused: the picked file is foreign/corrupt (#26, story 13)." },
  "restoreNewerVersion": "This backup was made by a newer version of Daftar",
  "@restoreNewerVersion": { "description": "Refused: the backup is from a newer app version (#26, story 14)." },
  "restoreFailed": "Restore failed",
  "@restoreFailed": { "description": "Generic restore failure message (#26, story 20)." },
  "exportSuccess": "Backup exported",
  "@exportSuccess": { "description": "Success message after an export/share (#26, story 20)." },
  "exportFailed": "Export failed",
  "@exportFailed": { "description": "Failure message when export could not produce/share a file (#26)." }
```

- [ ] **Step 2: Add Arabic strings** — in `lib/l10n/app_ar.arb`, add the matching keys (add a comma to the current last entry first):

```json
  "settingsBackup": "النسخ الاحتياطي والاستعادة",
  "backupExport": "تصدير نسخة احتياطية",
  "backupExportHint": "هذا الملف غير مُشفَّر — احفظه في مكان خاص.",
  "backupRestoreFromFile": "استعادة من ملف",
  "backupRestoreFromAuto": "استعادة من نسخة تلقائية",
  "backupRestoreTitle": "استعادة النسخة الاحتياطية؟",
  "backupRestoreMessage": "سيؤدي هذا إلى استبدال جميع البيانات الحالية بالنسخة الاحتياطية. يتم حفظ بياناتك الحالية في نسخة تلقائية أولًا، حتى يمكنك التراجع.",
  "backupRestoreConfirm": "استعادة",
  "backupNoAutoBackups": "لا توجد نسخ تلقائية بعد",
  "backupAutoBackupsTitle": "استعادة من نسخة تلقائية",
  "restoreSuccess": "تمت استعادة البيانات",
  "restoreNotABackup": "هذا الملف ليس نسخة احتياطية من دفتر",
  "restoreNewerVersion": "أُنشئت هذه النسخة بإصدار أحدث من دفتر",
  "restoreFailed": "فشلت الاستعادة",
  "exportSuccess": "تم تصدير النسخة الاحتياطية",
  "exportFailed": "فشل التصدير"
```

- [ ] **Step 3: Regenerate + analyze**

Run: `flutter gen-l10n` (or `flutter pub get` which triggers it) then `flutter analyze lib/l10n`
Expected: `lib/l10n/gen/app_localizations*.dart` now expose the new getters; analyze clean.

- [ ] **Step 4: Verify the whole suite still compiles**

Run: `flutter test test/l10n`
Expected: PASS (existing l10n tests unaffected).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/gen
git commit -m "feat: localize Backup & restore strings (en + ar) (#26)"
```

---

## Task 11: `BackupRestoreSection` widget + wire into Settings

The Settings UI: an Export action (with the not-encrypted hint), a Restore-from-file action (single confirm dialog → pick → restore), and a Restore-from-auto-backup action (dated list → confirm → restore). All platform hand-off is behind the injected `onShare`/`onPickFile`; all outcomes surface via `showMessage`; a successful restore calls `onRestored` (the app's reload helper).

**Files:**
- Create: `lib/presentation/settings/backup_restore_section.dart`
- Modify: `lib/presentation/settings/settings_screen.dart`
- Test: `test/presentation/backup_restore_section_test.dart`

**Interfaces:**
- Consumes: `BackupService`, `RestoreResult`, `AutoBackupEntry`, `AppLocalizations` getters from Task 10.
- Produces:
  - `class BackupSectionConfig { final BackupService service; final Future<void> Function(File) onShare; final Future<File?> Function() onPickFile; final Future<void> Function() onRestored; final void Function(String) showMessage; }`
  - `class BackupRestoreSection extends StatelessWidget { const BackupRestoreSection({required this.config}); }`
  - `SettingsScreen` gains `final BackupSectionConfig? backup;` and renders the section when non-null.

- [ ] **Step 1: Write the failing tests** — create `test/presentation/backup_restore_section_test.dart`:

```dart
import 'dart:io';

import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_service.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/settings/backup_restore_section.dart';
import 'package:debt_ledger/presentation/settings/settings_screen.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tmp;
  late AppDatabase appDb;
  late BackupService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('daftar_section_');
    appDb = AppDatabase(
        factory: databaseFactoryFfi, path: p.join(tmp.path, 'live.db'));
    service = BackupService(
        appDatabase: appDb, backupsDir: Directory(p.join(tmp.path, 'backups')));
  });
  tearDown(() async {
    await appDb.close();
    await tmp.delete(recursive: true);
  });

  Widget host(BackupSectionConfig config) => MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          controller: ThemeController(SettingsRepository(appDb)),
          backup: config,
        ),
      );

  BackupSectionConfig config({
    Future<void> Function(File)? onShare,
    Future<File?> Function()? onPickFile,
    Future<void> Function()? onRestored,
    void Function(String)? showMessage,
  }) =>
      BackupSectionConfig(
        service: service,
        onShare: onShare ?? (_) async {},
        onPickFile: onPickFile ?? () async => null,
        onRestored: onRestored ?? () async {},
        showMessage: showMessage ?? (_) {},
      );

  testWidgets('Export produces a file and hands it to onShare', (tester) async {
    await (await appDb.open()).insert('contacts', {'name': 'Ali'});
    File? shared;
    await tester.pumpWidget(host(config(onShare: (f) async => shared = f)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();

    expect(shared, isNotNull);
    expect(await shared!.exists(), isTrue);
  });

  testWidgets('Restore-from-file confirm gates the restore', (tester) async {
    // Prepare a real backup file to "pick".
    await (await appDb.open()).insert('contacts', {'name': 'Backup'});
    final file = await service.export();

    var restored = 0;
    await tester.pumpWidget(host(config(
      onPickFile: () async => file,
      onRestored: () async => restored++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-restore-file')));
    await tester.pumpAndSettle();
    // Dialog shown; cancelling does not restore.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(restored, 0);

    // Confirming restores.
    await tester.tap(find.byKey(const Key('backup-restore-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();
    expect(restored, 1);
  });

  testWidgets('a foreign file is refused with a message, no reload', (tester) async {
    final garbage = File(p.join(tmp.path, 'x.txt'));
    await garbage.writeAsString('nope');
    var restored = 0;
    final messages = <String>[];
    await tester.pumpWidget(host(config(
      onPickFile: () async => garbage,
      onRestored: () async => restored++,
      showMessage: messages.add,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-restore-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();

    expect(restored, 0);
    expect(messages.single, "That file isn't a Daftar backup");
  });

  testWidgets('auto-backup list renders dated entries and restores a pick', (
    tester,
  ) async {
    await (await appDb.open()).insert('contacts', {'name': 'Ali'});
    await service.autoBackup(); // one ring entry
    var restored = 0;
    await tester.pumpWidget(host(config(onRestored: () async => restored++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-restore-auto')));
    await tester.pumpAndSettle();
    // A dated tile appears; tap it, then confirm.
    await tester.tap(find.byKey(const Key('auto-backup-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();
    expect(restored, 1);
  });

  testWidgets('the Backup section is hidden when no config is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(controller: ThemeController(SettingsRepository(appDb))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-export')), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/backup_restore_section_test.dart`
Expected: FAIL — `backup_restore_section.dart` missing; `SettingsScreen.backup` undefined.

- [ ] **Step 3: Implement the section** — create `lib/presentation/settings/backup_restore_section.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/backup_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme/theme_context.dart';

/// Everything the Settings "Backup & restore" section needs. Platform hand-off
/// (share sheet / file picker) lives behind [onShare] / [onPickFile] so widget
/// tests never touch platform channels (mirrors the `onSharePdf` seam). A
/// successful restore calls [onRestored] (the app's reload helper); all outcomes
/// surface via [showMessage] (a root-messenger snackbar that survives remount).
class BackupSectionConfig {
  const BackupSectionConfig({
    required this.service,
    required this.onShare,
    required this.onPickFile,
    required this.onRestored,
    required this.showMessage,
  });

  final BackupService service;
  final Future<void> Function(File file) onShare;
  final Future<File?> Function() onPickFile;
  final Future<void> Function() onRestored;
  final void Function(String message) showMessage;
}

/// The Backup & restore Settings section (ADR 0010): Export, Restore-from-file,
/// Restore-from-auto-backup. Full-replace restore is gated by a single confirm
/// dialog (NOT the type-to-confirm reserved for Erase all data).
class BackupRestoreSection extends StatelessWidget {
  const BackupRestoreSection({super.key, required this.config});

  final BackupSectionConfig config;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsBackup,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        SizedBox(height: context.spacing.sm),
        ListTile(
          key: const Key('backup-export'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.ios_share),
          title: Text(l10n.backupExport),
          subtitle: Text(l10n.backupExportHint),
          onTap: () => _export(context, l10n),
        ),
        ListTile(
          key: const Key('backup-restore-file'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore_page),
          title: Text(l10n.backupRestoreFromFile),
          onTap: () => _restoreFromFile(context, l10n),
        ),
        ListTile(
          key: const Key('backup-restore-auto'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: Text(l10n.backupRestoreFromAuto),
          onTap: () => _restoreFromAuto(context, l10n),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, AppLocalizations l10n) async {
    try {
      final file = await config.service.export();
      await config.onShare(file);
      config.showMessage(l10n.exportSuccess);
    } catch (_) {
      config.showMessage(l10n.exportFailed);
    }
  }

  Future<void> _restoreFromFile(BuildContext context, AppLocalizations l10n) async {
    if (!await _confirm(context, l10n)) return;
    final file = await config.onPickFile();
    if (file == null) return; // user cancelled the picker
    await _runRestore(l10n, file);
  }

  Future<void> _restoreFromAuto(BuildContext context, AppLocalizations l10n) async {
    final ring = await config.service.listAutoBackups();
    if (!context.mounted) return;
    if (ring.isEmpty) {
      config.showMessage(l10n.backupNoAutoBackups);
      return;
    }
    final picked = await showDialog<AutoBackupEntry>(
      context: context,
      builder: (context) {
        final fmt = DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .add_jm();
        return AlertDialog(
          title: Text(l10n.backupAutoBackupsTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < ring.length; i++)
                  ListTile(
                    key: Key('auto-backup-$i'),
                    title: Text(fmt.format(ring[i].createdAt)),
                    onTap: () => Navigator.of(context).pop(ring[i]),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    if (picked == null || !context.mounted) return;
    if (!await _confirm(context, l10n)) return;
    await _runRestore(l10n, picked.file);
  }

  Future<bool> _confirm(BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreTitle),
        content: Text(l10n.backupRestoreMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('backup-restore-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.backupRestoreConfirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _runRestore(AppLocalizations l10n, File file) async {
    final RestoreResult result;
    try {
      result = await config.service.restore(file);
    } catch (_) {
      config.showMessage(l10n.restoreFailed);
      return;
    }
    switch (result) {
      case RestoreResult.success:
        await config.onRestored();
        config.showMessage(l10n.restoreSuccess);
      case RestoreResult.notABackup:
        config.showMessage(l10n.restoreNotABackup);
      case RestoreResult.newerVersion:
        config.showMessage(l10n.restoreNewerVersion);
      case RestoreResult.failure:
        config.showMessage(l10n.restoreFailed);
    }
  }
}
```

> Note: `_restoreFromAuto` opens the confirm dialog AFTER the picker dialog closes. Both use the same `backup-restore-confirm` key, so the auto-backup test taps the picker tile then the confirm button. The `backup-restore-file` flow shows the confirm dialog FIRST, then the (injected) picker — matching "warn before it happens".

- [ ] **Step 4: Wire into `SettingsScreen`** — in `lib/presentation/settings/settings_screen.dart`:

Add the import and field:

```dart
import 'backup_restore_section.dart';
```

```dart
  /// Backup & restore (#26). When supplied, the Backup section renders; null in
  /// focused theme tests, which then hide it.
  final BackupSectionConfig? backup;
```

Add `this.backup` to the constructor. Then render it — insert BEFORE the `if (onEraseAllData != null)` block inside the `ListView`'s children (so Backup sits above the destructive Data/Erase section):

```dart
            if (backup != null) ...[
              SizedBox(height: context.spacing.xl),
              BackupRestoreSection(config: backup!),
            ],
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/presentation/backup_restore_section_test.dart`
Expected: PASS (all five tests). Also run `flutter test test/presentation/settings_screen_test.dart test/presentation/settings_erase_test.dart` — unaffected.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/settings/backup_restore_section.dart lib/presentation/settings/settings_screen.dart test/presentation/backup_restore_section_test.dart
git commit -m "feat: Backup & restore Settings section with export/restore/auto-backup (#26)"
```

---

## Task 12: Production wiring — deps, `HomeScreen` thread-through, `main.dart`

Add the platform packages and wire the real app: create one `BackupDirtyFlag` and one `BackupService`, inject the flag into every repository, build the `share_plus`/`file_picker` callbacks, thread the `BackupSectionConfig` from `app.dart` through `HomeScreen` to `SettingsScreen`.

**Files:**
- Modify: `pubspec.yaml`, `lib/presentation/home/home_screen.dart`, `lib/main.dart`
- (Task 9's `app.dart` already builds `_backupConfig` and passes `backup: _backupConfig` to `HomeScreen`; remove any temporary placeholder now.)

**Interfaces:**
- `HomeScreen` gains `final BackupSectionConfig? backup;`, passed into the `SettingsScreen(...)` it builds in `_onMenuAction`.

- [ ] **Step 1: Add dependencies**

Run: `flutter pub add share_plus file_picker`
Expected: `pubspec.yaml` gains `share_plus:` and `file_picker:` under dependencies; `flutter pub get` resolves. (These only hand off to the OS — no network, consistent with ADR 0008.)

- [ ] **Step 2: Thread `backup` through `HomeScreen`** — in `lib/presentation/home/home_screen.dart`:

Add the import:

```dart
import '../settings/backup_restore_section.dart';
```

Add the field + constructor param (next to `onEraseAllData`):

```dart
    this.backup,
```
```dart
  /// Backup & restore config (#26), threaded to Settings. Null in focused tests.
  final BackupSectionConfig? backup;
```

Pass it into the `SettingsScreen(...)` built in `_onMenuAction`:

```dart
            builder: (_) => SettingsScreen(
              controller: widget.themeController!,
              profileController: widget.profileController,
              currencyController: widget.currencyController,
              localeController: widget.localeController,
              onEraseAllData: widget.onEraseAllData,
              backup: widget.backup,
            ),
```

- [ ] **Step 3: Wire `main.dart`** — replace the body of `main()` so the dirty flag reaches every repo and the service + platform callbacks reach the app:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/backup_dirty_flag.dart';
import 'data/backup_service.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'data/profile_repository.dart';
import 'data/settings_repository.dart';
import 'presentation/currency/currency_controller.dart';
import 'presentation/locale/locale_controller.dart';
import 'presentation/profile/profile_controller.dart';
import 'presentation/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase();
  final dirtyFlag = BackupDirtyFlag();
  final settingsRepository = SettingsRepository(appDatabase, dirty: dirtyFlag);
  final contactRepository = ContactRepository(appDatabase, dirty: dirtyFlag);
  final entryRepository = EntryRepository(appDatabase, dirty: dirtyFlag);
  final themeController = ThemeController(settingsRepository);
  final profileController =
      ProfileController(ProfileRepository(appDatabase, dirty: dirtyFlag));
  final currencyController = CurrencyController(settingsRepository);
  final localeController = LocaleController(settingsRepository);
  await themeController.load();
  await profileController.load();
  await currencyController.load();
  await localeController.load();

  // App-private backups directory (a sibling of the database file — no
  // path_provider needed, and it stays inside the app sandbox).
  final backupsDir = Directory(
      p.join(await appDatabase.factory.getDatabasesPath(), 'backups'));
  final backupService =
      BackupService(appDatabase: appDatabase, backupsDir: backupsDir);

  runApp(DebtLedgerApp(
    appDatabase: appDatabase,
    contactRepository: contactRepository,
    entryRepository: entryRepository,
    themeController: themeController,
    profileController: profileController,
    currencyController: currencyController,
    localeController: localeController,
    backupService: backupService,
    dirtyFlag: dirtyFlag,
    onShareBackup: (file) =>
        SharePlus.instance.share(ShareParams(files: [XFile(file.path)])),
    onPickBackupFile: () async {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      return path == null ? null : File(path);
    },
  ));
}
```

> `share_plus` API note: recent versions expose `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`. If `flutter pub add` resolved an older major that only has `Share.shareXFiles([XFile(path)])`, use that instead — either satisfies the injected `Future<void> Function(File)` seam. Confirm the exact symbol against the resolved version (use context7 / `share_plus` docs).

- [ ] **Step 4: Analyze + full test suite**

Run: `flutter analyze` then `flutter test`
Expected: analyze clean; ALL tests pass. Fix any signature drift (e.g. a stray temporary placeholder from Task 9).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/presentation/home/home_screen.dart lib/app.dart
git commit -m "feat: wire BackupService, dirty flag, share_plus/file_picker into the app (#26)"
```

---

## Task 13: Verify end-to-end + finalize docs

**Files:**
- Modify (if needed): `CONTEXT.md` (already updated with glossary), `docs/adr/0010-backup-file-format-and-restore.md` (already present).

- [ ] **Step 1: Full green build**

Run: `flutter analyze && flutter test`
Expected: no analyzer issues; every test passes.

- [ ] **Step 2: Manual smoke on a device/emulator (use the `verify` / `run` skill)**

Drive the real flow: Settings → Export backup → share sheet appears; add a contact; background the app; foreground; Settings → Restore from auto-backup → a dated entry exists; restore it → the added contact is gone (data replaced) and a success snackbar shows. Restore a foreign file → refused message, data intact. If a device isn't available, note this step as manually deferred rather than claiming it passed.

- [ ] **Step 3: Confirm Android build (share_plus/file_picker platform channels)**

Run: `flutter build apk --debug`
Expected: builds. (share_plus bundles its own FileProvider; file_picker needs no manifest change for basic pick. If the build flags a missing config, follow the package's Android setup — no network permission is added.)

- [ ] **Step 4: Commit any final doc touch-ups**

```bash
git add CONTEXT.md docs/adr/0010-backup-file-format-and-restore.md
git commit -m "docs: finalize Backup/restore glossary + ADR 0010 (#26)"
```

- [ ] **Step 5: Open the PR** (per finishing-a-development-branch)

```bash
git push -u origin feat/backup-restore-slice-13
gh pr create --fill --base main
```

---

## Self-Review

**Spec coverage (PRD user stories → tasks):**
- Export whole ledger to a file (1,3) → Task 2. Share sheet (2) → Task 12 (`onShareBackup`). Dated name (3) → Task 2 (`daftar-backup-<stamp>.db`).
- Restore recovers everything (4,5,6,7) → Task 4 round-trip (contacts, entries, per-currency balances via amounts, settings, profile — all ride the file copy).
- Warn before replace (8) → Task 11 confirm dialog. Auto-save before restore (9) → Task 4 (`restore` calls `autoBackup` first) + Task 11.
- Keep automatic on-device backup (10) → Tasks 3 + 8. Undo a wrong restore from auto-backup (11,12) → Tasks 3 + 11 (dated list).
- Refuse non-Daftar file (13) → Tasks 5 + 11. Refuse newer version (14) → Tasks 6 + 11. Older backup still opens (15) → Task 4 (reopen runs migrations forward; documented, covered by round-trip's success path).
- Restored data appears immediately (16) → Task 9 reload + key-bump remount. Not-encrypted hint (17) → Task 10 `backupExportHint` + Task 11. Keep only last few (18) → Task 3 ring. Skip when unchanged (19) → Tasks 7 + 8 dirty flag.
- Success/failure messages (20) → Task 11 `showMessage`. Controls in Settings (21) → Task 11. Arabic + RTL (22) → Task 10. Foreign/corrupt leaves ledger untouched (23) → Task 5.

**Implementation decisions → tasks:** `BackupService` (2–6); whole-file copy + close→copy→reopen (2); no encryption (10/11 hint only); validated full-replace (4–6); post-swap reload helper reused by erase (9); auto-backup on background if changed (7,8); Settings section (11); platform seams `onShareBackup`/`onPickBackupFile` (9,12); deps `share_plus`+`file_picker` (12); no schema change (honored — no migration touched).

**Testing decisions → tasks:** BackupService against real temp-file DBs (2–6); reject foreign/corrupt (5); refuse newer schema (6); ring rotation (3); Settings widget with injected callbacks (11); controller reload asserted via the erase integration (9) and restore round-trip (4).

**Placeholder scan:** One deliberate forward-reference — Task 9's `app.dart` imports `BackupSectionConfig`/`HomeScreen(backup:)` which land in Tasks 10–11; the note tells the executor to either implement 10–11 immediately after or stub `_backupConfig` to `null` temporarily. No `TODO`/`TBD` remain in shipped code.

**Type consistency:** `RestoreResult{success,notABackup,newerVersion,failure}`, `AutoBackupEntry{file,createdAt}`, `BackupDirtyFlag{isDirty,mark,reset}`, `BackupService(appDatabase,backupsDir,clock,retain)` with `export()→File`, `autoBackup()→File`, `listAutoBackups()→List<AutoBackupEntry>`, `restore(File)→RestoreResult`, `BackupSectionConfig{service,onShare,onPickFile,onRestored,showMessage}` — used identically across Tasks 2–12. Repo constructors all take `{BackupDirtyFlag? dirty}`.

**Out of scope (confirmed absent):** no cloud/network/accounts; no encryption/passphrase; no merge; Erase-all internals are #25 (only its reload path is refactored to reuse the shared helper); no user-configurable N; no scheduled auto-backup beyond on-background; no newer-version restore; Android-only.
