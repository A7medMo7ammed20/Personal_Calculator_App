import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/language_choice.dart';
import 'package:debt_ledger/presentation/locale/locale_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository repo;
  late LocaleController controller;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = SettingsRepository(appDb);
    controller = LocaleController(repo);
  });

  tearDown(() => appDb.close());

  test('defaults to system → null locale', () {
    expect(controller.languageChoice, LanguageChoice.system);
    expect(controller.locale, isNull);
  });

  test('arabic maps to Locale(ar), english to Locale(en)', () async {
    await controller.setLanguageChoice(LanguageChoice.arabic);
    expect(controller.locale, const Locale('ar'));
    await controller.setLanguageChoice(LanguageChoice.english);
    expect(controller.locale, const Locale('en'));
  });

  test('setLanguageChoice persists; load reads it back', () async {
    await controller.setLanguageChoice(LanguageChoice.arabic);
    final other = LocaleController(repo);
    await other.load();
    expect(other.languageChoice, LanguageChoice.arabic);
    expect(other.locale, const Locale('ar'));
  });

  test('notifies on change', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);
    await controller.setLanguageChoice(LanguageChoice.english);
    expect(notifications, greaterThanOrEqualTo(1));
  });
}
