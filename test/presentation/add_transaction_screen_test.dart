import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/entries/add_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase appDb;
  late ContactRepository contacts;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });
  tearDown(() => appDb.close());

  Widget host() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddTransactionScreen(
          contactRepository: contacts, entryRepository: entries, currency: Currency.sar),
      );

  testWidgets('search, pick a contact, save books an entry in the lens', (tester) async {
    final ali = await contacts.add(const Contact(name: 'Ali'));
    await contacts.add(const Contact(name: 'Sara'));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tx-contact-search')), 'Ali');
    await tester.pumpAndSettle();
    // Target the result tile: find.text('Ali') would also match the search
    // field's EditableText (its content is 'Ali').
    await tester.tap(find.widgetWithText(ListTile, 'Ali'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-amount')), '150');
    await tester.tap(find.byKey(const Key('tx-save')));
    await tester.pumpAndSettle();

    final booked = await entries.listByContact(ali.id!);
    expect(booked.single.amount, 150);
    expect(booked.single.currency, Currency.sar);
  });

  testWidgets('a no-match name offers to create the contact', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tx-contact-search')), 'Zed');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tx-create-contact')), findsOneWidget);
  });
}
