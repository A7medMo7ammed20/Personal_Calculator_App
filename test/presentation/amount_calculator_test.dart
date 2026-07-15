import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/entries/add_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late EntryRepository entries;
  late Contact contact;

  setUp(() async {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    entries = EntryRepository(appDb);
    contact = await ContactRepository(appDb).add(const Contact(name: 'Sami'));
  });

  tearDown(() => appDb.close());

  Future<void> openCalculator(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('entry-amount-calc')));
    await tester.pumpAndSettle();
  }

  Future<void> tapKeys(WidgetTester tester, List<String> keys) async {
    for (final k in keys) {
      await tester.tap(find.byKey(Key('calc-$k')));
      await tester.pump();
    }
  }

  testWidgets('computes an amount and places it in the amount box',
      (tester) async {
    await tester.pumpWidget(_wrap(AddEntryScreen(
      contactId: contact.id!,
      repository: entries,
      currency: Currency.sar,
    )));
    await tester.pumpAndSettle();

    await openCalculator(tester);
    // 200 + 50 -> 250
    await tapKeys(tester, [
      'key-2', 'key-0', 'key-0', 'op-add', 'key-5', 'key-0',
    ]);
    expect(find.byKey(const Key('calc-expression')), findsOneWidget);
    expect(find.text('200 + 50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calc-done')));
    await tester.pumpAndSettle();

    // The computed result is now in the amount box.
    expect(find.text('250'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = (await entries.listByContact(contact.id!)).single;
    expect(stored.amount, 250);
  });

  testWidgets('blocks committing a divide-by-zero', (tester) async {
    await tester.pumpWidget(_wrap(AddEntryScreen(
      contactId: contact.id!,
      repository: entries,
      currency: Currency.sar,
    )));
    await tester.pumpAndSettle();

    await openCalculator(tester);
    await tapKeys(tester, ['key-5', 'op-divide', 'key-0']);

    expect(find.text('Cannot divide by zero'), findsOneWidget);
    final done = tester.widget<FilledButton>(find.byKey(const Key('calc-done')));
    expect(done.onPressed, isNull); // disabled
  });

  testWidgets('seeds from the current amount when editing', (tester) async {
    final saved = await entries.add(Entry(
      contactId: contact.id!,
      amount: 500,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 7, 13, 10),
    ));

    await tester.pumpWidget(_wrap(AddEntryScreen(
      contactId: contact.id!,
      repository: entries,
      currency: Currency.sar,
      existing: saved,
    )));
    await tester.pumpAndSettle();

    await openCalculator(tester);
    // Seeded with 500; add 50 -> 550.
    expect(find.text('500'), findsWidgets);
    await tapKeys(tester, ['op-add', 'key-5', 'key-0']);
    expect(find.text('500 + 50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calc-done')));
    await tester.pumpAndSettle();

    expect(find.text('550'), findsOneWidget);
  });
}
