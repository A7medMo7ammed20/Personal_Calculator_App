import 'package:debt_ledger/domain/analysis_graph.dart';
import 'package:debt_ledger/domain/balance.dart';
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
  group('runningBalanceSeries', () {
    test('no entries produce an empty series', () {
      expect(runningBalanceSeries(const []), isEmpty);
    });

    test('one point per entry, cumulative, oldest to newest', () {
      final series = runningBalanceSeries([
        e(direction: Direction.owedToMe, amount: 300, when: DateTime(2026, 3, 5)),
        e(direction: Direction.owedByMe, amount: 100, when: DateTime(2026, 5, 12)),
        e(direction: Direction.owedToMe, amount: 50, when: DateTime(2026, 6, 1)),
      ]);

      // One vertex per entry — not per calendar day.
      expect(series, hasLength(3));
      expect(series.map((p) => p.balance.signed), [300, 200, 250]);
      // Ordered oldest to newest.
      for (var i = 1; i < series.length; i++) {
        expect(
          series[i].entry.createdAt.isBefore(series[i - 1].entry.createdAt),
          isFalse,
        );
      }
    });

    test('same-day entries each get their own point (no collapse)', () {
      final day = DateTime(2026, 7, 13, 10);
      final series = runningBalanceSeries([
        e(id: 1, direction: Direction.owedToMe, amount: 100, when: day),
        e(id: 2, direction: Direction.owedToMe, amount: 100, when: day),
        e(id: 3, direction: Direction.owedToMe, amount: 100, when: day),
      ]);

      // Eleven same-day entries would have collapsed to a single dot before;
      // now every entry is its own vertex.
      expect(series, hasLength(3));
      expect(series.map((p) => p.balance.signed), [100, 200, 300]);
    });

    test('bounded range carries in the opening balance from before the window', () {
      final series = runningBalanceSeries(
        [
          // Before the window — establishes the +5000 opening position.
          e(direction: Direction.owedToMe, amount: 5000, when: DateTime(2026, 6, 20)),
          // Inside the window — a repayment drops the line to +4000.
          e(direction: Direction.owedByMe, amount: 1000, when: DateTime(2026, 7, 10)),
        ],
        range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      );

      // Only the in-window entry is plotted...
      expect(series, hasLength(1));
      expect(series.single.entry.createdAt, DateTime(2026, 7, 10));
      // ...but its balance carries in the pre-window +5000 (5000 - 1000).
      expect(series.single.balance.signed, 4000);
    });

    test('bounded range excludes entries after the window', () {
      final series = runningBalanceSeries(
        [
          e(direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 7, 5)),
          e(direction: Direction.owedToMe, amount: 999, when: DateTime(2026, 9, 1)),
        ],
        range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      );

      expect(series, hasLength(1));
      expect(series.single.balance.signed, 200);
    });
  });

  group('contactBalancesSorted', () {
    test('empty map produces no bars', () {
      expect(contactBalancesSorted(const {}), isEmpty);
    });

    test('sorts by magnitude descending, keeping the sign', () {
      final bars = contactBalancesSorted({
        1: const Balance(200),
        2: const Balance(-900),
        3: const Balance(500),
      });

      expect(bars.map((b) => b.contactId), [2, 3, 1]);
      expect(bars.map((b) => b.balance.signed), [-900, 500, 200]);
    });

    test('excludes settled contacts', () {
      final bars = contactBalancesSorted({
        1: const Balance(300),
        2: const Balance(0),
        3: const Balance(0.001), // below the settled epsilon
      });

      expect(bars.map((b) => b.contactId), [1]);
    });

    test('equal magnitude ties break by contact id ascending', () {
      final bars = contactBalancesSorted({
        5: const Balance(100),
        2: const Balance(-100),
      });

      expect(bars.map((b) => b.contactId), [2, 5]);
    });
  });
}
