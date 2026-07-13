import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/running_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e({
  required int id,
  required Direction direction,
  required double amount,
  required DateTime when,
}) => Entry(
  id: id,
  contactId: 1,
  amount: amount,
  direction: direction,
  currency: Currency.sar,
  createdAt: when,
);

void main() {
  test('empty entries produce no rows', () {
    expect(runningSummary(const []), isEmpty);
  });

  test('single owed-to-me entry: gross to-me and net both equal the amount', () {
    final rows = runningSummary([
      e(id: 1, direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 3, 1)),
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.cumulativeOwedToMe, 200);
    expect(rows.single.cumulativeOwedByMe, 0);
    expect(rows.single.balance.signed, 200);
  });

  test('orders ascending by date and accumulates each direction grossly', () {
    // Deliberately out of order in the input.
    final rows = runningSummary([
      e(id: 3, direction: Direction.owedToMe, amount: 190, when: DateTime(2026, 3, 3)),
      e(id: 1, direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 3, 1)),
      e(id: 2, direction: Direction.owedByMe, amount: 50, when: DateTime(2026, 3, 2)),
    ]);

    expect(rows.map((r) => r.entry.id), [1, 2, 3]);
    // Gross running totals up to each row.
    expect(rows[0].cumulativeOwedToMe, 200);
    expect(rows[0].cumulativeOwedByMe, 0);
    expect(rows[1].cumulativeOwedToMe, 200);
    expect(rows[1].cumulativeOwedByMe, 50);
    expect(rows[2].cumulativeOwedToMe, 390);
    expect(rows[2].cumulativeOwedByMe, 50);
    // Net balance after the last row: 390 - 50 = 340 owed-to-me.
    expect(rows[2].balance.signed, 340);
    expect(rows[2].balance.isOwedToMe, isTrue);
  });

  test('a repayment can cross the balance to settled', () {
    final rows = runningSummary([
      e(id: 1, direction: Direction.owedToMe, amount: 100, when: DateTime(2026, 3, 1)),
      e(id: 2, direction: Direction.owedByMe, amount: 100, when: DateTime(2026, 3, 2)),
    ]);

    expect(rows.last.cumulativeOwedToMe, 100);
    expect(rows.last.cumulativeOwedByMe, 100);
    expect(rows.last.balance.isSettled, isTrue);
  });

  test('same-timestamp entries tie-break by id', () {
    final when = DateTime(2026, 3, 5);
    final rows = runningSummary([
      e(id: 2, direction: Direction.owedToMe, amount: 5, when: when),
      e(id: 1, direction: Direction.owedToMe, amount: 5, when: when),
    ]);

    expect(rows.map((r) => r.entry.id), [1, 2]);
  });
}
