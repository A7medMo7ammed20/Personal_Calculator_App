/// A person you keep a ledger with. In the UI one Contact *is* one ledger.
/// See CONTEXT.md.
///
/// Pure Dart value object with no persistence or Flutter dependency. A [Contact]
/// with a null [id] has not been saved yet; the repository assigns the id.
class Contact {
  const Contact({
    this.id,
    required this.name,
    this.phone,
    this.archived = false,
  });

  /// Database primary key; null until saved.
  final int? id;

  /// Required display name.
  final String name;

  /// Optional phone number.
  final String? phone;

  /// Archived contacts are hidden from the home list and excluded from the
  /// grand totals, but their ledger is preserved (#25). Defaults to active.
  final bool archived;

  Contact copyWith({int? id, String? name, String? phone, bool? archived}) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Contact &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(id, name, phone, archived);

  @override
  String toString() =>
      'Contact(id: $id, name: $name, phone: $phone, archived: $archived)';
}
