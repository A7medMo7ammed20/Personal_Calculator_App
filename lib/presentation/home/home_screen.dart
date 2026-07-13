import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

/// The home screen. Empty for now — later slices fill it with the Contact list,
/// currency lens, period filter and grand-total header.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Text(
          l10n.homeEmpty,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
