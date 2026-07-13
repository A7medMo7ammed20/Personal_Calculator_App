import 'balance.dart';
import 'contact.dart';

/// The field the home Contact list is sorted by (#6). Pure, independently-tested
/// comparators in the style of [entry_sort]. See CONTEXT.md ([[Activity]]).
enum ContactSortField { activity, name, balanceSize }

/// Returns a new list of [contacts] sorted by [field] within the active currency
/// lens. [balances] and [activity] are the per-Contact net balance and most
/// recent Entry date in that lens (both keyed by contact id; absent = no entries
/// in this currency). The input list is not mutated.
///
/// - `activity`: by last-Entry date. Contacts with **no activity** in the lens
///   are always pinned last (then by name), regardless of [ascending] — they are
///   the least-relevant group, not merely the oldest.
/// - `name`: case-insensitive.
/// - `balanceSize`: by **magnitude** (direction ignored); settled (≈0) is the
///   smallest, so it sinks to the bottom when biggest-first.
///
/// [ascending] carries the usual meaning (older / A-first / smaller first); the
/// home screen picks each field's natural default direction.
List<Contact> sortContacts(
  List<Contact> contacts,
  ContactSortField field, {
  required Map<int, Balance> balances,
  required Map<int, DateTime> activity,
  bool ascending = true,
}) {
  int byName(Contact a, Contact b) {
    final c = a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
    return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
  }

  double magnitude(Contact x) => balances[x.id]?.magnitude ?? 0;

  int compare(Contact a, Contact b) {
    switch (field) {
      case ContactSortField.name:
        final c = byName(a, b);
        return ascending ? c : -c;
      case ContactSortField.balanceSize:
        final c = magnitude(a).compareTo(magnitude(b));
        final r = c != 0 ? c : byName(a, b);
        return ascending ? r : -r;
      case ContactSortField.activity:
        final da = activity[a.id];
        final db = activity[b.id];
        // No activity in the lens always sorts last, then alphabetically —
        // independent of direction, so it stays pinned to the bottom.
        if (da == null && db == null) return byName(a, b);
        if (da == null) return 1;
        if (db == null) return -1;
        final c = da.compareTo(db);
        final r = c != 0 ? c : byName(a, b);
        return ascending ? r : -r;
    }
  }

  return [...contacts]..sort(compare);
}

/// Returns the [contacts] matching [query]: a case-insensitive, trimmed substring
/// of the **name**, or — when the query contains digits — a digit-normalized
/// substring of the **phone** (spaces, dashes and `+` are ignored on both sides).
/// A blank query returns the list unchanged.
List<Contact> filterContacts(List<Contact> contacts, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return contacts;
  final name = trimmed.toLowerCase();
  final queryDigits = _digitsOnly(trimmed);
  return contacts.where((contact) {
    if (contact.name.toLowerCase().contains(name)) return true;
    final phone = contact.phone;
    if (queryDigits.isNotEmpty && phone != null) {
      return _digitsOnly(phone).contains(queryDigits);
    }
    return false;
  }).toList();
}

String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
