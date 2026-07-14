/// The single local app owner ("you"). A required [name] — the creditor printed
/// on PDF [Statement]s — plus an optional [phone]. No account, login, or email.
/// See CONTEXT.md.
///
/// Pure Dart value object with no persistence or Flutter dependency. The absence
/// of a stored name (not an empty [Profile]) is what signals "not set yet"; the
/// repository returns `null` in that case rather than a nameless Profile.
class Profile {
  const Profile({required this.name, this.phone});

  /// Required display name — appears as the creditor on statements.
  final String name;

  /// Optional phone number.
  final String? phone;

  Profile copyWith({String? name, String? phone}) {
    return Profile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Profile && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);

  @override
  String toString() => 'Profile(name: $name, phone: $phone)';
}
