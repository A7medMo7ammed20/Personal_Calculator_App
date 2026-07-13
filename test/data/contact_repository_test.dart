import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
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

  test('update changes a stored Contact in place', () async {
    final contacts = ContactRepository(appDb);
    final saved = await contacts.add(const Contact(name: 'Old', phone: '111'));

    await contacts.update(saved.copyWith(name: 'New', phone: '222'));

    final stored = (await contacts.list()).single;
    expect(stored.id, saved.id);
    expect(stored.name, 'New');
    expect(stored.phone, '222');
  });

  test('delete removes the Contact and cascade-deletes its Entries', () async {
    final contacts = ContactRepository(appDb);
    final entries = EntryRepository(appDb);
    final contact = await contacts.add(const Contact(name: 'Doomed'));
    await entries.add(Entry(
      contactId: contact.id!,
      amount: 100,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 7, 13),
    ));

    await contacts.delete(contact.id!);

    expect(await contacts.list(), isEmpty);
    expect(await entries.listByContact(contact.id!), isEmpty);
  });

  test('entryCount counts entries across all currencies', () async {
    final contacts = ContactRepository(appDb);
    final entries = EntryRepository(appDb);
    final contact = await contacts.add(const Contact(name: 'Busy'));
    for (final currency in [Currency.sar, Currency.yer, Currency.sar]) {
      await entries.add(Entry(
        contactId: contact.id!,
        amount: 10,
        direction: Direction.owedToMe,
        currency: currency,
        createdAt: DateTime(2026, 7, 13),
      ));
    }

    expect(await contacts.entryCount(contact.id!), 3);
  });
}
