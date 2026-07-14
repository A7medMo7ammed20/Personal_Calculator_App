import 'balance.dart';
import 'contact.dart';
import 'currency.dart';
import 'entry.dart';
import 'period.dart';
import 'profile.dart';
import 'running_summary.dart';

/// One printed line of a [StatementDocument]: a dated entry with its amount on
/// exactly one directional column and the true, all-time running [Balance]
/// after it. See CONTEXT.md ([[Statement]]).
class StatementRow {
  const StatementRow({
    required this.date,
    required this.description,
    required this.direction,
    required this.amount,
    required this.balance,
  });

  final DateTime date;
  final String? description;
  final Direction direction;

  /// Positive magnitude of the entry; the column is chosen by [direction].
  final double amount;

  /// Net running balance after this row — never recomputed over a window.
  final Balance balance;

  /// The amount when this row is an owed-to-me entry, else `null` (blank cell).
  double? get owedToMe => direction == Direction.owedToMe ? amount : null;

  /// The amount when this row is an owed-by-me entry, else `null` (blank cell).
  double? get owedByMe => direction == Direction.owedByMe ? amount : null;
}

/// A library-agnostic model of a per-Contact, per-currency PDF [[Statement]].
/// Pure data — no `pdf`/Flutter types — so it is unit-tested without rendering
/// (see statement_test.dart); a separate renderer turns it into a PDF.
///
/// Under a date range the [rows] are clipped in view but the balance is never
/// recomputed: [openingBalance] carries the true position from before the
/// range, the per-row and [closingBalance] figures stay all-time, and only
/// [totalOwedToMe]/[totalOwedByMe] cover the in-range activity — so
/// `opening + (totalOwedToMe − totalOwedByMe) == closing`. Mirrors ADR 0004.
class StatementDocument {
  const StatementDocument({
    required this.creditorName,
    required this.contactName,
    required this.contactPhone,
    required this.currency,
    required this.dateRange,
    required this.isRtl,
    required this.openingBalance,
    required this.rows,
    required this.totalOwedToMe,
    required this.totalOwedByMe,
    required this.closingBalance,
  });

  /// The owner's name (from the [Profile]) printed as the creditor.
  final String creditorName;

  final String contactName;
  final String? contactPhone;
  final Currency currency;

  /// The applied window, or `null` for an all-time statement.
  final DateRange? dateRange;

  /// True when the document lays out right-to-left (Arabic).
  final bool isRtl;

  /// True running balance just before the window (Balance(0) at all time).
  final Balance openingBalance;

  final List<StatementRow> rows;

  /// Gross sum of the in-range owed-to-me amounts.
  final double totalOwedToMe;

  /// Gross sum of the in-range owed-by-me amounts.
  final double totalOwedByMe;

  /// True all-time balance at the last in-range entry (or [openingBalance] when
  /// the window holds no entries).
  final Balance closingBalance;
}

/// Builds a [StatementDocument] from the full, single-currency [entries] (the
/// all-time history). Reuses the pure [runningSummary] seam — the same series
/// behind the on-screen preview and the Analysis graph — then clips to [range]
/// in view while carrying in the opening balance. Pure function: no DB, no UI.
StatementDocument buildStatement({
  required Profile profile,
  required Contact contact,
  required Iterable<Entry> entries,
  required Currency currency,
  required DateRange? range,
  required bool isRtl,
}) {
  final series = runningSummary(entries); // ascending, cumulative, all-time

  final inRange = range == null
      ? series
      : series.where((r) => range.contains(r.entry.createdAt)).toList();

  // Opening balance: the running position of the last entry strictly before
  // the window (0 at all time or when nothing precedes the window).
  Balance opening = const Balance(0);
  if (range != null) {
    for (final r in series) {
      if (r.entry.createdAt.isBefore(range.start)) {
        opening = r.balance;
      } else {
        break; // series is ascending — nothing later is "before"
      }
    }
  }

  var totalOwedToMe = 0.0;
  var totalOwedByMe = 0.0;
  final rows = <StatementRow>[];
  for (final r in inRange) {
    final e = r.entry;
    if (e.direction == Direction.owedToMe) {
      totalOwedToMe += e.amount;
    } else {
      totalOwedByMe += e.amount;
    }
    rows.add(StatementRow(
      date: e.createdAt,
      description: e.description,
      direction: e.direction,
      amount: e.amount,
      balance: r.balance,
    ));
  }

  final closing = inRange.isEmpty ? opening : inRange.last.balance;

  return StatementDocument(
    creditorName: profile.name,
    contactName: contact.name,
    contactPhone: contact.phone,
    currency: currency,
    dateRange: range,
    isRtl: isRtl,
    openingBalance: opening,
    rows: rows,
    totalOwedToMe: totalOwedToMe,
    totalOwedByMe: totalOwedByMe,
    closingBalance: closing,
  );
}
