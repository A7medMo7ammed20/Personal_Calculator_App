import '../domain/balance.dart';
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

  /// A Contact's entries, newest first (by timestamp, then id). Pass a
  /// [currency] to scope to the active lens; omit it to return all currencies.
  Future<List<Entry>> listByContact(int contactId, {Currency? currency}) async {
    final db = await _appDb.open();
    final rows = await db.query(
      table,
      where: currency == null ? 'contact_id = ?' : 'contact_id = ? AND currency = ?',
      whereArgs: [contactId, if (currency != null) currency.code],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Overwrites the stored row identified by [Entry.id] (which must be non-null)
  /// with [entry]'s current values. Edits are in place — no audit trail.
  Future<void> update(Entry entry) async {
    final db = await _appDb.open();
    await db.update(
      table,
      _toRow(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Deletes the Entry with primary key [id].
  Future<void> delete(int id) async {
    final db = await _appDb.open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Per-Contact net [Balance] within one [currency], keyed by contact id.
  /// Contacts with no entries in [currency] are absent from the map. The two
  /// currencies are queried independently and never summed (see CONTEXT.md).
  Future<Map<int, Balance>> balancesByCurrency(Currency currency) async {
    final db = await _appDb.open();
    final rows = await db.rawQuery(
      '''
      SELECT contact_id,
             SUM(CASE WHEN direction = ? THEN amount ELSE -amount END) AS signed
      FROM $table
      WHERE currency = ?
      GROUP BY contact_id
      ''',
      [Direction.owedToMe.code, currency.code],
    );
    return {
      for (final row in rows)
        row['contact_id'] as int: Balance((row['signed'] as num).toDouble()),
    };
  }

  /// Each Contact's most recent Entry date within one [currency] (their
  /// [[Activity]] in that lens), keyed by contact id. Contacts with no entry in
  /// [currency] are absent. Drives the home screen's default sort (#6).
  Future<Map<int, DateTime>> lastActivityByCurrency(Currency currency) async {
    final db = await _appDb.open();
    final rows = await db.rawQuery(
      '''
      SELECT contact_id, MAX(created_at) AS last_at
      FROM $table
      WHERE currency = ?
      GROUP BY contact_id
      ''',
      [currency.code],
    );
    return {
      for (final row in rows)
        row['contact_id'] as int:
            DateTime.fromMillisecondsSinceEpoch(row['last_at'] as int),
    };
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
