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
