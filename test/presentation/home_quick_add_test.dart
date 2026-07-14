import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/entries/add_transaction_screen.dart';
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

  HomeScreen host() => HomeScreen(
    repository: contacts,
    entryRepository: entries,
    currencyController: CurrencyController(SettingsRepository(appDb)),
  );

  testWidgets('speed-dial reveals both add actions', (tester) async {
    await tester.pumpWidget(_wrap(host()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-speed-dial')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-add-transaction')), findsOneWidget);
    expect(find.byKey(const Key('quick-add-contact')), findsOneWidget);
  });

  testWidgets('Add معاملة opens the AddTransactionScreen', (tester) async {
    await tester.pumpWidget(_wrap(host()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-speed-dial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-add-transaction')));
    await tester.pumpAndSettle();

    expect(find.byType(AddTransactionScreen), findsOneWidget);
  });
}
