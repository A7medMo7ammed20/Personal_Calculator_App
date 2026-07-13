import 'balance.dart';
import 'entry.dart';

/// One line of a running summary: an [Entry] plus the gross cumulative totals
/// **up to and including** it and the net [Balance] after it. The two gross
/// totals mirror the PDF Statement's owed-to-me / owed-by-me columns; this is
/// the on-screen statement preview and the pure seam the Analysis graph (#8)
/// and Statement (#10) reuse. See CONTEXT.md.
class RunningSummaryRow {
  const RunningSummaryRow({
    required this.entry,
    required this.cumulativeOwedToMe,
    required this.cumulativeOwedByMe,
    required this.balance,
  });

  final Entry entry;

  /// Gross sum of all owed-to-me amounts up to and including [entry].
  final double cumulativeOwedToMe;

  /// Gross sum of all owed-by-me amounts up to and including [entry].
  final double cumulativeOwedByMe;

  /// Net position after [entry]: [cumulativeOwedToMe] − [cumulativeOwedByMe].
  final Balance balance;
}

/// Builds the date-ascending running summary over [entries] (already scoped to
/// one currency). Ties on timestamp break by [Entry.id]. Pure function — no DB,
/// no UI — exercised directly in unit tests like [balanceOf]/[totalsOf].
List<RunningSummaryRow> runningSummary(Iterable<Entry> entries) {
  final sorted = [...entries]..sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      if (byDate != 0) return byDate;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

  var owedToMe = 0.0;
  var owedByMe = 0.0;
  final rows = <RunningSummaryRow>[];
  for (final entry in sorted) {
    if (entry.direction == Direction.owedToMe) {
      owedToMe += entry.amount;
    } else {
      owedByMe += entry.amount;
    }
    rows.add(RunningSummaryRow(
      entry: entry,
      cumulativeOwedToMe: owedToMe,
      cumulativeOwedByMe: owedByMe,
      balance: Balance(owedToMe - owedByMe),
    ));
  }
  return rows;
}
