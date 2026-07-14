import 'dart:io';

import 'package:flutter/material.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';

import 'branding/daftar_splash.dart';
import 'data/app_database.dart';
import 'data/backup_dirty_flag.dart';
import 'data/backup_service.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'presentation/backup/auto_backup_observer.dart';
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
///
/// Stateful since #26: it owns the shared reload helper ([_reloadApp]) — reused
/// by Erase all data (#25) and by Restore — plus a generation key that remounts
/// the app root so no screen keeps stale rows, a root scaffold-messenger for
/// messages that survive that remount, and the auto-backup lifecycle wrapper.
class DebtLedgerApp extends StatefulWidget {
  const DebtLedgerApp({
    super.key,
    required this.appDatabase,
    required this.contactRepository,
    required this.entryRepository,
    required this.themeController,
    required this.profileController,
    required this.currencyController,
    required this.localeController,
    this.backupService,
    this.dirtyFlag,
    this.onShareBackup,
    this.onPickBackupFile,
  });

  final AppDatabase appDatabase;
  final ContactRepository contactRepository;
  final EntryRepository entryRepository;
  final ThemeController themeController;
  final ProfileController profileController;
  final CurrencyController currencyController;
  final LocaleController localeController;
  final BackupService? backupService;
  final BackupDirtyFlag? dirtyFlag;
  final Future<void> Function(File file)? onShareBackup;
  final Future<File?> Function()? onPickBackupFile;

  @override
  State<DebtLedgerApp> createState() => _DebtLedgerAppState();
}

class _DebtLedgerAppState extends State<DebtLedgerApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  int _generation = 0;

  /// Shared reload helper (ADR 0010): reopen the database implicitly by reloading
  /// every controller via the SAME code path used at startup, clear the dirty
  /// flag, then bump [_generation] so the navigator remounts with no stale rows.
  /// Reused by Erase all data (#25) and by Restore.
  Future<void> _reloadApp() async {
    await widget.themeController.load();
    await widget.profileController.load();
    await widget.currencyController.load();
    await widget.localeController.load();
    widget.dirtyFlag?.reset();
    if (mounted) setState(() => _generation++);
  }

  Future<void> _eraseAllData() async {
    await widget.appDatabase.eraseAll();
    await _reloadApp();
  }

  @override
  Widget build(BuildContext context) {
    final app = ListenableBuilder(
      // Theme + language both change MaterialApp-level props; merge them so
      // either re-tints / re-localizes the whole app live. Currency is not
      // here — it changes only body content, and HomeScreen listens directly.
      listenable:
          Listenable.merge([widget.themeController, widget.localeController]),
      builder: (context, _) => MaterialApp(
        scaffoldMessengerKey: _messengerKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(
          brightness: Brightness.light,
          seed: widget.themeController.seed,
        ),
        darkTheme: buildAppTheme(
          brightness: Brightness.dark,
          seed: widget.themeController.seed,
        ),
        themeMode: widget.themeController.themeMode,
        locale: widget.localeController.locale,
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
        home: KeyedSubtree(
          key: ValueKey(_generation),
          child: _generation == 0
              ? Builder(
                  builder: (context) => DaftarSplash(
                    onDone: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => _home()),
                    ),
                  ),
                )
              : _home(), // remount lands straight on home (no splash replay)
        ),
      ),
    );

    final dirty = widget.dirtyFlag;
    final service = widget.backupService;
    if (dirty == null || service == null) return app;
    return AutoBackupObserver(
      dirtyFlag: dirty,
      onBackground: service.autoBackup,
      child: app,
    );
  }

  Widget _home() => HomeScreen(
        repository: widget.contactRepository,
        entryRepository: widget.entryRepository,
        currencyController: widget.currencyController,
        themeController: widget.themeController,
        profileController: widget.profileController,
        localeController: widget.localeController,
        onEraseAllData: _eraseAllData,
      );
}
