import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/contact_screen.dart';
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

  Widget host(Contact c) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ContactScreen(contact: c, repository: entries, currency: Currency.sar),
      );

  testWidgets('reset settles the balance by adding one settle entry', (tester) async {
    // Persist the contact first: entries carry a FK to contacts.id.
    final c = await contacts.add(const Contact(name: 'Ali'));
    await entries.add(Entry(contactId: c.id!, amount: 300, direction: Direction.owedToMe, currency: Currency.sar, createdAt: DateTime(2026, 7, 1)));
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset account'));
    await tester.pumpAndSettle();
    // Confirm dialog names the amount, then confirm.
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    final all = await entries.listByContact(c.id!);
    expect(all.length, 2); // original + settle
    expect(find.text('Settled'), findsWidgets); // balance header now settled
  });

  testWidgets('reset item is disabled when already settled', (tester) async {
    final c = await contacts.add(const Contact(name: 'Ali')); // no entries → settled
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    // The menu item is PopupMenuItem<_ContactMenuAction> (a private enum), so
    // find by its key rather than the generic PopupMenuItem type.
    final item = tester.widget<PopupMenuItem>(find.byKey(const Key('reset-menu-item')));
    expect(item.enabled, isFalse);
  });
}
