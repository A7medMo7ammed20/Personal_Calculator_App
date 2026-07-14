import 'package:debt_ledger/app.dart';
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/language_choice.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/locale/locale_controller.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository settings;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    settings = SettingsRepository(appDb);
  });

  tearDown(() => appDb.close());

  Future<void> pumpApp(WidgetTester tester, LocaleController locale) async {
    final currency = CurrencyController(settings);
    await currency.load();
    await tester.pumpWidget(DebtLedgerApp(
      contactRepository: ContactRepository(appDb),
      entryRepository: EntryRepository(appDb),
      themeController: ThemeController(settings),
      profileController: ProfileController(ProfileRepository(appDb)),
      currencyController: currency,
      localeController: locale,
    ));
  }

  Locale? rootLocale(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale;

  testWidgets('a forced Arabic choice sets MaterialApp.locale to ar', (
    tester,
  ) async {
    final locale = LocaleController(settings);
    await locale.setLanguageChoice(LanguageChoice.arabic);
    await pumpApp(tester, locale);
    await tester.pump();
    expect(rootLocale(tester), const Locale('ar'));
  });

  testWidgets('system yields a null MaterialApp.locale', (tester) async {
    final locale = LocaleController(settings); // default system
    await pumpApp(tester, locale);
    await tester.pump();
    expect(rootLocale(tester), isNull);
  });

  testWidgets('a non-ar/en device locale under system resolves to English', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final locale = LocaleController(settings); // system
    await pumpApp(tester, locale);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Fallback is English (ADR 0007), not the alphabetically-first 'ar'.
    expect(find.text('No contacts yet'), findsOneWidget);
  });
}
