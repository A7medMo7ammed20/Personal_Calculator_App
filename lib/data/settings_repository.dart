import 'package:sqflite/sqflite.dart';

import '../domain/accent_theme.dart';
import '../domain/theme_choice.dart';
import 'app_database.dart';

/// Reads and writes app preferences in the key/value `settings` table.
///
/// Each preference is stored as its stable string code, so an unknown value
/// (e.g. after a downgrade) degrades to the type's default via `fromCode`
/// rather than throwing. Because the table lives in the app database, the
/// choices travel with the Backup (ADR 0001).
class SettingsRepository {
  SettingsRepository(this._appDb);

  static const String table = 'settings';

  static const String _accentKey = 'accent';
  static const String _themeChoiceKey = 'theme_choice';

  final AppDatabase _appDb;

  /// The selected accent, or [AccentTheme.defaultAccent] if none is stored.
  Future<AccentTheme> accent() async =>
      AccentTheme.fromCode(await _get(_accentKey));

  Future<void> setAccent(AccentTheme accent) => _set(_accentKey, accent.code);

  /// The selected brightness, or [ThemeChoice.defaultChoice] if none is stored.
  Future<ThemeChoice> themeChoice() async =>
      ThemeChoice.fromCode(await _get(_themeChoiceKey));

  Future<void> setThemeChoice(ThemeChoice choice) =>
      _set(_themeChoiceKey, choice.code);

  Future<String?> _get(String key) async {
    final db = await _appDb.open();
    final rows = await db.query(
      table,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    final db = await _appDb.open();
    await db.insert(
      table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
