import 'balance.dart';
import 'currency.dart';
import 'entry.dart';

/// Builds the single balancing [Entry] that zeroes [balance] in [currency]
/// (Reset account, ADR 0009): opposite direction, magnitude `|balance|`, with a
/// recognizable settle [description] (Arabic تسوية). Returns `null` when the
/// balance is already settled — the caller disables Reset in that case. A settle
/// *is* just an Entry: the statement and analysis need no special case. Pure.
Entry? buildSettleEntry({
  required int contactId,
  required Balance balance,
  required Currency currency,
  required DateTime createdAt,
  required String description,
}) {
  if (balance.isSettled) return null;
  return Entry(
    contactId: contactId,
    amount: balance.magnitude,
    direction: balance.isOwedToMe ? Direction.owedByMe : Direction.owedToMe,
    currency: currency,
    createdAt: createdAt,
    description: description,
  );
}
