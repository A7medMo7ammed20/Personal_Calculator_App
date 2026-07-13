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
    required Currency currency,
    Direction direction = Direction.owedToMe,
    double amount = 100,
  }) => Entry(
    contactId: contactId,
    amount: amount,
    direction: direction,
    currency: currency,
    createdAt: DateTime(2026, 7, 13, 10),
  );

  test('listByContact filters to the given currency', () async {
    final c = await contacts.add(const Contact(name: 'Sami'));
    await entries.add(sample(c.id!, currency: Currency.sar, amount: 100));
    await entries.add(sample(c.id!, currency: Currency.yer, amount: 999));

    final sar = await entries.listByContact(c.id!, currency: Currency.sar);

    expect(sar, hasLength(1));
    expect(sar.single.currency, Currency.sar);
    expect(sar.single.amount, 100);
  });

  test('balancesByCurrency nets each contact within one currency', () async {
    final a = await contacts.add(const Contact(name: 'A'));
    final b = await contacts.add(const Contact(name: 'B'));
    await entries.add(sample(a.id!, currency: Currency.sar, amount: 100));
    await entries.add(sample(a.id!,
        currency: Currency.sar, direction: Direction.owedByMe, amount: 40));
    await entries.add(sample(b.id!,
        currency: Currency.sar, direction: Direction.owedByMe, amount: 25));

    final balances = await entries.balancesByCurrency(Currency.sar);

    expect(balances[a.id]!.signed, 60); // 100 - 40
    expect(balances[b.id]!.signed, -25);
  });

  test('SAR and YER aggregate independently and never combine', () async {
    final c = await contacts.add(const Contact(name: 'Mixed'));
    await entries.add(sample(c.id!, currency: Currency.sar, amount: 100));
    await entries.add(sample(c.id!, currency: Currency.yer, amount: 300));

    final sar = await entries.balancesByCurrency(Currency.sar);
    final yer = await entries.balancesByCurrency(Currency.yer);

    expect(sar[c.id]!.signed, 100);
    expect(yer[c.id]!.signed, 300);
    // The two currencies are never summed into one 400 figure.
    expect(sar[c.id]!.signed + yer[c.id]!.signed, 400);
    expect(sar.containsKey(c.id), isTrue);
    expect(yer[c.id]!.signed, isNot(400));
  });

  test('balancesByCurrency omits contacts with no entries in that currency',
      () async {
    final c = await contacts.add(const Contact(name: 'YerOnly'));
    await entries.add(sample(c.id!, currency: Currency.yer, amount: 300));

    final sar = await entries.balancesByCurrency(Currency.sar);

    expect(sar.containsKey(c.id), isFalse);
  });
}
