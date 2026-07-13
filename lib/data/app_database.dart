import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite database and its schema versioning.
///
/// The schema is empty at version 1; later slices add the Contacts and Entries
/// tables by bumping [schemaVersion] and extending [_migrate]. A [DatabaseFactory]
/// and [path] can be injected so tests run against an in-memory database.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      // ignore: prefer_initializing_formals
      _path = path;

  /// Current schema version. Bump this and handle the delta in [_migrate]
  /// whenever the schema changes.
  static const int schemaVersion = 2;

  static const String _defaultFileName = 'debt_ledger.db';

  final DatabaseFactory _factory;
  final String? _path;

  Database? _db;

  /// Opens the database (idempotent), running migrations as needed.
  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = _path ?? p.join(await _factory.getDatabasesPath(), _defaultFileName);
    final db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: (db, oldVersion, newVersion) => _migrate(db, oldVersion, newVersion),
      ),
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onConfigure(Database db) async {
    // Entries cascade-delete with their Contact; keep foreign keys enforced.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Applies schema changes for every version in `(from, to]`. Each `if (from <
  /// N)` block owns the delta introduced at version N, so a fresh install
  /// (from == 0) and an upgrade both land on the same schema.
  Future<void> _migrate(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('''
        CREATE TABLE contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT
        )
      ''');
    }
  }
}
