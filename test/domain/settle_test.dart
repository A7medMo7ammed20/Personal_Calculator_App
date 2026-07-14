import 'package:debt_ledger/domain/balance.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/settle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final when = DateTime(2026, 7, 14, 12);

  test('owed-to-me balance settles with an owed-by-me entry of equal magnitude', () {
    final settle = buildSettleEntry(
      contactId: 7,
      balance: const Balance(300),
      currency: Currency.sar,
      createdAt: when,
      description: 'تسوية',
    )!;
    expect(settle.contactId, 7);
    expect(settle.direction, Direction.owedByMe);
    expect(settle.amount, 300);
    expect(settle.currency, Currency.sar);
    expect(settle.createdAt, when);
    expect(settle.description, 'تسوية');
    final history = Entry(
      contactId: 7,
      amount: 300,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(balanceOf([history, settle]).isSettled, isTrue);
  });

  test('owed-by-me balance settles with an owed-to-me entry', () {
    final settle = buildSettleEntry(
      contactId: 1, balance: const Balance(-42.5), currency: Currency.yer,
      createdAt: when, description: 'تسوية')!;
    expect(settle.direction, Direction.owedToMe);
    expect(settle.amount, 42.5);
    expect(settle.currency, Currency.yer);
  });

  test('a settled balance yields no settle entry', () {
    expect(
      buildSettleEntry(contactId: 1, balance: const Balance(0), currency: Currency.sar, createdAt: when, description: 'تسوية'),
      isNull,
    );
  });
}
