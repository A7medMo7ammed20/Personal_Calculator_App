import 'entry.dart';

/// A Contact's running total in one currency — the sum of all signed Entry
/// amounts. Repayment is just an opposite-direction Entry; there is no separate
/// settle concept. See CONTEXT.md.
///
/// Sign convention: positive = owed to me, negative = owed by me. The UI shows a
/// positive [magnitude] plus colour + label; the raw [signed] value stays
/// underneath for sorting and PDF.
class Balance {
  const Balance(this.signed);

  /// Raw signed total: positive owed-to-me, negative owed-by-me.
  final double signed;

  /// Always-positive amount shown to the user.
  double get magnitude => signed.abs();

  /// True when nothing is outstanding in either direction.
  bool get isSettled => magnitude < _epsilon;

  /// True when the Contact owes me (the non-settled positive case).
  bool get isOwedToMe => !isSettled && signed > 0;

  /// True when I owe the Contact.
  bool get isOwedByMe => !isSettled && signed < 0;

  /// Half a cent — below this the two directions have effectively cancelled,
  /// guarding against floating-point drift when netting decimals.
  static const double _epsilon = 0.005;
}

/// Nets a Contact's [entries] into a single [Balance]. Pure function: no DB, no
/// UI — the highest-value logic, exercised directly in unit tests.
Balance balanceOf(Iterable<Entry> entries) {
  final signed = entries.fold<double>(0, (sum, e) => sum + e.signedAmount);
  return Balance(signed);
}
