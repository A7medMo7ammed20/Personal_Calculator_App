import 'dart:io';

import 'package:debt_ledger/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('opens a versioned in-memory database', () async {
    final appDb = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDb.close);

    final db = await appDb.open();

    expect(await db.getVersion(), AppDatabase.schemaVersion);
  });

  test('open is idempotent and returns the same handle', () async {
    final appDb = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDb.close);

    final first = await appDb.open();
    final second = await appDb.open();

    expect(identical(first, second), isTrue);
  });

  test('v5 fresh install has the archived column defaulting to 0', () async {
    final appDb = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDb.close);
    final db = await appDb.open();
    final id = await db.insert('contacts', {'name': 'X'});
    final row = (await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(row['archived'], 0);
    expect(await db.getVersion(), 5);
  });

  test('upgrading from v4 adds archived defaulting to 0', () async {
    // A real temp file — `:memory:` opens a fresh DB each time, so the v4 write
    // must persist to disk for the v5 reopen to migrate it.
    final dir = await Directory.systemTemp.createTemp('daftar_v4_');
    final path = p.join(dir.path, 'legacy.db');
    addTearDown(() => dir.delete(recursive: true));

    final v4 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT)',
          );
        },
      ),
    );
    await v4.insert('contacts', {'name': 'Legacy'});
    await v4.close();

    final appDb = AppDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(appDb.close);
    final db = await appDb.open();
    final row = (await db.query(
      'contacts',
      where: 'name = ?',
      whereArgs: ['Legacy'],
    )).single;
    expect(row['archived'], 0);
    expect(await db.getVersion(), 5);
  });
}
