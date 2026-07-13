import 'currency.dart';

/// Whether an [Entry] is owed **to me** or **by me**. Set per Entry — the same
/// Contact can have entries in both directions. See CONTEXT.md.
enum Direction {
  /// The Contact owes me. Contributes positively to the Balance.
  owedToMe('to_me'),

  /// I owe the Contact. Contributes negatively to the Balance.
  owedByMe('by_me');

  const Direction(this.code);

  /// Value persisted in the database (e.g. `to_me`).
  final String code;

  /// Parses a persisted [code] back into a [Direction].
  static Direction fromCode(String code) {
    return Direction.values.firstWhere(
      (d) => d.code == code,
      orElse: () =>
          throw ArgumentError.value(code, 'code', 'Unknown direction'),
    );
  }
}

/// A single ledger line: an [amount] owed in one [direction], in one [currency],
/// on a date/time, with an optional [description]. Repayment is simply an
/// opposite-direction Entry — there is no separate settle concept. See CONTEXT.md.
///
/// Pure Dart value object with no persistence or Flutter dependency. An [Entry]
/// with a null [id] has not been saved yet; the repository assigns the id.
/// [amount] is always a positive magnitude — the sign is carried by [direction].
class Entry {
  const Entry({
    this.id,
    required this.contactId,
    required this.amount,
    required this.direction,
    required this.currency,
    required this.createdAt,
    this.description,
  });

  /// Database primary key; null until saved.
  final int? id;

  /// Owning [Contact]'s id (cascade-deletes with the Contact).
  final int contactId;

  /// Positive magnitude of the debt; the sign comes from [direction].
  final double amount;

  final Direction direction;
  final Currency currency;
  final DateTime createdAt;

  /// Optional free-text note.
  final String? description;

  /// Signed contribution to the Balance: positive owed-to-me, negative owed-by-me.
  double get signedAmount =>
      direction == Direction.owedToMe ? amount : -amount;

  Entry copyWith({
    int? id,
    int? contactId,
    double? amount,
    Direction? direction,
    Currency? currency,
    DateTime? createdAt,
    String? description,
  }) {
    return Entry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.contactId == contactId &&
      other.amount == amount &&
      other.direction == direction &&
      other.currency == currency &&
      other.createdAt == createdAt &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    id,
    contactId,
    amount,
    direction,
    currency,
    createdAt,
    description,
  );

  @override
  String toString() =>
      'Entry(id: $id, contactId: $contactId, amount: $amount, '
      'direction: ${direction.code}, currency: ${currency.code}, '
      'createdAt: $createdAt, description: $description)';
}
