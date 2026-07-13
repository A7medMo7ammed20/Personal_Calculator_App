import '../domain/currency.dart';
import '../domain/entry.dart';
import 'app_database.dart';

/// Reads and writes [Entry]s in SQLite.
///
/// Row mapping lives here so the domain [Entry] stays persistence-agnostic.
/// Entries cascade-delete with their Contact (see [AppDatabase] schema v3).
class EntryRepository {
  EntryRepository(this._appDb);

  static const String table = 'entries';

  final AppDatabase _appDb;

  /// Inserts [entry] and returns it with its assigned [Entry.id].
  Future<Entry> add(Entry entry) async {
    final db = await _appDb.open();
    final id = await db.insert(table, _toRow(entry));
    return entry.copyWith(id: id);
  }

  /// A Contact's entries, newest first (by timestamp, then id).
  Future<List<Entry>> listByContact(int contactId) async {
    final db = await _appDb.open();
    final rows = await db.query(
      table,
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Map<String, Object?> _toRow(Entry e) => {
    'contact_id': e.contactId,
    'amount': e.amount,
    'direction': e.direction.code,
    'currency': e.currency.code,
    'created_at': e.createdAt.millisecondsSinceEpoch,
    'description': e.description,
  };

  Entry _fromRow(Map<String, Object?> row) => Entry(
    id: row['id'] as int,
    contactId: row['contact_id'] as int,
    amount: (row['amount'] as num).toDouble(),
    direction: Direction.fromCode(row['direction'] as String),
    currency: Currency.fromCode(row['currency'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    description: row['description'] as String?,
  );
}
