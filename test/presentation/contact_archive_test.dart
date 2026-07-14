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
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });
  tearDown(() => appDb.close());

  // ContactScreen wired WITH the contact repository → the Archive overflow item
  // appears and auto-unarchive is available.
  Widget host(Contact c) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ContactScreen(
      contact: c,
      repository: entries,
      currency: Currency.sar,
      contactRepository: contacts,
    ),
  );

  Future<Contact> unsettled() async {
    final c = await contacts.add(const Contact(name: 'Ali'));
    await entries.add(
      Entry(
        contactId: c.id!,
        amount: 300,
        direction: Direction.owedToMe,
        currency: Currency.sar,
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    return c;
  }

  testWidgets('archiving an unsettled contact surfaces the outstanding amount', (
    tester,
  ) async {
    final c = await unsettled();
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    // The soft-gate dialog names the outstanding balance before archiving.
    // ('still owes you' is dialog-only; the ContactScreen balance header also
    // reads 'owes you', so match the dialog-unique phrasing.)
    expect(find.textContaining('still owes you'), findsOneWidget);
    expect(find.textContaining('Archive anyway'), findsOneWidget);
  });

  testWidgets('confirming archive sets archived and returns to the caller', (
    tester,
  ) async {
    final c = await unsettled();
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Archive'));
    await tester.pumpAndSettle();

    expect((await contacts.listArchived()).map((x) => x.id), [c.id]);
    expect(await contacts.list(), isEmpty);
  });

  testWidgets('a settled contact shows a plain archive confirm (no amount)', (
    tester,
  ) async {
    final c = await contacts.add(const Contact(name: 'Ali')); // no entries
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive contact?'), findsOneWidget);
    expect(find.textContaining('set aside'), findsOneWidget);
    expect(find.textContaining('owes you'), findsNothing);
  });

  testWidgets('adding an entry to an archived contact auto-unarchives it', (
    tester,
  ) async {
    final c = await contacts.add(const Contact(name: 'Ali'));
    await contacts.setArchived(c.id!, archived: true);
    // Re-read so the screen carries the archived flag (mirrors the Archived
    // view, which lists via listArchived()).
    final archived = (await contacts.listArchived()).single;
    await tester.pumpWidget(host(archived));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add)); // the add-entry FAB
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Booking activity brought the contact back to the active list.
    expect(await contacts.listArchived(), isEmpty);
    expect((await contacts.list()).map((x) => x.id), [c.id]);
  });
}
