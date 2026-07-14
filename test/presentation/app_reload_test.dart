import 'dart:io';

import 'package:debt_ledger/app.dart';
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_dirty_flag.dart';
import 'package:debt_ledger/data/backup_service.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/locale/locale_controller.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Full-app reload integration for Erase all data (#25) routed through the shared
// `_reloadApp` helper + key-bump remount (#26): seed a contact, erase it via
// Settings, assert the remounted home is empty.
//
// Uses the no-isolate ffi factory + `inMemoryDatabasePath` (like widget_test.dart
// and settings_erase_test.dart): a widget test runs its body in a FakeAsync zone,
// so real-async work (dart:io temp files, no-isolate DB calls) only completes
// when the clock is pumped. Pre-`pumpWidget` seeding therefore runs inside
// `tester.runAsync` (real clock); the app's own in-memory loads complete under
// `pumpAndSettle`. No real file is needed — this test never exercises a backup,
// so `BackupService` gets an unused directory.
void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('erase reloads and remounts to an empty home', (tester) async {
    final appDb = AppDatabase(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(appDb.close);
    final dirty = BackupDirtyFlag();
    final settings = SettingsRepository(appDb, dirty: dirty);
    final contacts = ContactRepository(appDb, dirty: dirty);
    final entries = EntryRepository(appDb, dirty: dirty);

    final theme = ThemeController(settings);
    final profile = ProfileController(ProfileRepository(appDb, dirty: dirty));
    final currency = CurrencyController(settings);
    final locale = LocaleController(settings);

    // Real-async setup off the FakeAsync clock (see file header).
    await tester.runAsync(() async {
      await contacts.add(const Contact(name: 'Ali'));
      await theme.load();
      await profile.load();
      await currency.load();
      await locale.load();
    });

    await tester.pumpWidget(DebtLedgerApp(
      appDatabase: appDb,
      contactRepository: contacts,
      entryRepository: entries,
      themeController: theme,
      profileController: profile,
      currencyController: currency,
      localeController: locale,
      backupService: BackupService(
          appDatabase: appDb, backupsDir: Directory('build/_unused_backups')),
      dirtyFlag: dirty,
      onShareBackup: (_) async {},
      onPickBackupFile: () async => null,
    ));
    // Advance past the splash's hold-timer (~1s) — its animation stops scheduling
    // frames before the timer fires, so a bare pumpAndSettle would settle on the
    // splash. Then settle the route transition + home load.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);

    // Open Settings → Erase all data → type-to-confirm.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // The full app's Settings list (profile + preferences + appearance + accent
    // + data) is long; the erase tile sits at the bottom, off-screen and unbuilt.
    await tester.scrollUntilVisible(
      find.byKey(const Key('erase-all-data')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('erase-all-data')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('erase-confirm-field')), 'ERASE');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('erase-confirm')));
    await tester.pumpAndSettle();

    // Remounted home no longer shows the erased contact.
    expect(find.text('Ali'), findsNothing);
  });
}
