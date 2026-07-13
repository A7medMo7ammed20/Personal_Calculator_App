import 'package:debt_ledger/domain/balance.dart';
import 'package:debt_ledger/domain/ledger_totals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no balances is a zero total on both sides', () {
    final totals = totalsOf(const []);

    expect(totals.owedToMe, 0);
    expect(totals.owedByMe, 0);
  });

  test('positive contact balances sum into owed-to-me', () {
    final totals = totalsOf(const [Balance(100), Balance(50)]);

    expect(totals.owedToMe, 150);
    expect(totals.owedByMe, 0);
  });

  test('negative contact balances sum (as magnitudes) into owed-by-me', () {
    final totals = totalsOf(const [Balance(-40), Balance(-60)]);

    expect(totals.owedToMe, 0);
    expect(totals.owedByMe, 100);
  });

  test('mixed balances split by sign and never net against each other', () {
    // One contact owes me 100, I owe another 30 — the two grand totals stay
    // separate (not a single net of 70).
    final totals = totalsOf(const [Balance(100), Balance(-30)]);

    expect(totals.owedToMe, 100);
    expect(totals.owedByMe, 30);
  });

  test('settled (zero) balances contribute to neither side', () {
    final totals = totalsOf(const [Balance(0), Balance(80), Balance(0)]);

    expect(totals.owedToMe, 80);
    expect(totals.owedByMe, 0);
  });
}
