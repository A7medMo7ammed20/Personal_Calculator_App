import 'dart:io';

import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_service.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/settings/backup_restore_section.dart';
import 'package:debt_ledger/presentation/settings/settings_screen.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A [BackupService] test double that returns results WITHOUT the real
/// close→copy→reopen file I/O. A `testWidgets` body runs in a FakeAsync zone
/// where real file/isolate I/O never completes (it hangs), so the widget's file
/// mechanism cannot be exercised here. Those mechanics are covered by the
/// data-layer tests (`backup_service_test.dart`); this widget test asserts only
/// the Settings UI orchestration — dialog gating, callback wiring, and
/// [RestoreResult] → message mapping.
class _FakeBackupService extends BackupService {
  _FakeBackupService(AppDatabase db)
      : super(appDatabase: db, backupsDir: Directory('build/_unused_backups'));

  RestoreResult nextRestore = RestoreResult.success;
  List<AutoBackupEntry> ring = const [];
  File? exportResult;
  File? restoredFrom;
  int restoreCalls = 0;

  @override
  Future<File> export() async => exportResult!;

  @override
  Future<RestoreResult> restore(File file) async {
    restoreCalls++;
    restoredFrom = file;
    return nextRestore;
  }

  @override
  Future<List<AutoBackupEntry>> listAutoBackups() async => ring;

  @override
  Future<File> autoBackup() async => exportResult ?? File('unused');
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tmp;
  late AppDatabase appDb;
  late _FakeBackupService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('daftar_section_');
    appDb = AppDatabase(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    service = _FakeBackupService(appDb);
  });
  tearDown(() async {
    await appDb.close();
    await tmp.delete(recursive: true);
  });

  Widget host(BackupSectionConfig config) => MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          controller: ThemeController(SettingsRepository(appDb)),
          backup: config,
        ),
      );

  BackupSectionConfig config({
    Future<void> Function(File)? onShare,
    Future<File?> Function()? onPickFile,
    Future<void> Function()? onRestored,
    void Function(String)? showMessage,
  }) =>
      BackupSectionConfig(
        service: service,
        onShare: onShare ?? (_) async {},
        onPickFile: onPickFile ?? () async => null,
        onRestored: onRestored ?? () async {},
        showMessage: showMessage ?? (_) {},
      );

  // A real file created with SYNC I/O (FakeAsync-safe) that a fake backup call
  // can hand back, so callers still receive a genuine, existing file.
  File fakeBackupFile(String name) => File(p.join(tmp.path, name))
    ..writeAsBytesSync(const [1, 2, 3]);

  testWidgets('Export produces a file and hands it to onShare', (tester) async {
    service.exportResult = fakeBackupFile('daftar-backup-x.db');
    File? shared;
    await tester.pumpWidget(host(config(onShare: (f) async => shared = f)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();

    expect(shared, isNotNull);
    expect(shared!.existsSync(), isTrue);
  });

  testWidgets('Restore-from-file confirm gates the restore', (tester) async {
    final file = fakeBackupFile('picked.db');
    var restored = 0;
    await tester.pumpWidget(host(config(
      onPickFile: () async => file,
      onRestored: () async => restored++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-restore-file')));
    await tester.pumpAndSettle();
    // Dialog shown; cancelling does not restore.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(restored, 0);
    expect(service.restoreCalls, 0);

    // Confirming restores.
    await tester.tap(find.byKey(const Key('backup-restore-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();
    expect(restored, 1);
    expect(service.restoredFrom, file);
  });

  testWidgets('a foreign file is refused with a message, no reload', (tester) async {
    service.nextRestore = RestoreResult.notABackup;
    final garbage = fakeBackupFile('x.txt');
    var restored = 0;
    final messages = <String>[];
    await tester.pumpWidget(host(config(
      onPickFile: () async => garbage,
      onRestored: () async => restored++,
      showMessage: messages.add,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-restore-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();

    expect(restored, 0);
    expect(messages.single, "That file isn't a Daftar backup");
  });

  testWidgets('auto-backup list renders dated entries and restores a pick', (
    tester,
  ) async {
    service.ring = [
      AutoBackupEntry(
        file: fakeBackupFile('auto-1.db'),
        createdAt: DateTime(2026, 1, 2, 15, 30),
      ),
    ];
    var restored = 0;
    await tester.pumpWidget(host(config(onRestored: () async => restored++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-restore-auto')));
    await tester.pumpAndSettle();
    // A dated tile appears; tap it, then confirm.
    await tester.tap(find.byKey(const Key('auto-backup-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-restore-confirm')));
    await tester.pumpAndSettle();
    expect(restored, 1);
  });

  testWidgets('the Backup section is hidden when no config is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(controller: ThemeController(SettingsRepository(appDb))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-export')), findsNothing);
  });
}
