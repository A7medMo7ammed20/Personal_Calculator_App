import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

// The no-isolate factory keeps SQLite in the test isolate so pumpAndSettle can
// see the async responses (the default ffi factory runs it in a background
// isolate whose port messages the fake test clock never pumps).
HomeScreen _homeScreen() {
  final db = AppDatabase(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
  return HomeScreen(
    repository: ContactRepository(db),
    entryRepository: EntryRepository(db),
    currencyController: CurrencyController(SettingsRepository(db)),
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('home renders the English empty state (LTR)', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('en'), _homeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debt Ledger'), findsOneWidget);
    expect(find.text('No contacts yet'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr);
  });

  testWidgets('home renders the Arabic empty state (RTL)', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('ar'), _homeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('دفتر الديون'), findsOneWidget);
    expect(find.text('لا توجد جهات اتصال بعد'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);
  });

  testWidgets('adding a Contact shows it in the home list', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('en'), _homeScreen()),
    );
    await tester.pumpAndSettle();

    // Open the ＋ speed-dial, then choose Add جهة اتصال.
    await tester.tap(find.byKey(const Key('home-speed-dial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-add-contact')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Khaled');
    // The opening-معاملة section pushes Save below the fold now.
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Khaled'), findsOneWidget);
    expect(find.text('No contacts yet'), findsNothing);
  });

  testWidgets('saving with an empty name is blocked', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('en'), _homeScreen()),
    );
    await tester.pumpAndSettle();

    // Open the ＋ speed-dial, then choose Add جهة اتصال.
    await tester.tap(find.byKey(const Key('home-speed-dial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-add-contact')));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Still on the form, with the validation message shown.
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });
}
