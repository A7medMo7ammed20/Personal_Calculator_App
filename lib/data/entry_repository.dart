import '../domain/balance.dart';
import '../domain/currency.dart';
import '../domain/entry.dart';
import '../domain/period.dart';
import 'app_database.dart';
import 'backup_dirty_flag.dart';

/// Reads and writes [Entry]s in SQLite.
///
/// Row mapping lives here so the domain [Entry] stays persistence-agnostic.
/// Entries cascade-delete with their Contact (see [AppDatabase] schema v3).
class EntryRepository {
  // A named param can't be private, so `this._dirty` won't compile; assign the
  // field in the initializer list instead.
  // ignore: prefer_initializing_formals
  EntryRepository(this._appDb, {BackupDirtyFlag? dirty}) : _dirty = dirty;

  static const String table = 'entries';

  /// The four aggregate queries (balances, activity, analysis series, flow
  /// window) count only *active* contacts: an archived contact drops out of
  /// every total while [listByContact] keeps their own ledger intact (#25).
  /// The literal `'contacts'` is used instead of importing [ContactRepository]
  /// to avoid a mutual import.
  static const String _activeContactsOnly =
      'contact_id IN (SELECT id FROM contacts WHERE archived = 0)';

  final AppDatabase _appDb;
  final BackupDirtyFlag? _dirty;

  /// Inserts [entry] and returns it with its assigned [Entry.id].
  Future<Entry> add(Entry entry) async {
    final db = await _appDb.open();
    final id = await db.insert(table, _toRow(entry));
    _dirty?.mark();
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
    _dirty?.mark();
  }

  /// Deletes the Entry with primary key [id].
  Future<void> delete(int id) async {
    final db = await _appDb.open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    _dirty?.mark();
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
      WHERE currency = ? AND $_activeContactsOnly
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
      WHERE currency = ? AND $_activeContactsOnly
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

  /// Entries in one [currency] whose timestamp falls in the half-open [range]
  /// `[start, endExclusive)`. Feeds the home period filter's visibility set and
  /// [[Flow]] header (#7); the [[Balance]] is never computed from this.
  Future<List<Entry>> entriesInRange(Currency currency, DateRange range) async {
    final db = await _appDb.open();
    final rows = await db.query(
      table,
      where: 'currency = ? AND created_at >= ? AND created_at < ? '
          'AND $_activeContactsOnly',
      whereArgs: [
        currency.code,
        range.start.millisecondsSinceEpoch,
        range.endExclusive.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Every Entry in one [currency] across all Contacts, **ascending** by date
  /// (then id), optionally only those strictly before [upTo]. Feeds the Analysis
  /// graph's cumulative series (#8) — the ascending order and the `upTo` bound
  /// let it carry in the opening [[Balance]] from before a window. See ADR 0004.
  Future<List<Entry>> listByCurrency(Currency currency, {DateTime? upTo}) async {
    final db = await _appDb.open();
    final rows = await db.query(
      table,
      where: upTo == null
          ? 'currency = ? AND $_activeContactsOnly'
          : 'currency = ? AND created_at < ? AND $_activeContactsOnly',
      whereArgs: [
        currency.code,
        if (upTo != null) upTo.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at ASC, id ASC',
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
