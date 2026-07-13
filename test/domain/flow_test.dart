import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/flow.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e(Direction direction, double amount) => Entry(
  contactId: 1,
  amount: amount,
  direction: direction,
  currency: Currency.sar,
  createdAt: DateTime(2026, 7, 1),
);

void main() {
  test('sums lent and received grossly, without netting within a contact', () {
    final flow = flowTotalsOf([
      e(Direction.owedToMe, 1000),
      e(Direction.owedByMe, 300), // a repayment in the same window
      e(Direction.owedToMe, 500),
    ]);
    expect(flow.lent, 1500);
    expect(flow.received, 300);
  });

  test('no entries is zero flow', () {
    expect(flowTotalsOf(const []), Flow.zero);
  });

  test('only owed-by-me entries produce received with zero lent', () {
    final flow = flowTotalsOf([e(Direction.owedByMe, 40), e(Direction.owedByMe, 60)]);
    expect(flow.lent, 0);
    expect(flow.received, 100);
  });
}
