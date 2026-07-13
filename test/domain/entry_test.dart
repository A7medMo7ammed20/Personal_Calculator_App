import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 13, 10, 30);

  Entry entry({
    Direction direction = Direction.owedToMe,
    double amount = 100,
  }) => Entry(
    contactId: 1,
    amount: amount,
    direction: direction,
    currency: Currency.sar,
    createdAt: now,
  );

  test('owed-to-me entry has a positive signed amount', () {
    expect(entry(direction: Direction.owedToMe, amount: 100).signedAmount, 100);
  });

  test('owed-by-me entry has a negative signed amount', () {
    expect(entry(direction: Direction.owedByMe, amount: 100).signedAmount, -100);
  });

  test('copyWith replaces only the given fields', () {
    final original = entry();
    final updated = original.copyWith(id: 7, amount: 250);

    expect(updated.id, 7);
    expect(updated.amount, 250);
    expect(updated.direction, original.direction);
    expect(updated.contactId, original.contactId);
    expect(updated.createdAt, original.createdAt);
  });

  test('value equality holds for identical entries', () {
    expect(entry(), entry());
    expect(entry().hashCode, entry().hashCode);
  });

  test('entries differing by direction are not equal', () {
    expect(
      entry(direction: Direction.owedToMe),
      isNot(entry(direction: Direction.owedByMe)),
    );
  });

  test('Direction round-trips through its persisted code', () {
    for (final d in Direction.values) {
      expect(Direction.fromCode(d.code), d);
    }
  });
}
