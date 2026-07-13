import 'package:debt_ledger/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
