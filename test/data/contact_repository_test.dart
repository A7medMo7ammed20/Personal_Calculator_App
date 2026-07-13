import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ContactRepository repo;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = ContactRepository(appDb);
  });

  tearDown(() => appDb.close());

  test('add assigns an id and returns the stored Contact', () async {
    final saved = await repo.add(const Contact(name: 'Sami', phone: '0555'));

    expect(saved.id, isNotNull);
    expect(saved.name, 'Sami');
    expect(saved.phone, '0555');
  });

  test('add accepts a name-only Contact (phone null)', () async {
    final saved = await repo.add(const Contact(name: 'Layla'));

    expect(saved.id, isNotNull);
    expect(saved.phone, isNull);
  });

  test('list returns all saved contacts, newest first', () async {
    final first = await repo.add(const Contact(name: 'First'));
    final second = await repo.add(const Contact(name: 'Second'));

    final all = await repo.list();

    expect(all.map((c) => c.id), [second.id, first.id]);
    expect(all.map((c) => c.name), ['Second', 'First']);
  });

  test('list is empty on a fresh database', () async {
    expect(await repo.list(), isEmpty);
  });
}
