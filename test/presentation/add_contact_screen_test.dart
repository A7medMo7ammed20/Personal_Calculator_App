import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/add_contact_screen.dart';
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

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
  });

  tearDown(() => appDb.close());

  testWidgets('editing a contact prefills and updates in place', (tester) async {
    final saved = await contacts.add(const Contact(name: 'Old', phone: '111'));

    await tester.pumpWidget(_wrap(
      AddContactScreen(repository: contacts, existing: saved),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit contact'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('111'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'New');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = (await contacts.list()).single;
    expect(stored.id, saved.id);
    expect(stored.name, 'New');
  });
}
