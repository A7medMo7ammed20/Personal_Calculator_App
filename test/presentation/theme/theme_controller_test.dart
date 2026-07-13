import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:debt_ledger/domain/theme_choice.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository repo;
  late ThemeController controller;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = SettingsRepository(appDb);
    controller = ThemeController(repo);
  });

  tearDown(() => appDb.close());

  test('starts on the defaults before load', () {
    expect(controller.accent, AccentTheme.teal);
    expect(controller.themeChoice, ThemeChoice.system);
    expect(controller.themeMode, ThemeMode.system);
    expect(controller.seed, const Color(0xFF14746F));
  });

  test('load pulls persisted values and notifies once', () async {
    await repo.setAccent(AccentTheme.plum);
    await repo.setThemeChoice(ThemeChoice.dark);
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.load();

    expect(controller.accent, AccentTheme.plum);
    expect(controller.themeChoice, ThemeChoice.dark);
    expect(notified, 1);
  });

  test('setAccent updates, notifies, and persists', () async {
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setAccent(AccentTheme.ocean);

    expect(controller.accent, AccentTheme.ocean);
    expect(controller.seed, const Color(0xFF0369A1));
    expect(notified, 1);
    expect(await repo.accent(), AccentTheme.ocean);
  });

  test('setThemeChoice updates the ThemeMode and persists', () async {
    await controller.setThemeChoice(ThemeChoice.light);

    expect(controller.themeChoice, ThemeChoice.light);
    expect(controller.themeMode, ThemeMode.light);
    expect(await repo.themeChoice(), ThemeChoice.light);
  });

  test('every ThemeChoice maps to the matching ThemeMode', () async {
    await controller.setThemeChoice(ThemeChoice.dark);
    expect(controller.themeMode, ThemeMode.dark);
    await controller.setThemeChoice(ThemeChoice.system);
    expect(controller.themeMode, ThemeMode.system);
  });
}
