import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/archived_contacts_screen.dart';
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

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ArchivedContactsScreen(
      contactRepository: contacts,
      entryRepository: entries,
      currency: Currency.sar,
    ),
  );

  testWidgets('lists archived contacts and unarchives them inline', (
    tester,
  ) async {
    final c = await contacts.add(const Contact(name: 'Ali'));
    await contacts.setArchived(c.id!, archived: true);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);

    await tester.tap(find.byKey(Key('unarchive-${c.id}')));
    await tester.pumpAndSettle();

    // The row is gone and the contact is back in the active list.
    expect(find.text('Ali'), findsNothing);
    expect((await contacts.list()).map((x) => x.name), ['Ali']);
    expect(await contacts.listArchived(), isEmpty);
  });

  testWidgets('shows the empty state when nothing is archived', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('No archived contacts'), findsOneWidget);
  });
}
