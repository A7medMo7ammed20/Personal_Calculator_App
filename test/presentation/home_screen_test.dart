import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/home/home_screen.dart';
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
  late ContactRepository contacts;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });

  tearDown(() => appDb.close());

  testWidgets('long-press delete warns a contact with the entry count',
      (tester) async {
    final contact = await contacts.add(const Contact(name: 'Sami'));
    await entries.add(Entry(
      contactId: contact.id!, amount: 10, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 7, 13),
    ));
    await entries.add(Entry(
      contactId: contact.id!, amount: 20, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 7, 14),
    ));

    await tester.pumpWidget(_wrap(
      HomeScreen(repository: contacts, entryRepository: entries),
    ));
    await tester.pumpAndSettle();

    // Long-press the contact tile → floating Edit/Delete buttons appear.
    await tester.longPress(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Delete contact?'), findsOneWidget);
    expect(find.textContaining('2 entries'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sami'), findsNothing);
    expect(await contacts.list(), isEmpty);
  });

  testWidgets('search filters the contact list by name in real time',
      (tester) async {
    await contacts.add(const Contact(name: 'Ali'));
    await contacts.add(const Contact(name: 'Sara'));

    await tester.pumpWidget(_wrap(
      HomeScreen(repository: contacts, entryRepository: entries),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsNothing);
  });

  testWidgets('search by digits matches a contact phone', (tester) async {
    await contacts.add(const Contact(name: 'Ali', phone: '055 512 3456'));
    await contacts.add(const Contact(name: 'Sara', phone: '050 999 0000'));

    await tester.pumpWidget(_wrap(
      HomeScreen(repository: contacts, entryRepository: entries),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0555123');
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsNothing);
  });
}
