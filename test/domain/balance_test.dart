import 'package:debt_ledger/domain/balance.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 13);

  Entry entry(Direction direction, double amount) => Entry(
    contactId: 1,
    amount: amount,
    direction: direction,
    currency: Currency.sar,
    createdAt: now,
  );

  test('empty ledger is a settled zero balance', () {
    final balance = balanceOf(const []);

    expect(balance.signed, 0);
    expect(balance.magnitude, 0);
    expect(balance.isSettled, isTrue);
  });

  test('a single owed-to-me entry is a positive balance', () {
    final balance = balanceOf([entry(Direction.owedToMe, 100)]);

    expect(balance.signed, 100);
    expect(balance.magnitude, 100);
    expect(balance.isOwedToMe, isTrue);
    expect(balance.isSettled, isFalse);
  });

  test('mixed directions net against each other', () {
    final balance = balanceOf([
      entry(Direction.owedToMe, 100),
      entry(Direction.owedByMe, 30),
    ]);

    expect(balance.signed, 70);
    expect(balance.isOwedToMe, isTrue);
  });

  test('equal opposite entries settle to zero (repayment)', () {
    final balance = balanceOf([
      entry(Direction.owedToMe, 100),
      entry(Direction.owedByMe, 100),
    ]);

    expect(balance.signed, 0);
    expect(balance.isSettled, isTrue);
  });

  test('owed-by-me exceeding owed-to-me is a negative balance', () {
    final balance = balanceOf([
      entry(Direction.owedToMe, 40),
      entry(Direction.owedByMe, 100),
    ]);

    expect(balance.signed, -60);
    expect(balance.magnitude, 60);
    expect(balance.isOwedToMe, isFalse);
    expect(balance.isSettled, isFalse);
  });

  test('decimal amounts net without visible drift at cent precision', () {
    final balance = balanceOf([
      entry(Direction.owedToMe, 10.10),
      entry(Direction.owedToMe, 20.20),
      entry(Direction.owedByMe, 0.30),
    ]);

    expect(balance.magnitude, closeTo(30.00, 0.0001));
  });
}
