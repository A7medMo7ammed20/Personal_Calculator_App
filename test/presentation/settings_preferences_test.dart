import 'package:debt_ledger/app.dart';
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/currency.dart';
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
  late CurrencyController currency;
  late LocaleController locale;

  setUp(() async {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    settings = SettingsRepository(appDb);
    currency = CurrencyController(settings);
    locale = LocaleController(settings);
    await currency.load();
    await locale.load();
  });

  tearDown(() => appDb.close());

  Future<void> pumpToHome(WidgetTester tester) async {
    await tester.pumpWidget(DebtLedgerApp(
      appDatabase: appDb,
      contactRepository: ContactRepository(appDb),
      entryRepository: EntryRepository(appDb),
      themeController: ThemeController(settings),
      profileController: ProfileController(ProfileRepository(appDb)),
      currencyController: currency,
      localeController: locale,
    ));
    // Advance past the DaftarSplash draw + hold, then settle onto home.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  Locale? rootLocale(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale;

  testWidgets('choosing العربية flips the app to Arabic RTL and persists', (
    tester,
  ) async {
    await pumpToHome(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const Key('language-ar')));
    await tester.pumpAndSettle();

    expect(rootLocale(tester), const Locale('ar'));
    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
    expect(await settings.language(), isNotNull);
  });

  testWidgets('changing the default currency live-switches the lens + persists',
      (tester) async {
    await pumpToHome(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const Key('currency-YER')));
    await tester.pumpAndSettle();

    expect(currency.active, Currency.yer);
    expect(currency.defaultCurrency, Currency.yer);
    expect(await settings.defaultCurrency(), Currency.yer);
  });

  testWidgets('a bottom-tab tap does not rewrite the persisted default', (
    tester,
  ) async {
    await pumpToHome(tester); // default SAR

    // Tap the YER bottom-tab (transient lens change).
    await tester.tap(find.text('YER'));
    await tester.pumpAndSettle();

    expect(currency.active, Currency.yer);
    expect(currency.defaultCurrency, Currency.sar);
    expect(await settings.defaultCurrency(), Currency.sar); // untouched
  });
}
