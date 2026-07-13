import 'balance.dart';
import 'entry.dart';
import 'period.dart';

/// How wide each [BalancePoint]'s calendar bucket is. Chosen from the visible
/// span so the line stays readable at any zoom (see [bucketGranularityForSpanDays]).
enum BucketGranularity { daily, weekly, monthly }

/// Adaptive granularity from a visible span in whole days: `<= 62` daily,
/// `63..400` weekly, `> 400` monthly. See ADR 0004.
BucketGranularity bucketGranularityForSpanDays(int days) {
  if (days <= 62) return BucketGranularity.daily;
  if (days <= 400) return BucketGranularity.weekly;
  return BucketGranularity.monthly;
}

/// One plotted point of the [[Analysis graph]]: the cumulative net [Balance]
/// across all Contacts (in one currency) **as of the end of** [bucket]. The
/// [bucket] is the drill-down interval — feed it to `entriesInRange` +
/// [intervalBreakdown] to list who moved the line. See CONTEXT.md.
class BalancePoint {
  const BalancePoint({required this.bucket, required this.balance});

  /// The half-open calendar interval `[start, endExclusive)` this point covers.
  final DateRange bucket;

  /// Cumulative net position of every Entry dated before [bucket.endExclusive]
  /// — so a bounded window carries in the opening balance, and empty buckets
  /// repeat the prior balance (flat) rather than dropping to zero.
  final Balance balance;
}

/// Builds the cumulative net-balance series for one currency's [entries] over a
/// window. When [range] is null the window is **all time** (first entry → [now]);
/// otherwise it is the bounded period `range`. Granularity is adaptive; buckets
/// are calendar-aligned in local time; [firstDayOfWeek] (1=Mon..7=Sun) sets the
/// weekly boundary so callers can honour the locale. Pure — unit-tested without
/// DB or UI. See ADR 0004.
List<BalancePoint> cumulativeSeries(
  Iterable<Entry> entries, {
  required DateRange? range,
  required DateTime now,
  int firstDayOfWeek = DateTime.monday,
}) {
  final sorted = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final DateTime winStart;
  final DateTime rawEnd;
  if (range != null) {
    winStart = range.start;
    rawEnd = range.endExclusive;
  } else {
    if (sorted.isEmpty) return const [];
    winStart = sorted.first.createdAt;
    rawEnd = now.isAfter(winStart) ? now : winStart.add(const Duration(days: 1));
  }

  final spanDays = rawEnd.difference(winStart).inDays;
  final granularity = bucketGranularityForSpanDays(spanDays < 1 ? 1 : spanDays);

  // A bounded period tiles to its exact end. All time tiles through the bucket
  // that *contains* now, so "today" is always covered even when it lands on a
  // bucket boundary.
  final tilingEnd = range != null
      ? range.endExclusive
      : _nextBucketStart(
          _bucketStartOf(now, granularity, firstDayOfWeek), granularity);

  final points = <BalancePoint>[];
  var running = 0.0;
  var i = 0;
  var start = _bucketStartOf(winStart, granularity, firstDayOfWeek);
  while (start.isBefore(tilingEnd)) {
    final end = _nextBucketStart(start, granularity);
    // Advance through every Entry that lands before this bucket's end, so the
    // running total is the true cumulative position as of the bucket's end.
    while (i < sorted.length && sorted[i].createdAt.isBefore(end)) {
      running += sorted[i].signedAmount;
      i++;
    }
    points.add(BalancePoint(
      bucket: DateRange(start, end),
      balance: Balance(running),
    ));
    start = end;
  }
  return points;
}

DateTime _bucketStartOf(DateTime d, BucketGranularity g, int firstDayOfWeek) {
  switch (g) {
    case BucketGranularity.daily:
      return DateTime(d.year, d.month, d.day);
    case BucketGranularity.weekly:
      final offset = (d.weekday - firstDayOfWeek) % 7;
      final day = DateTime(d.year, d.month, d.day);
      return day.subtract(Duration(days: offset < 0 ? offset + 7 : offset));
    case BucketGranularity.monthly:
      return DateTime(d.year, d.month, 1);
  }
}

DateTime _nextBucketStart(DateTime start, BucketGranularity g) {
  switch (g) {
    case BucketGranularity.daily:
      return DateTime(start.year, start.month, start.day + 1);
    case BucketGranularity.weekly:
      return DateTime(start.year, start.month, start.day + 7);
    case BucketGranularity.monthly:
      return DateTime(start.year, start.month + 1, 1);
  }
}

/// One Contact's net movement within a single drill-down interval (#8). The
/// [delta] is signed like [Entry.signedAmount]: positive raised the line
/// (owed-to-me), negative lowered it (owed-by-me). See CONTEXT.md
/// ([[Analysis graph]]) — the deltas of an interval sum to that segment's rise
/// or fall, so the breakdown always ties back to the line.
class ContactDelta {
  const ContactDelta({required this.contactId, required this.delta});

  final int contactId;
  final double delta;
}

/// Groups one interval's [entries] (already scoped to the bucket and currency by
/// the caller) into a per-Contact net [ContactDelta], sorted by magnitude
/// descending, ties broken by contact id ascending. Pure — unit-tested without
/// DB or UI, like [balanceOf]/[flowTotalsOf].
List<ContactDelta> intervalBreakdown(Iterable<Entry> entries) {
  final byContact = <int, double>{};
  for (final entry in entries) {
    byContact[entry.contactId] =
        (byContact[entry.contactId] ?? 0) + entry.signedAmount;
  }
  final deltas = [
    for (final e in byContact.entries)
      ContactDelta(contactId: e.key, delta: e.value),
  ];
  deltas.sort((a, b) {
    final byMagnitude = b.delta.abs().compareTo(a.delta.abs());
    if (byMagnitude != 0) return byMagnitude;
    return a.contactId.compareTo(b.contactId);
  });
  return deltas;
}
