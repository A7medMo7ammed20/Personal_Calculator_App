import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/backup_dirty_flag.dart';
import 'data/backup_service.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'data/profile_repository.dart';
import 'data/settings_repository.dart';
import 'presentation/currency/currency_controller.dart';
import 'presentation/locale/locale_controller.dart';
import 'presentation/profile/profile_controller.dart';
import 'presentation/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase();
  // One dirty flag shared by every write path, so auto-backup can skip when
  // nothing changed since the last snapshot (#26, ADR 0010).
  final dirtyFlag = BackupDirtyFlag();
  final settingsRepository = SettingsRepository(appDatabase, dirty: dirtyFlag);
  final contactRepository = ContactRepository(appDatabase, dirty: dirtyFlag);
  final entryRepository = EntryRepository(appDatabase, dirty: dirtyFlag);
  final themeController = ThemeController(settingsRepository);
  final profileController =
      ProfileController(ProfileRepository(appDatabase, dirty: dirtyFlag));
  final currencyController = CurrencyController(settingsRepository);
  final localeController = LocaleController(settingsRepository);
  // Load every persisted preference before the first frame so the app opens in
  // the user's theme, language and default currency without a flash of default.
  await themeController.load();
  await profileController.load();
  await currencyController.load();
  await localeController.load();

  // App-private backups directory (a sibling of the database file — no
  // path_provider needed, and it stays inside the app sandbox).
  final backupsDir = Directory(
      p.join(await appDatabase.factory.getDatabasesPath(), 'backups'));
  final backupService =
      BackupService(appDatabase: appDatabase, backupsDir: backupsDir);

  runApp(DebtLedgerApp(
    appDatabase: appDatabase,
    contactRepository: contactRepository,
    entryRepository: entryRepository,
    themeController: themeController,
    profileController: profileController,
    currencyController: currencyController,
    localeController: localeController,
    backupService: backupService,
    dirtyFlag: dirtyFlag,
    onShareBackup: (file) =>
        SharePlus.instance.share(ShareParams(files: [XFile(file.path)])),
    onPickBackupFile: () async {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      return path == null ? null : File(path);
    },
  ));
}
