import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:debt_ledger/domain/theme_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository repo;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = SettingsRepository(appDb);
  });

  tearDown(() => appDb.close());

  test('returns the defaults on a fresh database', () async {
    expect(await repo.accent(), AccentTheme.teal);
    expect(await repo.themeChoice(), ThemeChoice.system);
  });

  test('persists and reads back the accent', () async {
    await repo.setAccent(AccentTheme.plum);
    expect(await repo.accent(), AccentTheme.plum);
  });

  test('persists and reads back the theme choice', () async {
    await repo.setThemeChoice(ThemeChoice.dark);
    expect(await repo.themeChoice(), ThemeChoice.dark);
  });

  test('setting a key twice overwrites rather than duplicating', () async {
    await repo.setAccent(AccentTheme.indigo);
    await repo.setAccent(AccentTheme.ocean);
    expect(await repo.accent(), AccentTheme.ocean);
  });

  test('a separate repository on the same db reads persisted values', () async {
    // Settings live in the shared SQLite file, so they travel with the Backup
    // (ADR 0001) — a fresh repository instance sees what an earlier one wrote.
    await repo.setAccent(AccentTheme.indigo);
    await repo.setThemeChoice(ThemeChoice.light);

    final other = SettingsRepository(appDb);
    expect(await other.accent(), AccentTheme.indigo);
    expect(await other.themeChoice(), ThemeChoice.light);
  });
}
