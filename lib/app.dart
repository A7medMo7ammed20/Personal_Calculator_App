import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

import 'branding/daftar_splash.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/profile/profile_controller.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_controller.dart';

/// Root widget: wires theming (switchable accent + brightness via
/// [ThemeController]), localization (Arabic + English with RTL) and the home
/// screen. Rebuilds whenever the user changes the accent or brightness so the
/// whole app re-tints live (ADR 0002).
class DebtLedgerApp extends StatelessWidget {
  const DebtLedgerApp({
    super.key,
    required this.contactRepository,
    required this.entryRepository,
    required this.themeController,
    required this.profileController,
  });

  final ContactRepository contactRepository;
  final EntryRepository entryRepository;
  final ThemeController themeController;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Cold launch shows the animated Daftar splash (the monogram draws on,
        // then the دفتر · Daftar wordmark reveals), which routes to the home
        // screen when it finishes. The Builder gives a context under the
        // Navigator so the splash can replace itself with Home.
        home: Builder(
          builder: (context) => DaftarSplash(
            onDone: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  repository: contactRepository,
                  entryRepository: entryRepository,
                  themeController: themeController,
                  profileController: profileController,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
