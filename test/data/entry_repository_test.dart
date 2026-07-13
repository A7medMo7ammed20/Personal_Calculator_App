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
  late ContactRepository contacts;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });

  tearDown(() => appDb.close());

  Entry sample(
    int contactId, {
    Direction direction = Direction.owedToMe,
    double amount = 100,
    String? description,
    DateTime? createdAt,
  }) => Entry(
    contactId: contactId,
    amount: amount,
    direction: direction,
    currency: Currency.sar,
    createdAt: createdAt ?? DateTime(2026, 7, 13, 10),
    description: description,
  );

  test('add assigns an id and returns the stored Entry', () async {
    final contact = await contacts.add(const Contact(name: 'Sami'));

    final saved = await entries.add(sample(contact.id!, description: 'lunch'));

    expect(saved.id, isNotNull);
    expect(saved.contactId, contact.id);
    expect(saved.amount, 100);
    expect(saved.direction, Direction.owedToMe);
    expect(saved.description, 'lunch');
  });

  test('add accepts an Entry with no description', () async {
    final contact = await contacts.add(const Contact(name: 'Layla'));

    final saved = await entries.add(sample(contact.id!));

    expect(saved.id, isNotNull);
    expect(saved.description, isNull);
  });

  test('round-trips direction, currency and timestamp through the database',
      () async {
    final contact = await contacts.add(const Contact(name: 'Nora'));
    final when = DateTime(2026, 1, 2, 9, 45);
    await entries.add(sample(
      contact.id!,
      direction: Direction.owedByMe,
      amount: 42.5,
      createdAt: when,
    ));

    final stored = (await entries.listByContact(contact.id!)).single;

    expect(stored.direction, Direction.owedByMe);
    expect(stored.currency, Currency.sar);
    expect(stored.amount, 42.5);
    expect(stored.createdAt, when);
  });

  test('listByContact returns only that contact, newest first', () async {
    final a = await contacts.add(const Contact(name: 'A'));
    final b = await contacts.add(const Contact(name: 'B'));

    final older = await entries.add(
      sample(a.id!, createdAt: DateTime(2026, 7, 1)),
    );
    final newer = await entries.add(
      sample(a.id!, createdAt: DateTime(2026, 7, 10)),
    );
    await entries.add(sample(b.id!));

    final forA = await entries.listByContact(a.id!);

    expect(forA.map((e) => e.id), [newer.id, older.id]);
  });

  test('deleting a Contact cascade-deletes its Entries', () async {
    final contact = await contacts.add(const Contact(name: 'Doomed'));
    await entries.add(sample(contact.id!));
    await entries.add(sample(contact.id!, direction: Direction.owedByMe));

    final db = await appDb.open();
    await db.delete(
      ContactRepository.table,
      where: 'id = ?',
      whereArgs: [contact.id],
    );

    expect(await entries.listByContact(contact.id!), isEmpty);
  });
}
