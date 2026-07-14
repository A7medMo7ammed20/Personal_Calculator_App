import 'package:debt_ledger/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carries a required name and an optional phone', () {
    const withPhone = Profile(name: 'Ahmed', phone: '0555');
    const withoutPhone = Profile(name: 'Ahmed');

    expect(withPhone.name, 'Ahmed');
    expect(withPhone.phone, '0555');
    expect(withoutPhone.phone, isNull);
  });

  test('is equal by value (name + phone)', () {
    expect(
      const Profile(name: 'Ahmed', phone: '0555'),
      const Profile(name: 'Ahmed', phone: '0555'),
    );
    expect(
      const Profile(name: 'Ahmed', phone: '0555').hashCode,
      const Profile(name: 'Ahmed', phone: '0555').hashCode,
    );
    expect(
      const Profile(name: 'Ahmed', phone: '0555'),
      isNot(const Profile(name: 'Ahmed', phone: '0999')),
    );
    expect(
      const Profile(name: 'Ahmed'),
      isNot(const Profile(name: 'Sara')),
    );
  });

  test('copyWith replaces only the given fields', () {
    const original = Profile(name: 'Ahmed', phone: '0555');

    expect(original.copyWith(name: 'Sara'),
        const Profile(name: 'Sara', phone: '0555'));
    expect(original.copyWith(phone: '0999'),
        const Profile(name: 'Ahmed', phone: '0999'));
    expect(original.copyWith(), original);
  });
}
