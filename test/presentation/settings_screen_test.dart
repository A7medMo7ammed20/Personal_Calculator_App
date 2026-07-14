import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/language_choice.dart';
import 'package:debt_ledger/domain/theme_choice.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/locale/locale_controller.dart';
import 'package:debt_ledger/presentation/settings/settings_screen.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository repo;
  late ThemeController controller;

  setUp(() {
    // NoIsolate: a testWidgets FakeAsync zone can't drive sqflite's background
    // isolate, so isolate-backed DB futures would deadlock (as the other
    // widget tests already avoid).
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    repo = SettingsRepository(appDb);
    controller = ThemeController(repo);
  });

  tearDown(() => appDb.close());

  Widget host() => MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(controller: controller),
      );

  testWidgets('tapping an accent swatch selects and persists it', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('accent-plum')));
    await tester.pumpAndSettle();

    expect(controller.accent, AccentTheme.plum);
    expect(await repo.accent(), AccentTheme.plum);
  });

  testWidgets('tapping a brightness option selects and persists it', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(controller.themeChoice, ThemeChoice.dark);
    expect(await repo.themeChoice(), ThemeChoice.dark);
  });

  testWidgets('shows the four accents and three brightness options', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    for (final accent in AccentTheme.values) {
      expect(find.byKey(Key('accent-${accent.code}')), findsOneWidget);
    }
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  Widget hostWithPrefs(CurrencyController currency, LocaleController locale) =>
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          controller: controller,
          currencyController: currency,
          localeController: locale,
        ),
      );

  testWidgets('Preferences is hidden when the controllers are absent', (
    tester,
  ) async {
    await tester.pumpWidget(host()); // theme-only host from the existing tests
    expect(find.text('Preferences'), findsNothing);
    // Only the theme "System" segment exists — no language "System".
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('default-currency segment persists + live-switches via setDefault',
      (tester) async {
    final currency = CurrencyController(repo);
    await currency.load(); // SAR
    final locale = LocaleController(repo);
    await tester.pumpWidget(hostWithPrefs(currency, locale));
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    await tester.tap(find.byKey(const Key('currency-YER')));
    await tester.pumpAndSettle();

    expect(currency.defaultCurrency, Currency.yer);
    expect(currency.active, Currency.yer);
    expect(await repo.defaultCurrency(), Currency.yer);
  });

  testWidgets('language segment selects العربية and persists', (tester) async {
    final currency = CurrencyController(repo);
    final locale = LocaleController(repo);
    await tester.pumpWidget(hostWithPrefs(currency, locale));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language-ar')));
    await tester.pumpAndSettle();

    expect(locale.languageChoice, LanguageChoice.arabic);
    expect(await repo.language(), LanguageChoice.arabic);
  });
}
