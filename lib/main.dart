import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
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
  final settingsRepository = SettingsRepository(appDatabase);
  final contactRepository = ContactRepository(appDatabase);
  final entryRepository = EntryRepository(appDatabase);
  final themeController = ThemeController(settingsRepository);
  final profileController = ProfileController(ProfileRepository(appDatabase));
  final currencyController = CurrencyController(settingsRepository);
  final localeController = LocaleController(settingsRepository);
  // Load every persisted preference before the first frame so the app opens in
  // the user's theme, language and default currency without a flash of default.
  await themeController.load();
  await profileController.load();
  await currencyController.load();
  await localeController.load();
  runApp(DebtLedgerApp(
    appDatabase: appDatabase,
    contactRepository: contactRepository,
    entryRepository: entryRepository,
    themeController: themeController,
    profileController: profileController,
    currencyController: currencyController,
    localeController: localeController,
  ));
}
