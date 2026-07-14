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
  static const int schemaVersion = 5;

  static const String _defaultFileName = 'debt_ledger.db';

  final DatabaseFactory _factory;
  final String? _path;

  Database? _db;

  /// The factory the app opened with — reused to validate candidate backup
  /// files against the same SQLite engine (see BackupService).
  DatabaseFactory get factory => _factory;

  /// The absolute path of the live database file (same resolution [open] uses).
  Future<String> resolvedPath() async =>
      _path ?? p.join(await _factory.getDatabasesPath(), _defaultFileName);

  /// Opens the database (idempotent), running migrations as needed.
  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await resolvedPath();
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

  /// Wipes every table to a genuine first-run state (Erase all data, ADR 0009).
  /// Schema is left intact; only rows are dropped. Irreversible.
  Future<void> eraseAll() async {
    final db = await open();
    await db.delete('entries');
    await db.delete('contacts');
    await db.delete('settings');
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
    if (from < 3) {
      // Entries carry a `currency` column now so slice #4 (the currency lens)
      // only adds filtering, not a migration. Cascade delete relies on
      // `PRAGMA foreign_keys = ON` (set in _onConfigure).
      await db.execute('''
        CREATE TABLE entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contact_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          direction TEXT NOT NULL,
          currency TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          description TEXT,
          FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_entries_contact_id ON entries (contact_id)',
      );
    }
    if (from < 4) {
      // A simple key/value store for app preferences (accent + brightness).
      // Living in the same file means the choices travel with the Backup
      // (ADR 0001) at no extra cost.
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (from < 5) {
      // Archive (ADR 0009): a whole-person set-aside flag. 0 = active, 1 = archived.
      await db.execute(
        'ALTER TABLE contacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
      );
    }
  }
}
