import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

import 'presentation/home/home_screen.dart';

/// Root widget: wires theming (light/dark following the system), localization
/// (Arabic + English with RTL) and the home screen.
class DebtLedgerApp extends StatelessWidget {
  const DebtLedgerApp({super.key});

  static const Color _seed = Color(0xFF2E7D5B); // ledger green

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
