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
}
