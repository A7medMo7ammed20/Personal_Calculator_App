import '../domain/contact.dart';
import 'app_database.dart';

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
