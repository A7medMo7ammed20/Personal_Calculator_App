import 'package:sqflite/sqflite.dart';

import '../domain/profile.dart';
import 'app_database.dart';

/// Reads and writes the single local [Profile] in the key/value `settings`
/// table (the same table [SettingsRepository] uses), so the profile travels
/// with the Backup (ADR 0001) at no extra cost and needs no schema migration.
///
/// The name is the anchor: [profile] returns `null` unless a non-blank name is
/// stored — an orphan phone, a blank name, or a fresh install all read as "no
/// profile yet", which is exactly the signal the first-export name prompt keys
/// off (see `ensureProfileName`).
class ProfileRepository {
  ProfileRepository(this._appDb);

  static const String table = 'settings';

  static const String _nameKey = 'profile_name';
  static const String _phoneKey = 'profile_phone';

  final AppDatabase _appDb;

  /// The stored [Profile], or `null` when no non-blank name has been set.
  Future<Profile?> profile() async {
    final name = (await _get(_nameKey))?.trim();
    if (name == null || name.isEmpty) return null;
    final phone = (await _get(_phoneKey))?.trim();
    return Profile(
      name: name,
      phone: (phone == null || phone.isEmpty) ? null : phone,
    );
  }

  /// Persists [name] (trimmed). A blank value reads back as "no profile".
  Future<void> setName(String name) => _set(_nameKey, name.trim());

  /// Persists [phone] (trimmed); `null`/blank clears it back to no phone.
  Future<void> setPhone(String? phone) => _set(_phoneKey, phone?.trim() ?? '');

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
