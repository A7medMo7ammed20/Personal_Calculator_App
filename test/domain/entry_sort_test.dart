import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/entry_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e({
  required int id,
  Direction direction = Direction.owedToMe,
  double amount = 100,
  String? description,
  DateTime? when,
}) => Entry(
  id: id,
  contactId: 1,
  amount: amount,
  direction: direction,
  currency: Currency.sar,
  createdAt: when ?? DateTime(2026, 7, 13),
  description: description,
);

void main() {
  test('sort by date ascending and descending', () {
    final entries = [
      e(id: 1, when: DateTime(2026, 3, 3)),
      e(id: 2, when: DateTime(2026, 3, 1)),
      e(id: 3, when: DateTime(2026, 3, 2)),
    ];

    expect(
      sortEntries(entries, EntrySortField.date).map((x) => x.id),
      [2, 3, 1],
    );
    expect(
      sortEntries(entries, EntrySortField.date, ascending: false).map((x) => x.id),
      [1, 3, 2],
    );
  });

  test('sort by value uses signed amount (owed-by-me lowest)', () {
    final entries = [
      e(id: 1, direction: Direction.owedToMe, amount: 50),
      e(id: 2, direction: Direction.owedByMe, amount: 30),
      e(id: 3, direction: Direction.owedToMe, amount: 200),
    ];

    // Ascending: -30, +50, +200.
    expect(
      sortEntries(entries, EntrySortField.value).map((x) => x.id),
      [2, 1, 3],
    );
  });

  test('sort by description is case-insensitive; blanks sort last ascending', () {
    final entries = [
      e(id: 1, description: 'banana'),
      e(id: 2, description: 'Apple'),
      e(id: 3, description: null),
    ];

    expect(
      sortEntries(entries, EntrySortField.description).map((x) => x.id),
      [2, 1, 3],
    );
  });

  test('does not mutate the input list', () {
    final entries = [e(id: 1, when: DateTime(2026, 3, 3)), e(id: 2, when: DateTime(2026, 3, 1))];
    sortEntries(entries, EntrySortField.date);
    expect(entries.map((x) => x.id), [1, 2]);
  });

  test('filter matches description case-insensitively and trims the query', () {
    final entries = [
      e(id: 1, description: 'Lunch with Sami'),
      e(id: 2, description: 'Taxi'),
      e(id: 3, description: null),
    ];

    expect(
      filterEntriesByDescription(entries, '  lunch ').map((x) => x.id),
      [1],
    );
  });

  test('empty filter query returns everything', () {
    final entries = [e(id: 1, description: 'x'), e(id: 2, description: null)];
    expect(filterEntriesByDescription(entries, '   ').map((x) => x.id), [1, 2]);
  });
}
