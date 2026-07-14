import 'balance.dart';
import 'entry.dart';
import 'period.dart';
import 'running_summary.dart';

/// One plotted vertex of the [[Analysis graph]]'s "over time" line: the
/// cumulative net [Balance] across all Contacts (in one currency) **as of** its
/// [entry]. One point per Entry — not per calendar bucket — so same-day entries
/// each stay visible instead of collapsing to a single dot. See CONTEXT.md and
/// ADR 0004.
class BalancePoint {
  const BalancePoint({required this.entry, required this.balance});

  /// The Entry this vertex sits on — its date and signed amount drive the
  /// drill-down.
  final Entry entry;

  /// Cumulative net position of every Entry up to and including [entry] — so a
  /// bounded window inherently carries in the opening balance.
  final Balance balance;
}

/// Builds the per-entry cumulative net-balance series for one currency's
/// [entries]. Reuses the [runningSummary] seam (ascending, cumulative), then —
/// when [range] is non-null — keeps only the points whose Entry falls in the
/// window. The running total still accumulates across pre-window entries, so the
/// leftmost in-window point carries in the true opening [[Balance]] rather than
/// resetting to zero (the balance is clipped in view, never recomputed). Pure —
/// unit-tested without DB or UI. See ADR 0004.
List<BalancePoint> runningBalanceSeries(
  Iterable<Entry> entries, {
  DateRange? range,
}) {
  final points = <BalancePoint>[];
  for (final row in runningSummary(entries)) {
    if (range != null && !range.contains(row.entry.createdAt)) continue;
    points.add(BalancePoint(entry: row.entry, balance: row.balance));
  }
  return points;
}

/// One contact's net [Balance] in the "by contact" bar chart. The [balance]
/// keeps its sign so the bar can diverge either side of zero (owed-to-me vs
/// owed-by-me). See CONTEXT.md ([[Analysis graph]]).
class ContactBalance {
  const ContactBalance({required this.contactId, required this.balance});

  final int contactId;
  final Balance balance;
}

/// Turns per-contact [balances] (e.g. `EntryRepository.balancesByCurrency`) into
/// the bar list: settled contacts dropped, sorted by [Balance.magnitude]
/// descending, ties broken by contact id ascending. All-time — the bars are a
/// snapshot, never windowed (CONTEXT.md's golden rule). Pure — unit-tested
/// without DB or UI, like [balanceOf].
List<ContactBalance> contactBalancesSorted(Map<int, Balance> balances) {
  final bars = [
    for (final entry in balances.entries)
      if (!entry.value.isSettled)
        ContactBalance(contactId: entry.key, balance: entry.value),
  ];
  bars.sort((a, b) {
    final byMagnitude = b.balance.magnitude.compareTo(a.balance.magnitude);
    if (byMagnitude != 0) return byMagnitude;
    return a.contactId.compareTo(b.contactId);
  });
  return bars;
}
