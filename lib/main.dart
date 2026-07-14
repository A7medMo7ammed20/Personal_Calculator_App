import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';
import 'data/profile_repository.dart';
import 'data/settings_repository.dart';
import 'presentation/profile/profile_controller.dart';
import 'presentation/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase();
  final contactRepository = ContactRepository(appDatabase);
  final entryRepository = EntryRepository(appDatabase);
  final themeController = ThemeController(SettingsRepository(appDatabase));
  final profileController = ProfileController(ProfileRepository(appDatabase));
  // Load the persisted accent + brightness (and the profile) before the first
  // frame so the app opens in the user's chosen theme without a flash of the
  // default, and the export flow already knows whether a name is set.
  await themeController.load();
  await profileController.load();
  runApp(DebtLedgerApp(
    contactRepository: contactRepository,
    entryRepository: entryRepository,
    themeController: themeController,
    profileController: profileController,
  ));
}
