import '../domain/contact.dart';
import 'app_database.dart';
import 'entry_repository.dart';

/// Reads and writes [Contact]s in SQLite.
///
/// Row mapping lives here so the domain [Contact] stays persistence-agnostic.
class ContactRepository {
  ContactRepository(this._appDb);

  static const String table = 'contacts';

  final AppDatabase _appDb;

  /// Inserts [contact] and returns it with its assigned [Contact.id].
  Future<Contact> add(Contact contact) async {
    final db = await _appDb.open();
    final id = await db.insert(table, _toRow(contact));
    return contact.copyWith(id: id);
  }

  /// All contacts, newest first (later slices add sort-by-activity, #6).
  Future<List<Contact>> list() async {
    final db = await _appDb.open();
    final rows = await db.query(table, orderBy: 'id DESC');
    return rows.map(_fromRow).toList();
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
  }

  /// Deletes the Contact with primary key [id]. Its Entries cascade-delete
  /// (see [AppDatabase] schema v3, foreign keys on).
  Future<void> delete(int id) async {
    final db = await _appDb.open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
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
  };

  Contact _fromRow(Map<String, Object?> row) => Contact(
    id: row['id'] as int,
    name: row['name'] as String,
    phone: row['phone'] as String?,
  );
}
