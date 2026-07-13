import 'package:debt_ledger/domain/analysis_graph.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/period.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e({
  int? id,
  int contactId = 1,
  required Direction direction,
  required double amount,
  required DateTime when,
}) => Entry(
  id: id,
  contactId: contactId,
  amount: amount,
  direction: direction,
  currency: Currency.sar,
  createdAt: when,
);

void main() {
  group('intervalBreakdown', () {
    test('empty interval produces no deltas', () {
      expect(intervalBreakdown(const []), isEmpty);
    });

    test('collapses a contact\'s entries into one net delta', () {
      final deltas = intervalBreakdown([
        e(contactId: 7, direction: Direction.owedToMe, amount: 1000, when: DateTime(2026, 3, 1)),
        e(contactId: 7, direction: Direction.owedByMe, amount: 300, when: DateTime(2026, 3, 2)),
      ]);

      expect(deltas, hasLength(1));
      expect(deltas.single.contactId, 7);
      // +1000 owed-to-me, -300 owed-by-me => net +700.
      expect(deltas.single.delta, 700);
    });

    test('one row per contact, sorted by magnitude descending', () {
      final deltas = intervalBreakdown([
        e(contactId: 1, direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 3, 1)),
        e(contactId: 2, direction: Direction.owedByMe, amount: 900, when: DateTime(2026, 3, 1)),
        e(contactId: 3, direction: Direction.owedToMe, amount: 500, when: DateTime(2026, 3, 1)),
      ]);

      expect(deltas.map((d) => d.contactId), [2, 3, 1]);
      expect(deltas.map((d) => d.delta), [-900, 500, 200]);
    });

    test('deltas sum to the interval net movement', () {
      final entries = [
        e(contactId: 1, direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 3, 1)),
        e(contactId: 2, direction: Direction.owedByMe, amount: 900, when: DateTime(2026, 3, 1)),
        e(contactId: 3, direction: Direction.owedToMe, amount: 500, when: DateTime(2026, 3, 1)),
      ];
      final total = intervalBreakdown(entries).fold<double>(0, (s, d) => s + d.delta);
      // 200 - 900 + 500 = -200.
      expect(total, -200);
    });

    test('equal-magnitude deltas tie-break by contact id ascending', () {
      final deltas = intervalBreakdown([
        e(contactId: 5, direction: Direction.owedToMe, amount: 100, when: DateTime(2026, 3, 1)),
        e(contactId: 2, direction: Direction.owedByMe, amount: 100, when: DateTime(2026, 3, 1)),
      ]);

      expect(deltas.map((d) => d.contactId), [2, 5]);
    });
  });

  group('bucketGranularityForSpanDays', () {
    test('<= 62 days is daily', () {
      expect(bucketGranularityForSpanDays(1), BucketGranularity.daily);
      expect(bucketGranularityForSpanDays(62), BucketGranularity.daily);
    });

    test('63..400 days is weekly', () {
      expect(bucketGranularityForSpanDays(63), BucketGranularity.weekly);
      expect(bucketGranularityForSpanDays(400), BucketGranularity.weekly);
    });

    test('> 400 days is monthly', () {
      expect(bucketGranularityForSpanDays(401), BucketGranularity.monthly);
      expect(bucketGranularityForSpanDays(4000), BucketGranularity.monthly);
    });
  });

  group('cumulativeSeries', () {
    test('no entries produce an empty series at all time', () {
      expect(
        cumulativeSeries(const [], range: null, now: DateTime(2026, 7, 13)),
        isEmpty,
      );
    });

    test('bounded month: daily buckets carrying in the opening balance', () {
      final series = cumulativeSeries(
        [
          // Before the window — establishes the +5000 opening position.
          e(direction: Direction.owedToMe, amount: 5000, when: DateTime(2026, 6, 20)),
          // Inside the window — a repayment drops the line to +4000.
          e(direction: Direction.owedByMe, amount: 1000, when: DateTime(2026, 7, 10)),
        ],
        range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
        now: DateTime(2026, 7, 31, 12),
      );

      // One point per calendar day of July.
      expect(series, hasLength(31));
      expect(series.first.bucket.start, DateTime(2026, 7, 1));
      expect(series.last.bucket.endExclusive, DateTime(2026, 8, 1));
      // Left edge carries in the true pre-window position, not zero.
      expect(series.first.balance.signed, 5000);
      // After the July 10 repayment the line sits at +4000 for the rest.
      expect(series.last.balance.signed, 4000);
    });

    test('empty buckets carry the balance forward (flat, never zero)', () {
      final series = cumulativeSeries(
        [
          e(direction: Direction.owedToMe, amount: 5000, when: DateTime(2026, 6, 20)),
          e(direction: Direction.owedByMe, amount: 1000, when: DateTime(2026, 7, 10)),
        ],
        range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
        now: DateTime(2026, 7, 31, 12),
      );

      // Day 9 (before the repayment) still holds the opening balance...
      final day9 = series.firstWhere((p) => p.bucket.start == DateTime(2026, 7, 9));
      expect(day9.balance.signed, 5000);
      // ...and every day from the 10th onward is flat at +4000, no drop to zero.
      final after = series.where((p) => !p.bucket.start.isBefore(DateTime(2026, 7, 10)));
      expect(after.every((p) => p.balance.signed == 4000), isTrue);
    });

    test('all time spans first-entry to now and ends at the true balance', () {
      final series = cumulativeSeries(
        [
          e(direction: Direction.owedToMe, amount: 300, when: DateTime(2026, 3, 5)),
          e(direction: Direction.owedByMe, amount: 100, when: DateTime(2026, 5, 12)),
        ],
        range: null,
        now: DateTime(2026, 7, 13),
      );

      expect(series, isNotEmpty);
      // First bucket starts on/before the first entry; window covers now.
      expect(series.first.bucket.start.isAfter(DateTime(2026, 3, 5)), isFalse);
      expect(series.last.bucket.endExclusive.isAfter(DateTime(2026, 7, 13)), isTrue);
      // Cumulative to now includes everything: 300 - 100 = 200.
      expect(series.last.balance.signed, 200);
    });

    test('a single entry still renders a valid series', () {
      final series = cumulativeSeries(
        [e(direction: Direction.owedToMe, amount: 750, when: DateTime(2026, 4, 2))],
        range: null,
        now: DateTime(2026, 4, 20),
      );

      expect(series, isNotEmpty);
      expect(series.last.balance.signed, 750);
    });

    test('points are ordered oldest to newest', () {
      final series = cumulativeSeries(
        [
          e(direction: Direction.owedToMe, amount: 100, when: DateTime(2026, 2, 1)),
          e(direction: Direction.owedToMe, amount: 100, when: DateTime(2026, 6, 1)),
        ],
        range: null,
        now: DateTime(2026, 7, 13),
      );

      for (var i = 1; i < series.length; i++) {
        expect(series[i].bucket.start.isAfter(series[i - 1].bucket.start), isTrue);
      }
    });
  });
}
