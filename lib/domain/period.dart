/// The home/analysis time-range selector (#7). See CONTEXT.md ([[Period filter]]).
///
/// On home it is a **visibility** filter (which Contacts appear) plus a [[Flow]]
/// header — it never touches a Contact's all-time [[Balance]].
enum PeriodOption { allTime, thisMonth, lastMonth, thisYear, custom }

/// A half-open time window `[start, endExclusive)` in local time.
class DateRange {
  const DateRange(this.start, this.endExclusive);

  final DateTime start;
  final DateTime endExclusive;

  /// True when [when] falls in `[start, endExclusive)` — start inclusive, end
  /// exclusive, so adjacent ranges never double-count a boundary instant.
  bool contains(DateTime when) =>
      !when.isBefore(start) && when.isBefore(endExclusive);

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);
}

/// Resolves [option] to a concrete [DateRange] relative to [now] (passed in so
/// the calculation stays pure and testable). Returns `null` for
/// [PeriodOption.allTime] — and for [PeriodOption.custom] until both
/// [customStart] and [customEnd] are chosen. Calendar periods are half-open;
/// custom includes both the start and end **days** in full.
DateRange? resolvePeriod(
  PeriodOption option,
  DateTime now, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  switch (option) {
    case PeriodOption.allTime:
      return null;
    case PeriodOption.thisMonth:
      return DateRange(
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1),
      );
    case PeriodOption.lastMonth:
      return DateRange(
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 1),
      );
    case PeriodOption.thisYear:
      return DateRange(
        DateTime(now.year, 1, 1),
        DateTime(now.year + 1, 1, 1),
      );
    case PeriodOption.custom:
      if (customStart == null || customEnd == null) return null;
      return DateRange(day(customStart), day(customEnd).add(const Duration(days: 1)));
  }
}
