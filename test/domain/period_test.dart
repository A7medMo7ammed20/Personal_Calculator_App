import 'package:debt_ledger/domain/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 13, 10, 30);

  test('all time resolves to no range (null)', () {
    expect(resolvePeriod(PeriodOption.allTime, now), isNull);
  });

  test('this month is the current calendar month, half-open', () {
    final r = resolvePeriod(PeriodOption.thisMonth, now)!;
    expect(r.start, DateTime(2026, 7, 1));
    expect(r.endExclusive, DateTime(2026, 8, 1));
  });

  test('last month is the previous calendar month', () {
    final r = resolvePeriod(PeriodOption.lastMonth, now)!;
    expect(r.start, DateTime(2026, 6, 1));
    expect(r.endExclusive, DateTime(2026, 7, 1));
  });

  test('last month wraps the year in January', () {
    final r = resolvePeriod(PeriodOption.lastMonth, DateTime(2026, 1, 9))!;
    expect(r.start, DateTime(2025, 12, 1));
    expect(r.endExclusive, DateTime(2026, 1, 1));
  });

  test('this month wraps the year in December', () {
    final r = resolvePeriod(PeriodOption.thisMonth, DateTime(2026, 12, 5))!;
    expect(r.start, DateTime(2026, 12, 1));
    expect(r.endExclusive, DateTime(2027, 1, 1));
  });

  test('this year is the calendar year, half-open', () {
    final r = resolvePeriod(PeriodOption.thisYear, now)!;
    expect(r.start, DateTime(2026, 1, 1));
    expect(r.endExclusive, DateTime(2027, 1, 1));
  });

  test('custom uses inclusive start and end days', () {
    final r = resolvePeriod(
      PeriodOption.custom,
      now,
      customStart: DateTime(2026, 3, 10, 14), // time-of-day ignored
      customEnd: DateTime(2026, 3, 20, 9),
    )!;
    expect(r.start, DateTime(2026, 3, 10));
    expect(r.endExclusive, DateTime(2026, 3, 21)); // end day fully included
  });

  test('custom without dates falls back to no range', () {
    expect(resolvePeriod(PeriodOption.custom, now), isNull);
  });

  test('DateRange.contains is half-open [start, end)', () {
    final r = DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1));
    expect(r.contains(DateTime(2026, 7, 1)), isTrue); // start inclusive
    expect(r.contains(DateTime(2026, 7, 31, 23, 59)), isTrue);
    expect(r.contains(DateTime(2026, 8, 1)), isFalse); // end exclusive
    expect(r.contains(DateTime(2026, 6, 30, 23, 59)), isFalse);
  });
}
