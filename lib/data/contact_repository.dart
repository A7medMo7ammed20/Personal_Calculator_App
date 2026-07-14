import '../domain/contact.dart';
import 'app_database.dart';
import 'backup_dirty_flag.dart';
import 'entry_repository.dart';

/// Reads and writes [Contact]s in SQLite.
///
/// Row mapping lives here so the domain [Contact] stays persistence-agnostic.
class ContactRepository {
  ContactRepository(this._appDb, {BackupDirtyFlag? dirty}) : _dirty = dirty;

  static const String table = 'contacts';

  final AppDatabase _appDb;
  final BackupDirtyFlag? _dirty;

  /// Inserts [contact] and returns it with its assigned [Contact.id].
  Future<Contact> add(Contact contact) async {
    final db = await _appDb.open();
    final id = await db.insert(table, _toRow(contact));
    _dirty?.mark();
    return contact.copyWith(id: id);
  }

  /// Active (non-archived) contacts, newest first. The home screen re-sorts/
  /// filters this in the domain layer (see `sortContacts` / `filterContacts`,
  /// #6). Archived contacts are excluded here and surface via [listArchived].
  Future<List<Contact>> list() async {
    final db = await _appDb.open();
    final rows = await db.query(table, where: 'archived = 0', orderBy: 'id DESC');
    return rows.map(_fromRow).toList();
  }

  /// Archived contacts only, newest first — the Archived view (#25).
  Future<List<Contact>> listArchived() async {
    final db = await _appDb.open();
    final rows = await db.query(table, where: 'archived = 1', orderBy: 'id DESC');
    return rows.map(_fromRow).toList();
  }

  /// Sets the archived flag on the Contact with primary key [id]. Archiving
  /// hides the whole person from the active list and the grand totals while
  /// preserving their ledger; unarchiving restores them.
  Future<void> setArchived(int id, {required bool archived}) async {
    final db = await _appDb.open();
    await db.update(
      table,
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _dirty?.mark();
  }

  /// Overwrites the stored row identified by [Contact.id] with [contact]'s
  /// current name and phone.
  Future<void> update(Contact contact) async {
    final db = await _appDb.open();
    await db.update(
      table,
      _toRow(contact),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
    _dirty?.mark();
  }

  /// Deletes the Contact with primary key [id]. Its Entries cascade-delete
  /// (see [AppDatabase] schema v3, foreign keys on).
  Future<void> delete(int id) async {
    final db = await _appDb.open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    _dirty?.mark();
  }

  /// How many Entries this Contact has, across all currencies — used to warn
  /// before a cascade delete.
  Future<int> entryCount(int contactId) async {
    final db = await _appDb.open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${EntryRepository.table} WHERE contact_id = ?',
      [contactId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Map<String, Object?> _toRow(Contact c) => {
    'name': c.name,
    'phone': c.phone,
    'archived': c.archived ? 1 : 0,
  };

  Contact _fromRow(Map<String, Object?> row) => Contact(
    id: row['id'] as int,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    archived: (row['archived'] as int? ?? 0) == 1,
  );
}
