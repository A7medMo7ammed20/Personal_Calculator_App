import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Root widget: wires theming (light/dark following the system), localization
/// (Arabic + English with RTL) and the home screen.
class DebtLedgerApp extends StatelessWidget {
  const DebtLedgerApp({
    super.key,
    required this.contactRepository,
    required this.entryRepository,
  });

  final ContactRepository contactRepository;
  final EntryRepository entryRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(
        repository: contactRepository,
        entryRepository: entryRepository,
      ),
    );
  }
}
