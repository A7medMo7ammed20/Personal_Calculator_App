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
}
