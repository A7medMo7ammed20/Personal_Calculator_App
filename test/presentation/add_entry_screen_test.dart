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

  testWidgets('editing an existing entry prefills and updates in place',
      (tester) async {
    final saved = await entries.add(Entry(
      contactId: contact.id!,
      amount: 100,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 7, 13, 10),
      description: 'lunch',
    ));

    await tester.pumpWidget(_wrap(AddEntryScreen(
      contactId: contact.id!,
      repository: entries,
      currency: Currency.sar,
      existing: saved,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // amount prefilled
    expect(find.text('lunch'), findsOneWidget); // description prefilled

    await tester.enterText(find.byType(TextFormField).first, '175');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = (await entries.listByContact(contact.id!)).single;
    expect(stored.id, saved.id); // same row, updated
    expect(stored.amount, 175);
  });
}
