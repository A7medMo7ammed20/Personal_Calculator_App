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
