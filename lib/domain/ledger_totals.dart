import 'balance.dart';

/// The two per-currency grand totals shown in the home header: how much is owed
/// **to me** and how much **I owe**, summed across all Contacts in one currency.
///
/// The two sides never net against each other — they are reported separately.
/// See CONTEXT.md (Currency lens).
class LedgerTotals {
  const LedgerTotals({required this.owedToMe, required this.owedByMe});

  /// Sum of the positive (owed-to-me) Contact balances.
  final double owedToMe;

  /// Sum of the magnitudes of the negative (owed-by-me) Contact balances.
  final double owedByMe;

  static const LedgerTotals zero = LedgerTotals(owedToMe: 0, owedByMe: 0);
}

/// Aggregates per-Contact [balances] (already scoped to one currency) into the
/// two home-header totals. Each Contact's net balance lands on exactly one side:
/// positive → owed-to-me, negative → owed-by-me, settled → neither. Pure
/// function so the split is unit-testable without DB or UI.
LedgerTotals totalsOf(Iterable<Balance> balances) {
  var owedToMe = 0.0;
  var owedByMe = 0.0;
  for (final balance in balances) {
    if (balance.isOwedToMe) {
      owedToMe += balance.magnitude;
    } else if (balance.isOwedByMe) {
      owedByMe += balance.magnitude;
    }
  }
  return LedgerTotals(owedToMe: owedToMe, owedByMe: owedByMe);
}
