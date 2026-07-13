import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/period.dart';
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

  test('update changes a stored Entry in place', () async {
    final contact = await contacts.add(const Contact(name: 'Edit Me'));
    final saved = await entries.add(sample(contact.id!, amount: 100));

    await entries.update(
      saved.copyWith(amount: 250, direction: Direction.owedByMe),
    );

    final stored = (await entries.listByContact(contact.id!)).single;
    expect(stored.id, saved.id);
    expect(stored.amount, 250);
    expect(stored.direction, Direction.owedByMe);
  });

  test('delete removes only the given Entry', () async {
    final contact = await contacts.add(const Contact(name: 'Two Rows'));
    final keep = await entries.add(sample(contact.id!, amount: 10));
    final drop = await entries.add(sample(contact.id!, amount: 20));

    await entries.delete(drop.id!);

    final remaining = await entries.listByContact(contact.id!);
    expect(remaining.map((e) => e.id), [keep.id]);
  });

  Entry inCurrency(int contactId, Currency currency, DateTime when) => Entry(
    contactId: contactId,
    amount: 100,
    direction: Direction.owedToMe,
    currency: currency,
    createdAt: when,
  );

  test('lastActivityByCurrency returns each contact newest entry in the lens',
      () async {
    final a = await contacts.add(const Contact(name: 'A'));
    final b = await contacts.add(const Contact(name: 'B'));
    await entries.add(inCurrency(a.id!, Currency.sar, DateTime(2026, 7, 1)));
    await entries.add(inCurrency(a.id!, Currency.sar, DateTime(2026, 7, 10)));
    await entries.add(inCurrency(a.id!, Currency.yer, DateTime(2026, 7, 12)));
    await entries.add(inCurrency(b.id!, Currency.yer, DateTime(2026, 6, 1)));

    expect(await entries.lastActivityByCurrency(Currency.sar), {
      a.id!: DateTime(2026, 7, 10), // newest SAR only; B has no SAR entry
    });
    expect(await entries.lastActivityByCurrency(Currency.yer), {
      a.id!: DateTime(2026, 7, 12),
      b.id!: DateTime(2026, 6, 1),
    });
  });

  test('entriesInRange returns only the lens currency within [start, end)',
      () async {
    final a = await contacts.add(const Contact(name: 'A'));
    final june = await entries.add(
      inCurrency(a.id!, Currency.sar, DateTime(2026, 6, 30, 23, 59)),
    );
    final julyStart = await entries.add(
      inCurrency(a.id!, Currency.sar, DateTime(2026, 7, 1)), // start inclusive
    );
    final julyMid = await entries.add(
      inCurrency(a.id!, Currency.sar, DateTime(2026, 7, 20)),
    );
    await entries.add(
      inCurrency(a.id!, Currency.sar, DateTime(2026, 8, 1)), // end exclusive
    );
    await entries.add(
      inCurrency(a.id!, Currency.yer, DateTime(2026, 7, 10)), // other currency
    );

    final range = DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1));
    final inJuly = await entries.entriesInRange(Currency.sar, range);

    expect(
      inJuly.map((e) => e.id).toSet(),
      {julyStart.id, julyMid.id},
    );
    expect(inJuly.map((e) => e.id), isNot(contains(june.id)));
  });

  test('the all-time balance is unaffected by any period query', () async {
    final a = await contacts.add(const Contact(name: 'A'));
    await entries.add(inCurrency(a.id!, Currency.sar, DateTime(2020, 1, 1)));
    await entries.add(inCurrency(a.id!, Currency.sar, DateTime(2026, 7, 20)));

    final allTime = await entries.balancesByCurrency(Currency.sar);
    // Query a narrow window (only the 2026 entry falls inside).
    await entries.entriesInRange(
      Currency.sar,
      DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
    );
    final afterWindowQuery = await entries.balancesByCurrency(Currency.sar);

    // Balance stays the full all-time net (200 = 100 + 100), never windowed.
    expect(allTime[a.id!]!.signed, 200);
    expect(afterWindowQuery[a.id!]!.signed, allTime[a.id!]!.signed);
  });
}
