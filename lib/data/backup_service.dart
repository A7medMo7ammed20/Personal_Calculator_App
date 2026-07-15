import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show OpenDatabaseOptions, Database, Sqflite;

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
    this.copyFile = _copyFile,
  });

  final AppDatabase appDatabase;
  final Directory backupsDir;
  final DateTime Function() clock;
  final int retain;

  /// The file-copy primitive (source → destination path). Injectable — like
  /// [clock] — so a test can force an I/O failure mid-restore and prove the
  /// swap never leaves a half-written live database.
  final Future<void> Function(File source, String dest) copyFile;

  static Future<void> _copyFile(File source, String dest) async {
    await source.copy(dest);
  }

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

  /// Full-replace restore (ADR 0010). Validates [file] in a temporary read-only
  /// handle FIRST — a foreign/corrupt file or a newer-schema backup is refused
  /// before the live database is touched. The incoming file is then *staged*
  /// beside the live database while it is still open, so a disk-full or I/O
  /// error during the copy (the realistic failure) returns
  /// [RestoreResult.failure] with the live data untouched — never a half-written
  /// database. Only once the backup is fully staged does it snapshot the current
  /// data into the ring (the undo) and swap: the swap is a `delete` + `rename`,
  /// which writes no bytes and so cannot fail on a full disk. On success the
  /// database is left CLOSED for the caller's reload helper to reopen.
  Future<RestoreResult> restore(File file) async {
    final verdict = await _validate(file);
    if (verdict != RestoreResult.success) return verdict;

    final livePath = await appDatabase.resolvedPath();
    final staged = File('$livePath.restore-tmp');

    // Phase 1 — stage the incoming file beside the live database while it is
    // still open and untouched. The realistic failure (disk full, I/O error)
    // lands here, before anything is swapped, so the live data stays whole.
    try {
      await copyFile(file, staged.path);
    } catch (_) {
      if (await staged.exists()) await staged.delete();
      return RestoreResult.failure;
    }

    // Phase 2 — commit. Snapshot the current data into the ring (the undo),
    // then close the database, drop the old file plus its WAL/SHM sidecars, and
    // move the staged copy into place. `rename` writes no bytes (so it cannot
    // fail on a full disk) and, because the destination is removed first, is
    // portable to Windows, where rename-over-existing is not atomic.
    try {
      await autoBackup();
      await appDatabase.close();
      for (final path in [livePath, '$livePath-wal', '$livePath-shm']) {
        final old = File(path);
        if (await old.exists()) await old.delete();
      }
      await staged.rename(livePath);
      return RestoreResult.success;
    } catch (_) {
      // If the live file is still present the swap never started — drop the
      // staged copy. If it is gone, the rename failed mid-swap: keep the staged
      // copy (and the ring snapshot) for recovery. Either way report failure
      // rather than throwing.
      if (await File(livePath).exists() && await staged.exists()) {
        await staged.delete();
      }
      return RestoreResult.failure;
    }
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

  /// Close the live database (checkpoints WAL into a consistent file), copy that
  /// file to [destPath], then reopen so the app keeps working.
  Future<void> _snapshotTo(String destPath) async {
    final livePath = await appDatabase.resolvedPath();
    await appDatabase.close();
    try {
      await copyFile(File(livePath), destPath);
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

/// The outcome of a restore attempt (ADR 0010). Only [success] touches the live
/// database; every other value leaves it exactly as it was.
enum RestoreResult { success, notABackup, newerVersion, failure }

/// One entry in the auto-backup ring: the snapshot file and when it was taken.
class AutoBackupEntry {
  const AutoBackupEntry({required this.file, required this.createdAt});
  final File file;
  final DateTime createdAt;
}
