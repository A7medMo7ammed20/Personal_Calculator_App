import 'entry.dart';

/// The gross directional money movement over a window, in one currency (#7).
/// See CONTEXT.md ([[Flow]]).
///
/// Unlike a [[Balance]] (a net, all-time position), flow is **gross** and
/// **per-entry**: a Contact who took +1000 and repaid −300 in the window adds
/// 1000 to [lent] *and* 300 to [received].
class Flow {
  const Flow({required this.lent, required this.received});

  /// Sum of every owed-to-me Entry amount in the window.
  final double lent;

  /// Sum of every owed-by-me Entry amount in the window.
  final double received;

  static const Flow zero = Flow(lent: 0, received: 0);

  @override
  bool operator ==(Object other) =>
      other is Flow && other.lent == lent && other.received == received;

  @override
  int get hashCode => Object.hash(lent, received);
}

/// Gross flow over [entries] (already scoped to one window and currency by the
/// caller). Pure so it is unit-tested without DB or UI.
Flow flowTotalsOf(Iterable<Entry> entries) {
  var lent = 0.0;
  var received = 0.0;
  for (final entry in entries) {
    if (entry.direction == Direction.owedToMe) {
      lent += entry.amount;
    } else {
      received += entry.amount;
    }
  }
  return Flow(lent: lent, received: received);
}
