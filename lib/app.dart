import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

import 'branding/daftar_splash.dart';
import 'data/app_database.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'presentation/currency/currency_controller.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/locale/locale_controller.dart';
import 'presentation/profile/profile_controller.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_controller.dart';

/// Root widget: wires theming (accent + brightness via [ThemeController]),
/// language (via [LocaleController] → `MaterialApp.locale`, RTL/LTR live), the
/// currency lens ([CurrencyController]) and the home screen. Rebuilds whenever
/// the theme or the language changes (ADR 0002/0007).
class DebtLedgerApp extends StatelessWidget {
  const DebtLedgerApp({
    super.key,
    required this.appDatabase,
    required this.contactRepository,
    required this.entryRepository,
    required this.themeController,
    required this.profileController,
    required this.currencyController,
    required this.localeController,
  });

  final AppDatabase appDatabase;
  final ContactRepository contactRepository;
  final EntryRepository entryRepository;
  final ThemeController themeController;
  final ProfileController profileController;
  final CurrencyController currencyController;
  final LocaleController localeController;

  /// Erase all data (#25): wipe every table, then reload each controller so the
  /// app snaps back to its genuine first-run state — default theme, language,
  /// currency and no profile. The currency reload notifies HomeScreen, which
  /// refetches the (now empty) ledger.
  Future<void> _eraseAllData() async {
    await appDatabase.eraseAll();
    await themeController.load();
    await profileController.load();
    await currencyController.load();
    await localeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Theme + language both change MaterialApp-level props; merge them so
      // either re-tints / re-localizes the whole app live. Currency is not
      // here — it changes only body content, and HomeScreen listens directly.
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(
          brightness: Brightness.light,
          seed: themeController.seed,
        ),
        darkTheme: buildAppTheme(
          brightness: Brightness.dark,
          seed: themeController.seed,
        ),
        themeMode: themeController.themeMode,
        locale: localeController.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Under "system" (locale == null) a device set to neither ar nor en
        // falls back to English, not the alphabetically-first 'ar' (ADR 0007).
        localeListResolutionCallback: (locales, supported) {
          if (locales != null) {
            for (final device in locales) {
              for (final option in supported) {
                if (option.languageCode == device.languageCode) return option;
              }
            }
          }
          return const Locale('en');
        },
        home: Builder(
          builder: (context) => DaftarSplash(
            onDone: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  repository: contactRepository,
                  entryRepository: entryRepository,
                  currencyController: currencyController,
                  themeController: themeController,
                  profileController: profileController,
                  localeController: localeController,
                  onEraseAllData: _eraseAllData,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
