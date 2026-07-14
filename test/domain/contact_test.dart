import 'package:debt_ledger/domain/contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a new Contact is not archived by default', () {
    expect(const Contact(name: 'Ali').archived, isFalse);
  });

  test('copyWith(archived: true) flips it and keeps the other fields', () {
    const original = Contact(id: 3, name: 'Ali', phone: '055 512 3456');
    final archived = original.copyWith(archived: true);

    expect(archived.archived, isTrue);
    expect(archived.id, 3);
    expect(archived.name, 'Ali');
    expect(archived.phone, '055 512 3456');
  });

  test('two contacts differing only by archived are not equal', () {
    const active = Contact(id: 3, name: 'Ali');
    final archived = active.copyWith(archived: true);

    expect(active, isNot(archived));
    expect(active.hashCode, isNot(archived.hashCode));
  });

  test('archived surfaces in toString', () {
    const contact = Contact(name: 'Ali', archived: true);
    expect(contact.toString(), contains('archived: true'));
  });
}
