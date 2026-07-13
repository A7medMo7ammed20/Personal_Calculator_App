import 'package:debt_ledger/domain/balance.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/contact_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Contact c(int id, String name, {String? phone}) =>
    Contact(id: id, name: name, phone: phone);

void main() {
  // Ali(1) & Sara(2) have activity; Omar(3) & Badr(4) have none in the lens.
  final contacts = [
    c(1, 'Ali'),
    c(2, 'Sara'),
    c(3, 'Omar'),
    c(4, 'Badr'),
  ];
  final activity = <int, DateTime>{
    1: DateTime(2026, 7, 10),
    2: DateTime(2026, 6, 1),
  };
  final balances = <int, Balance>{
    1: const Balance(900),
    2: const Balance(-700),
    3: const Balance(200),
    // Badr(4) absent -> settled/zero.
  };

  List<int> ids(List<Contact> list) => list.map((x) => x.id!).toList();

  group('sort by activity', () {
    test('newest first (descending); no-activity contacts pinned last by name', () {
      expect(
        ids(sortContacts(contacts, ContactSortField.activity,
            balances: balances, activity: activity, ascending: false)),
        [1, 2, 4, 3], // Ali(07-10), Sara(06-01), then Badr, Omar (A-Z)
      );
    });

    test('oldest first (ascending) still pins no-activity contacts last', () {
      expect(
        ids(sortContacts(contacts, ContactSortField.activity,
            balances: balances, activity: activity, ascending: true)),
        [2, 1, 4, 3], // Sara(06-01), Ali(07-10), then Badr, Omar (A-Z)
      );
    });
  });

  group('sort by name', () {
    test('A-Z ascending', () {
      expect(
        ids(sortContacts(contacts, ContactSortField.name,
            balances: balances, activity: activity, ascending: true)),
        [1, 4, 3, 2], // Ali, Badr, Omar, Sara
      );
    });

    test('Z-A descending', () {
      expect(
        ids(sortContacts(contacts, ContactSortField.name,
            balances: balances, activity: activity, ascending: false)),
        [2, 3, 4, 1],
      );
    });
  });

  group('sort by balance size', () {
    test('biggest magnitude first (descending); settled sinks to bottom', () {
      expect(
        ids(sortContacts(contacts, ContactSortField.balanceSize,
            balances: balances, activity: activity, ascending: false)),
        [1, 2, 3, 4], // 900, 700, 200, 0 — direction ignored
      );
    });

    test('smallest magnitude first (ascending)', () {
      expect(
        ids(sortContacts(contacts, ContactSortField.balanceSize,
            balances: balances, activity: activity, ascending: true)),
        [4, 3, 2, 1],
      );
    });
  });

  test('does not mutate the input list', () {
    final input = [c(1, 'Ali'), c(2, 'Badr')];
    sortContacts(input, ContactSortField.name,
        balances: const {}, activity: const {});
    expect(ids(input), [1, 2]);
  });

  group('filterContacts', () {
    final people = [
      c(1, 'Ali', phone: '055 512 3456'),
      c(2, 'Sara'), // no phone
      c(3, 'Omar', phone: '055-512-9999'),
    ];

    test('matches name case-insensitively and trims the query', () {
      expect(ids(filterContacts(people, '  al ')), [1]);
    });

    test('digit-normalized phone match ignores spaces and dashes', () {
      // '0555 123' -> digits '0555123'; only Ali's number contains it.
      expect(ids(filterContacts(people, '0555 123')), [1]);
    });

    test('a letter query never matches on phone (null phone is safe)', () {
      expect(ids(filterContacts(people, 'sara')), [2]);
    });

    test('empty/blank query returns everything', () {
      expect(ids(filterContacts(people, '   ')), [1, 2, 3]);
    });
  });
}
