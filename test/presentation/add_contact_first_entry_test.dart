import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/add_contact_screen.dart';
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
        home: AddContactScreen(
          repository: contacts, entryRepository: entries, currency: Currency.sar),
      );

  Future<void> tapSave(WidgetTester tester) async {
    // The opening-entry section makes the form taller than the test surface;
    // scroll the Save button into view before tapping.
    await tester.ensureVisible(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('name + amount books contact and its first entry', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byKey(const Key('contact-name')), 'Omar');
    await tester.enterText(find.byKey(const Key('entry-amount')), '200');
    await tapSave(tester);

    final all = await contacts.list();
    expect(all.single.name, 'Omar');
    expect((await entries.listByContact(all.single.id!)).single.amount, 200);
  });

  testWidgets('name only books just the contact', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byKey(const Key('contact-name')), 'Nada');
    await tapSave(tester);

    final all = await contacts.list();
    expect(all.single.name, 'Nada');
    expect(await entries.listByContact(all.single.id!), isEmpty);
  });
}
