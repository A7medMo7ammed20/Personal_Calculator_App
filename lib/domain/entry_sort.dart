import 'entry.dart';

/// The field an entry list is sorted by on the Contact page. Kept as pure,
/// independently-tested comparators so the home Contacts sort (#6) can reuse
/// the same style. See CONTEXT.md.
enum EntrySortField { date, value, description }

/// Returns a new list of [entries] sorted by [field]. `value` sorts by signed
/// amount (owed-by-me lowest → owed-to-me highest); `description` is
/// case-insensitive with blank descriptions last in ascending order. Ties break
/// by timestamp then id for stability. The input list is not mutated.
List<Entry> sortEntries(
  List<Entry> entries,
  EntrySortField field, {
  bool ascending = true,
}) {
  int stableTie(Entry a, Entry b) {
    final byDate = a.createdAt.compareTo(b.createdAt);
    if (byDate != 0) return byDate;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  int compare(Entry a, Entry b) {
    switch (field) {
      case EntrySortField.date:
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
      case EntrySortField.value:
        final c = a.signedAmount.compareTo(b.signedAmount);
        return c != 0 ? c : stableTie(a, b);
      case EntrySortField.description:
        final da = (a.description ?? '').trim().toLowerCase();
        final db = (b.description ?? '').trim().toLowerCase();
        // Blank descriptions sort last in ascending order.
        if (da.isEmpty && db.isEmpty) return stableTie(a, b);
        if (da.isEmpty) return 1;
        if (db.isEmpty) return -1;
        final c = da.compareTo(db);
        return c != 0 ? c : stableTie(a, b);
    }
  }

  final sorted = [...entries]..sort(compare);
  return ascending ? sorted : sorted.reversed.toList();
}

/// Returns the [entries] whose description contains [query] (case-insensitive,
/// trimmed). A blank query returns the list unchanged.
List<Entry> filterEntriesByDescription(List<Entry> entries, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return entries;
  return entries
      .where((e) => (e.description ?? '').toLowerCase().contains(needle))
      .toList();
}
