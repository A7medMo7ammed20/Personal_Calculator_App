# Slice 5: Edit/Delete + Entry Search/Sort + Running Summary — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Entries and Contacts editable/deletable via swipe gestures with confirm+undo, add per-Contact entry search/sort, and add a tap-to-view running summary (statement preview).

**Architecture:** Layered — pure domain logic (running-summary series, sort/filter comparators) tested directly; repository CRUD mirroring existing `add`; presentation wires swipe (`Dismissible`), a search/sort bar, and a running-summary bottom sheet onto the existing Contact page and home tiles. No schema migration (edit/delete add no columns). No new packages.

**Tech Stack:** Flutter 3.44.4 / Dart 3.12.2, sqflite (+ `sqflite_common_ffi` for tests), `intl`, generated l10n (`flutter gen-l10n`).

## Global Constraints

- Flutter 3.44.4 / Dart 3.12.2. No new pub dependencies.
- Schema stays at **version 3** — no migration. `PRAGMA foreign_keys = ON` already cascades Contact → Entries.
- Currency is a **global lens**: all Contact-page math and the running summary are scoped to the active currency; SAR/YER never mix.
- Balance sign: positive = owed-to-me, negative = owed-by-me; UI shows positive magnitude + colour/label, never the raw sign.
- l10n: every user-facing string added to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`, then `flutter gen-l10n`. Import `package:debt_ledger/l10n/gen/app_localizations.dart` (note `gen/`).
- Swipe directions chosen by semantic `DismissDirection.startToEnd`/`endToStart` so they flip correctly under Arabic RTL. **swipe toward end = delete**, **swipe toward start = edit**.
- Delete is the only irreversible action: Entry delete = confirm dialog + undo SnackBar; Contact delete = confirm dialog stating cascade entry count + undo.
- Widget tests use `databaseFactoryFfiNoIsolate`; repo/unit tests use `databaseFactoryFfi`.
- Money colours reused verbatim: green `Color(0xFF2E7D5B)`, red `Color(0xFFC0392B)`. Format via `formatMoney(magnitude, currency)`.
- Commit after every task with green `flutter analyze` (excludes `lib/l10n/gen/**`) and `flutter test`.

---

### Task 1: EntryRepository.update / delete

**Files:**
- Modify: `lib/data/entry_repository.dart`
- Test: `test/data/entry_repository_test.dart`

**Interfaces:**
- Consumes: existing `EntryRepository.add`, `listByContact`, `_toRow`, `_fromRow`.
- Produces:
  - `Future<void> update(Entry entry)` — updates the row identified by `entry.id` (must be non-null) with `_toRow(entry)`.
  - `Future<void> delete(int id)` — deletes the row with primary key `id`.

- [ ] **Step 1: Write the failing tests** — append inside `main()` in `test/data/entry_repository_test.dart`:

```dart
  test('update changes a stored Entry in place', () async {
    final contact = await contacts.add(const Contact(name: 'Edit Me'));
    final saved = await entries.add(sample(contact.id!, amount: 100));

    await entries.update(
      saved.copyWith(amount: 250, direction: Direction.owedByMe),
    );

    final stored = (await entries.listByContact(contact.id!)).single;
    expect(stored.id, saved.id);
    expect(stored.amount, 250);
    expect(stored.direction, Direction.owedByMe);
  });

  test('delete removes only the given Entry', () async {
    final contact = await contacts.add(const Contact(name: 'Two Rows'));
    final keep = await entries.add(sample(contact.id!, amount: 10));
    final drop = await entries.add(sample(contact.id!, amount: 20));

    await entries.delete(drop.id!);

    final remaining = await entries.listByContact(contact.id!);
    expect(remaining.map((e) => e.id), [keep.id]);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/entry_repository_test.dart`
Expected: FAIL — `The method 'update' isn't defined` / `'delete' isn't defined`.

- [ ] **Step 3: Add the methods** — in `lib/data/entry_repository.dart`, after the `add` method (before `balancesByCurrency`):

```dart
  /// Overwrites the stored row identified by [Entry.id] (which must be non-null)
  /// with [entry]'s current values. Edits are in place — no audit trail.
  Future<void> update(Entry entry) async {
    final db = await _appDb.open();
    await db.update(
      table,
      _toRow(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Deletes the Entry with primary key [id].
  Future<void> delete(int id) async {
    final db = await _appDb.open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/entry_repository_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/entry_repository.dart test/data/entry_repository_test.dart
git commit -m "feat: EntryRepository update and delete (#5)"
```

---

### Task 2: ContactRepository.update / delete / entryCount

**Files:**
- Modify: `lib/data/contact_repository.dart`
- Test: `test/data/contact_repository_test.dart`

**Interfaces:**
- Consumes: existing `ContactRepository.add`, `list`, `EntryRepository` (for the cascade/count tests).
- Produces:
  - `Future<void> update(Contact contact)` — updates the row identified by `contact.id`.
  - `Future<void> delete(int id)` — deletes the Contact with primary key `id` (cascade removes its Entries).
  - `Future<int> entryCount(int contactId)` — count of the Contact's Entries across **all** currencies.

- [ ] **Step 1: Write the failing tests** — append inside `main()` in `test/data/contact_repository_test.dart`. If the file has no `EntryRepository`/`Entry` imports or setup yet, add these imports at top:

```dart
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
```

Then the tests (use whatever `contacts`/`appDb` fixture the file already defines in `setUp`; construct an `EntryRepository(appDb)` inline):

```dart
  test('update changes a stored Contact in place', () async {
    final contacts = ContactRepository(appDb);
    final saved = await contacts.add(const Contact(name: 'Old', phone: '111'));

    await contacts.update(saved.copyWith(name: 'New', phone: '222'));

    final stored = (await contacts.list()).single;
    expect(stored.id, saved.id);
    expect(stored.name, 'New');
    expect(stored.phone, '222');
  });

  test('delete removes the Contact and cascade-deletes its Entries', () async {
    final contacts = ContactRepository(appDb);
    final entries = EntryRepository(appDb);
    final contact = await contacts.add(const Contact(name: 'Doomed'));
    await entries.add(Entry(
      contactId: contact.id!,
      amount: 100,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 7, 13),
    ));

    await contacts.delete(contact.id!);

    expect(await contacts.list(), isEmpty);
    expect(await entries.listByContact(contact.id!), isEmpty);
  });

  test('entryCount counts entries across all currencies', () async {
    final contacts = ContactRepository(appDb);
    final entries = EntryRepository(appDb);
    final contact = await contacts.add(const Contact(name: 'Busy'));
    for (final currency in [Currency.sar, Currency.yer, Currency.sar]) {
      await entries.add(Entry(
        contactId: contact.id!,
        amount: 10,
        direction: Direction.owedToMe,
        currency: currency,
        createdAt: DateTime(2026, 7, 13),
      ));
    }

    expect(await contacts.entryCount(contact.id!), 3);
  });
```

> Note: this test relies on `PRAGMA foreign_keys = ON` (already set in `AppDatabase`). The existing `contact_repository_test.dart` `setUp` already builds an `AppDatabase` with `databaseFactoryFfi`; reuse it.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/contact_repository_test.dart`
Expected: FAIL — `update` / `delete` / `entryCount` not defined.

- [ ] **Step 3: Add the methods** — in `lib/data/contact_repository.dart`, after the `list` method:

```dart
  /// Overwrites the stored row identified by [Contact.id] with [contact]'s
  /// current name and phone.
  Future<void> update(Contact contact) async {
    final db = await _appDb.open();
    await db.update(
      table,
      _toRow(contact),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  /// Deletes the Contact with primary key [id]. Its Entries cascade-delete
  /// (see [AppDatabase] schema v3, foreign keys on).
  Future<void> delete(int id) async {
    final db = await _appDb.open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// How many Entries this Contact has, across all currencies — used to warn
  /// before a cascade delete.
  Future<int> entryCount(int contactId) async {
    final db = await _appDb.open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${EntryRepository.table} WHERE contact_id = ?',
      [contactId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }
```

Add the import at the top of `lib/data/contact_repository.dart` if not present:

```dart
import 'entry_repository.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/contact_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/contact_repository.dart test/data/contact_repository_test.dart
git commit -m "feat: ContactRepository update, delete, entryCount (#5)"
```

---

### Task 3: Running-summary series (pure domain)

**Files:**
- Create: `lib/domain/running_summary.dart`
- Test: `test/domain/running_summary_test.dart`

**Interfaces:**
- Consumes: `Entry`, `Direction` (`lib/domain/entry.dart`), `Balance` (`lib/domain/balance.dart`).
- Produces:
  - `class RunningSummaryRow` with fields `final Entry entry; final double cumulativeOwedToMe; final double cumulativeOwedByMe; final Balance balance;` and a const constructor `RunningSummaryRow({required this.entry, required this.cumulativeOwedToMe, required this.cumulativeOwedByMe, required this.balance})`.
  - `List<RunningSummaryRow> runningSummary(Iterable<Entry> entries)` — returns rows in **date-ascending** order (tie-break by `id`), each carrying gross cumulative owed-to-me and owed-by-me totals and the net `Balance` after that entry. Pass entries already scoped to one currency.

- [ ] **Step 1: Write the failing test** — create `test/domain/running_summary_test.dart`:

```dart
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/running_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e({
  required int id,
  required Direction direction,
  required double amount,
  required DateTime when,
}) => Entry(
  id: id,
  contactId: 1,
  amount: amount,
  direction: direction,
  currency: Currency.sar,
  createdAt: when,
);

void main() {
  test('empty entries produce no rows', () {
    expect(runningSummary(const []), isEmpty);
  });

  test('single owed-to-me entry: gross to-me and net both equal the amount', () {
    final rows = runningSummary([
      e(id: 1, direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 3, 1)),
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.cumulativeOwedToMe, 200);
    expect(rows.single.cumulativeOwedByMe, 0);
    expect(rows.single.balance.signed, 200);
  });

  test('orders ascending by date and accumulates each direction grossly', () {
    // Deliberately out of order in the input.
    final rows = runningSummary([
      e(id: 3, direction: Direction.owedToMe, amount: 190, when: DateTime(2026, 3, 3)),
      e(id: 1, direction: Direction.owedToMe, amount: 200, when: DateTime(2026, 3, 1)),
      e(id: 2, direction: Direction.owedByMe, amount: 50, when: DateTime(2026, 3, 2)),
    ]);

    expect(rows.map((r) => r.entry.id), [1, 2, 3]);
    // Gross running totals up to each row.
    expect(rows[0].cumulativeOwedToMe, 200);
    expect(rows[0].cumulativeOwedByMe, 0);
    expect(rows[1].cumulativeOwedToMe, 200);
    expect(rows[1].cumulativeOwedByMe, 50);
    expect(rows[2].cumulativeOwedToMe, 390);
    expect(rows[2].cumulativeOwedByMe, 50);
    // Net balance after the last row: 390 - 50 = 340 owed-to-me.
    expect(rows[2].balance.signed, 340);
    expect(rows[2].balance.isOwedToMe, isTrue);
  });

  test('a repayment can cross the balance to settled', () {
    final rows = runningSummary([
      e(id: 1, direction: Direction.owedToMe, amount: 100, when: DateTime(2026, 3, 1)),
      e(id: 2, direction: Direction.owedByMe, amount: 100, when: DateTime(2026, 3, 2)),
    ]);

    expect(rows.last.cumulativeOwedToMe, 100);
    expect(rows.last.cumulativeOwedByMe, 100);
    expect(rows.last.balance.isSettled, isTrue);
  });

  test('same-timestamp entries tie-break by id', () {
    final when = DateTime(2026, 3, 5);
    final rows = runningSummary([
      e(id: 2, direction: Direction.owedToMe, amount: 5, when: when),
      e(id: 1, direction: Direction.owedToMe, amount: 5, when: when),
    ]);

    expect(rows.map((r) => r.entry.id), [1, 2]);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/running_summary_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:debt_ledger/domain/running_summary.dart'`.

- [ ] **Step 3: Write the implementation** — create `lib/domain/running_summary.dart`:

```dart
import 'balance.dart';
import 'entry.dart';

/// One line of a running summary: an [Entry] plus the gross cumulative totals
/// **up to and including** it and the net [Balance] after it. The two gross
/// totals mirror the PDF Statement's owed-to-me / owed-by-me columns; this is
/// the on-screen statement preview and the pure seam the Analysis graph (#8)
/// and Statement (#10) reuse. See CONTEXT.md.
class RunningSummaryRow {
  const RunningSummaryRow({
    required this.entry,
    required this.cumulativeOwedToMe,
    required this.cumulativeOwedByMe,
    required this.balance,
  });

  final Entry entry;

  /// Gross sum of all owed-to-me amounts up to and including [entry].
  final double cumulativeOwedToMe;

  /// Gross sum of all owed-by-me amounts up to and including [entry].
  final double cumulativeOwedByMe;

  /// Net position after [entry]: [cumulativeOwedToMe] − [cumulativeOwedByMe].
  final Balance balance;
}

/// Builds the date-ascending running summary over [entries] (already scoped to
/// one currency). Ties on timestamp break by [Entry.id]. Pure function — no DB,
/// no UI — exercised directly in unit tests like [balanceOf]/[totalsOf].
List<RunningSummaryRow> runningSummary(Iterable<Entry> entries) {
  final sorted = [...entries]..sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      if (byDate != 0) return byDate;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

  var owedToMe = 0.0;
  var owedByMe = 0.0;
  final rows = <RunningSummaryRow>[];
  for (final entry in sorted) {
    if (entry.direction == Direction.owedToMe) {
      owedToMe += entry.amount;
    } else {
      owedByMe += entry.amount;
    }
    rows.add(RunningSummaryRow(
      entry: entry,
      cumulativeOwedToMe: owedToMe,
      cumulativeOwedByMe: owedByMe,
      balance: Balance(owedToMe - owedByMe),
    ));
  }
  return rows;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/running_summary_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/running_summary.dart test/domain/running_summary_test.dart
git commit -m "feat: running-summary series builder (#16)"
```

---

### Task 4: Entry sort/filter comparators (pure domain)

**Files:**
- Create: `lib/domain/entry_sort.dart`
- Test: `test/domain/entry_sort_test.dart`

**Interfaces:**
- Consumes: `Entry` (`lib/domain/entry.dart`).
- Produces:
  - `enum EntrySortField { date, value, description }`.
  - `List<Entry> sortEntries(List<Entry> entries, EntrySortField field, {bool ascending = true})` — returns a **new** sorted list (input unmutated). `value` sorts by `signedAmount` (owed-by-me lowest, owed-to-me highest). `description` sorts case-insensitively; null/empty descriptions sort last in ascending order. Ties break by `createdAt` then `id` for a stable order.
  - `List<Entry> filterEntriesByDescription(List<Entry> entries, String query)` — returns entries whose description contains `query` (case-insensitive, trimmed). Empty/whitespace query returns the list unchanged.

- [ ] **Step 1: Write the failing test** — create `test/domain/entry_sort_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/entry_sort_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:debt_ledger/domain/entry_sort.dart'`.

- [ ] **Step 3: Write the implementation** — create `lib/domain/entry_sort.dart`:

```dart
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
```

> Note on `descending` blank handling: `reversed` will move blank descriptions to the front when descending. That is acceptable for this slice (the user toggles direction explicitly); do not add special-casing.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/entry_sort_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entry_sort.dart test/domain/entry_sort_test.dart
git commit -m "feat: entry sort/filter comparators (#15)"
```

---

### Task 5: l10n strings for edit/delete, search/sort, and summary

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`
- Regenerate: `lib/l10n/gen/**` via `flutter gen-l10n` (committed)

**Interfaces:**
- Produces (accessed as `AppLocalizations.of(context).<key>`): `editEntry`, `editContact`, `edit`, `delete`, `cancel`, `undo`, `deleteEntryTitle`, `deleteEntryMessage`, `entryDeleted`, `deleteContactTitle`, `deleteContactMessage(count)`, `contactDeleted`, `searchEntriesHint`, `sortLabel`, `sortByDate`, `sortByValue`, `sortByDescription`, `summaryTitle(date)`.
- Reuses existing: `save`, `homeTotalOwedToMe` ("Owed to you"), `homeTotalOwedByMe` ("You owe"), `balanceOwedToMe`, `balanceOwedByMe`, `balanceSettled`.

- [ ] **Step 1: Add the English strings** — insert these keys into `lib/l10n/app_en.arb` before the closing `}` (add a comma to the current last entry):

```json
  "edit": "Edit",
  "@edit": { "description": "Generic edit action label (swipe reveal, form title prefix)." },
  "delete": "Delete",
  "@delete": { "description": "Generic delete action label (swipe reveal)." },
  "cancel": "Cancel",
  "@cancel": { "description": "Dismiss a dialog without acting." },
  "undo": "Undo",
  "@undo": { "description": "SnackBar action that reverses a delete." },
  "editEntry": "Edit entry",
  "@editEntry": { "description": "Title of the entry form when editing an existing entry." },
  "editContact": "Edit contact",
  "@editContact": { "description": "Title of the contact form when editing an existing contact." },
  "deleteEntryTitle": "Delete entry?",
  "@deleteEntryTitle": { "description": "Confirmation dialog title before deleting an entry." },
  "deleteEntryMessage": "This entry will be removed and the balance recomputed.",
  "@deleteEntryMessage": { "description": "Confirmation dialog body before deleting an entry." },
  "entryDeleted": "Entry deleted",
  "@entryDeleted": { "description": "SnackBar shown after an entry is deleted, alongside Undo." },
  "deleteContactTitle": "Delete contact?",
  "@deleteContactTitle": { "description": "Confirmation dialog title before deleting a contact." },
  "deleteContactMessage": "{count, plural, =0{This contact has no entries.} =1{1 entry will also be deleted.} other{{count} entries will also be deleted.}}",
  "@deleteContactMessage": {
    "description": "Confirmation body stating how many entries cascade-delete with the contact.",
    "placeholders": { "count": { "type": "int" } }
  },
  "contactDeleted": "Contact deleted",
  "@contactDeleted": { "description": "SnackBar shown after a contact is deleted, alongside Undo." },
  "searchEntriesHint": "Search description",
  "@searchEntriesHint": { "description": "Hint text in the per-contact entry search field." },
  "sortLabel": "Sort",
  "@sortLabel": { "description": "Label for the entry sort control." },
  "sortByDate": "Date",
  "@sortByDate": { "description": "Sort entries by date." },
  "sortByValue": "Value",
  "@sortByValue": { "description": "Sort entries by signed value." },
  "sortByDescription": "Description",
  "@sortByDescription": { "description": "Sort entries by description text." },
  "summaryTitle": "Summary up to {date}",
  "@summaryTitle": {
    "description": "Title of the running-summary bottom sheet, showing the tapped entry's date.",
    "placeholders": { "date": { "type": "String", "example": "Mar 3, 2026" } }
  }
```

- [ ] **Step 2: Add the Arabic strings** — insert the matching keys into `lib/l10n/app_ar.arb` before its closing `}` (add a comma to the current last entry). Note the full Arabic plural categories:

```json
  "edit": "تعديل",
  "delete": "حذف",
  "cancel": "إلغاء",
  "undo": "تراجع",
  "editEntry": "تعديل الحركة",
  "editContact": "تعديل جهة الاتصال",
  "deleteEntryTitle": "حذف الحركة؟",
  "deleteEntryMessage": "ستُحذف هذه الحركة وسيُعاد حساب الرصيد.",
  "entryDeleted": "تم حذف الحركة",
  "deleteContactTitle": "حذف جهة الاتصال؟",
  "deleteContactMessage": "{count, plural, =0{لا توجد حركات لهذه الجهة.} one{ستُحذف حركة واحدة أيضًا.} two{ستُحذف حركتان أيضًا.} few{ستُحذف {count} حركات أيضًا.} many{ستُحذف {count} حركة أيضًا.} other{ستُحذف {count} حركة أيضًا.}}",
  "contactDeleted": "تم حذف جهة الاتصال",
  "searchEntriesHint": "ابحث في الوصف",
  "sortLabel": "ترتيب",
  "sortByDate": "التاريخ",
  "sortByValue": "القيمة",
  "sortByDescription": "الوصف",
  "summaryTitle": "الملخّص حتى {date}"
}
```

(Do not duplicate the `@`-metadata blocks in the Arabic file — the English file is the template of record; the Arabic file carries only values, matching the existing file's style. Verify against the existing `app_ar.arb` and match whatever convention it already uses.)

- [ ] **Step 3: Regenerate localizations and verify they compile**

Run: `flutter gen-l10n && flutter analyze`
Expected: gen-l10n succeeds; analyze reports no errors (generated files under `lib/l10n/gen/` excluded from lints but must compile).

- [ ] **Step 4: Sanity-check the new getters exist**

Run: `flutter test test/presentation/contact_screen_test.dart`
Expected: PASS (existing tests still green; confirms the generated `AppLocalizations` is valid).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/gen
git commit -m "feat: l10n strings for slice 5 (edit/delete, search/sort, summary)"
```

---

### Task 6: Generalize AddEntryScreen to add-or-edit

**Files:**
- Modify: `lib/presentation/entries/add_entry_screen.dart`
- Test: `test/presentation/add_entry_screen_test.dart` (create)

**Interfaces:**
- Consumes: `EntryRepository.add`, `EntryRepository.update`, `Entry.copyWith`.
- Produces: `AddEntryScreen` gains an optional `final Entry? existing;` constructor param. When non-null the form prefills from it, the app-bar title becomes `l10n.editEntry`, and `_save` calls `repository.update(existing.copyWith(...))` then pops the updated `Entry`. When null, behaviour is unchanged (calls `add`, pops the saved `Entry`).

- [ ] **Step 1: Write the failing widget test** — create `test/presentation/add_entry_screen_test.dart`:

```dart
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/entries/add_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late EntryRepository entries;
  late Contact contact;

  setUp(() async {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    entries = EntryRepository(appDb);
    contact = await ContactRepository(appDb).add(const Contact(name: 'Sami'));
  });

  tearDown(() => appDb.close());

  testWidgets('editing an existing entry prefills and updates in place',
      (tester) async {
    final saved = await entries.add(Entry(
      contactId: contact.id!,
      amount: 100,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 7, 13, 10),
      description: 'lunch',
    ));

    await tester.pumpWidget(_wrap(AddEntryScreen(
      contactId: contact.id!,
      repository: entries,
      currency: Currency.sar,
      existing: saved,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // amount prefilled
    expect(find.text('lunch'), findsOneWidget); // description prefilled

    await tester.enterText(find.byType(TextFormField).first, '175');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = (await entries.listByContact(contact.id!)).single;
    expect(stored.id, saved.id); // same row, updated
    expect(stored.amount, 175);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/add_entry_screen_test.dart`
Expected: FAIL — `No named parameter with the name 'existing'`.

- [ ] **Step 3: Add the `existing` param and edit path** — in `lib/presentation/entries/add_entry_screen.dart`:

Add the field to the widget and constructor:

```dart
  const AddEntryScreen({
    super.key,
    required this.contactId,
    required this.repository,
    required this.currency,
    this.existing,
  });

  final int contactId;
  final EntryRepository repository;
  final Currency currency;

  /// When non-null, the form edits this Entry in place instead of adding a new
  /// one (issue #5). The currency lens is still inherited — never edited here.
  final Entry? existing;
```

Prefill state in `initState` (add the method to `_AddEntryScreenState`, and remove the field initializers for `_direction`/`_when` if you set them here — keep them as `late`):

```dart
  late Direction _direction;
  late DateTime _when;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = _trimAmount(existing.amount);
      _descriptionController.text = existing.description ?? '';
      _direction = existing.direction;
      _when = existing.createdAt;
    } else {
      _direction = Direction.owedToMe;
      _when = _nowToMinute();
    }
  }

  /// Renders 100.0 as "100" and 42.5 as "42.5" for the amount field.
  static String _trimAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toString();
  }
```

Update `_save` to branch on `widget.existing`:

```dart
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final description = _descriptionController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final existing = widget.existing;

    final Entry result;
    if (existing != null) {
      result = existing.copyWith(
        amount: amount,
        direction: _direction,
        createdAt: _when,
        description: description.isEmpty ? null : description,
      );
      await widget.repository.update(result);
    } else {
      result = await widget.repository.add(Entry(
        contactId: widget.contactId,
        amount: amount,
        direction: _direction,
        currency: widget.currency,
        createdAt: _when,
        description: description.isEmpty ? null : description,
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
```

> Caveat: `copyWith` cannot set `description` back to null (it uses `?? this`). For this slice, clearing a description on edit is out of scope — if the field is emptied, the prior description is retained. Note this in the entry form's doc comment.

Update the app-bar title:

```dart
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.addEntry : l10n.editEntry),
      ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/add_entry_screen_test.dart test/presentation/contact_screen_test.dart`
Expected: PASS (new edit test + existing add-flow tests still green).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/entries/add_entry_screen.dart test/presentation/add_entry_screen_test.dart
git commit -m "feat: AddEntryScreen edits an existing entry in place (#5)"
```

---

### Task 7: Generalize AddContactScreen to add-or-edit

**Files:**
- Modify: `lib/presentation/contacts/add_contact_screen.dart`
- Test: `test/presentation/add_contact_screen_test.dart` (create)

**Interfaces:**
- Consumes: `ContactRepository.add`, `ContactRepository.update`, `Contact.copyWith`.
- Produces: `AddContactScreen` gains `final Contact? existing;`. When non-null: prefill name/phone, app-bar title `l10n.editContact`, `_save` calls `repository.update(existing.copyWith(...))` and pops the updated `Contact`.

- [ ] **Step 1: Write the failing widget test** — create `test/presentation/add_contact_screen_test.dart`:

```dart
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/add_contact_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ContactRepository contacts;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
  });

  tearDown(() => appDb.close());

  testWidgets('editing a contact prefills and updates in place', (tester) async {
    final saved = await contacts.add(const Contact(name: 'Old', phone: '111'));

    await tester.pumpWidget(_wrap(
      AddContactScreen(repository: contacts, existing: saved),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit contact'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('111'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'New');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = (await contacts.list()).single;
    expect(stored.id, saved.id);
    expect(stored.name, 'New');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/add_contact_screen_test.dart`
Expected: FAIL — `No named parameter with the name 'existing'`.

- [ ] **Step 3: Add the `existing` param and edit path** — in `lib/presentation/contacts/add_contact_screen.dart`:

```dart
  const AddContactScreen({super.key, required this.repository, this.existing});

  final ContactRepository repository;

  /// When non-null, the form edits this Contact's name/phone in place (#5).
  final Contact? existing;
```

Prefill in `initState` (add to `_AddContactScreenState`):

```dart
  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone ?? '';
    }
  }
```

Branch `_save`:

```dart
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final existing = widget.existing;

    final Contact result;
    if (existing != null) {
      result = existing.copyWith(name: name, phone: phone.isEmpty ? null : phone);
      await widget.repository.update(result);
    } else {
      result = await widget.repository.add(
        Contact(name: name, phone: phone.isEmpty ? null : phone),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
```

> Same `copyWith` null caveat as entries: clearing a phone on edit is out of scope this slice.

Title:

```dart
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.addContact : l10n.editContact),
      ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/add_contact_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/contacts/add_contact_screen.dart test/presentation/add_contact_screen_test.dart
git commit -m "feat: AddContactScreen edits an existing contact in place (#5)"
```

---

### Task 8: Contact page — entry search + sort bar (#15)

**Files:**
- Modify: `lib/presentation/contacts/contact_screen.dart`
- Test: `test/presentation/contact_screen_test.dart`

**Interfaces:**
- Consumes: `sortEntries`, `filterEntriesByDescription`, `EntrySortField` (`lib/domain/entry_sort.dart`).
- Produces: `_ContactScreenState` gains `String _query = ''`, `EntrySortField _sortField = EntrySortField.date`, `bool _ascending = false` (newest-first default matches current behaviour). Build applies `filterEntriesByDescription` then `sortEntries` to the snapshot list before rendering. A search `TextField` and a sort control sit above the list. Search/sort are pure transforms — **no DB reload**.

- [ ] **Step 1: Write the failing widget tests** — append to `test/presentation/contact_screen_test.dart`:

```dart
  testWidgets('searching filters the entry list by description', (tester) async {
    await entries.add(Entry(
      contactId: contact.id!, amount: 10, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 7, 1), description: 'Lunch',
    ));
    await entries.add(Entry(
      contactId: contact.id!, amount: 20, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 7, 2), description: 'Taxi',
    ));

    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Taxi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'lunch');
    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Taxi'), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/contact_screen_test.dart -n "searching filters"`
Expected: FAIL — no `TextField` found / both entries still shown.

- [ ] **Step 3: Implement the search + sort bar** — in `lib/presentation/contacts/contact_screen.dart`:

Add imports:

```dart
import '../../domain/entry_sort.dart';
```

Add state fields to `_ContactScreenState`:

```dart
  final _searchController = TextEditingController();
  String _query = '';
  EntrySortField _sortField = EntrySortField.date;
  bool _ascending = false; // newest-first default (created_at DESC)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
```

In `build`, after computing `entries` from the snapshot and BEFORE `balanceOf`, derive the visible list. Note: the **balance uses all entries**, the **list uses the filtered/sorted view**:

```dart
          final entries = snapshot.data ?? const <Entry>[];
          final balance = balanceOf(entries); // balance is over ALL entries
          final visible = sortEntries(
            filterEntriesByDescription(entries, _query),
            _sortField,
            ascending: _ascending,
          );
```

Insert a search/sort bar between `_BalanceHeader` and the `Expanded` list. Replace the current `Expanded(child: entries.isEmpty ? ... : ListView...)` block so the list iterates `visible`, and add the bar above it:

```dart
              _EntrySearchSortBar(
                controller: _searchController,
                sortField: _sortField,
                ascending: _ascending,
                onQueryChanged: (q) => setState(() => _query = q),
                onSortSelected: (field) => setState(() {
                  if (_sortField == field) {
                    _ascending = !_ascending; // tapping active field toggles
                  } else {
                    _sortField = field;
                    _ascending = true;
                  }
                }),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          l10n.contactEntriesEmpty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _entryTile(context, l10n, visible[index]),
                      ),
              ),
```

Add the bar widget at the bottom of the file:

```dart
/// Search field plus a sort control (Date / Value / Description) for the
/// Contact's own entries (#15). Tapping the active sort field toggles asc/desc.
class _EntrySearchSortBar extends StatelessWidget {
  const _EntrySearchSortBar({
    required this.controller,
    required this.sortField,
    required this.ascending,
    required this.onQueryChanged,
    required this.onSortSelected,
  });

  final TextEditingController controller;
  final EntrySortField sortField;
  final bool ascending;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EntrySortField> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(EntrySortField f) => switch (f) {
      EntrySortField.date => l10n.sortByDate,
      EntrySortField.value => l10n.sortByValue,
      EntrySortField.description => l10n.sortByDescription,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchEntriesHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<EntrySortField>(
            tooltip: l10n.sortLabel,
            icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            initialValue: sortField,
            onSelected: onSortSelected,
            itemBuilder: (context) => [
              for (final f in EntrySortField.values)
                CheckedPopupMenuItem(
                  value: f,
                  checked: f == sortField,
                  child: Text(label(f)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/contact_screen_test.dart`
Expected: PASS (new search test + all existing Contact-screen tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/contacts/contact_screen.dart test/presentation/contact_screen_test.dart
git commit -m "feat: per-contact entry search and sort bar (#15)"
```

---

### Task 9: Contact page — swipe edit/delete on entries (#5)

**Files:**
- Modify: `lib/presentation/contacts/contact_screen.dart`
- Test: `test/presentation/contact_screen_test.dart`

**Interfaces:**
- Consumes: `EntryRepository.delete`, `EntryRepository.add`, `AddEntryScreen(existing:)`.
- Produces: each entry row wrapped in a `Dismissible` keyed by `ValueKey(entry.id)`. `startToEnd` (swipe toward end) = delete via a confirm dialog; on confirm, delete and show an undo SnackBar that re-adds the entry. `endToStart` (swipe toward start) = open `AddEntryScreen(existing: entry)` and never dismiss (returns `false`). Reload entries after any change. New private helpers: `Future<void> _editEntry(Entry)`, `Future<bool> _confirmDeleteEntry()`, `Future<void> _deleteEntry(Entry)`.

- [ ] **Step 1: Write the failing widget test** — append to `test/presentation/contact_screen_test.dart`:

```dart
  testWidgets('swipe-to-delete asks for confirmation then removes on confirm',
      (tester) async {
    await entries.add(seed(contact.id!, Direction.owedToMe, 150));

    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    // Swipe the entry tile toward the end (LTR: to the right) = delete.
    await tester.drag(find.byType(Dismissible).first, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    // Balance falls back to settled; an undo SnackBar appears.
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/contact_screen_test.dart -n "swipe-to-delete"`
Expected: FAIL — no `Dismissible` found.

- [ ] **Step 3: Implement swipe edit/delete** — in `lib/presentation/contacts/contact_screen.dart`:

Wrap the tile builder. Change the `itemBuilder` to call a new `_dismissibleEntry`:

```dart
                        itemBuilder: (context, index) =>
                            _dismissibleEntry(context, l10n, visible[index]),
```

Add the wrapper and handlers to `_ContactScreenState`:

```dart
  Widget _dismissibleEntry(
    BuildContext context,
    AppLocalizations l10n,
    Entry entry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      // Swipe toward END = delete (red). Confirmed, then undoable.
      background: Container(
        color: _red.withValues(alpha: 0.90),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 20),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      // Swipe toward START = edit (blue). Never dismisses the tile.
      secondaryBackground: Container(
        color: Colors.blue.withValues(alpha: 0.85),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final ok = await _confirmDeleteEntry(l10n);
          return ok;
        } else {
          await _editEntry(entry);
          return false; // edit never dismisses
        }
      },
      onDismissed: (_) => _deleteEntry(entry),
      child: _entryTile(context, l10n, entry),
    );
  }

  Future<bool> _confirmDeleteEntry(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEntryTitle),
        content: Text(l10n.deleteEntryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteEntry(Entry entry) async {
    await widget.repository.delete(entry.id!);
    if (!mounted) return;
    setState(_load);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.entryDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            // Re-insert as a fresh row; nothing references entry ids.
            await widget.repository.add(entry.copyWith(id: null));
            if (mounted) setState(_load);
          },
        ),
      ));
  }

  Future<void> _editEntry(Entry entry) async {
    final updated = await Navigator.of(context).push<Entry>(
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(
          contactId: widget.contact.id!,
          repository: widget.repository,
          currency: widget.currency,
          existing: entry,
        ),
      ),
    );
    if (updated != null && mounted) setState(_load);
  }
```

> RTL note: `startToEnd`/`endToStart` and `AlignmentDirectional`/`EdgeInsetsDirectional` all resolve against text direction, so the red delete background always sits on the "end" swipe and mirrors correctly in Arabic. The existing Arabic RTL test in this file guards direction; no extra locale test needed for the swipe mapping itself, but do a live RTL check in Task 12.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/contact_screen_test.dart`
Expected: PASS (swipe-delete test + all existing).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/contacts/contact_screen.dart test/presentation/contact_screen_test.dart
git commit -m "feat: swipe to edit/delete entries with confirm + undo (#5)"
```

---

### Task 10: Running-summary bottom sheet on tap (#16)

**Files:**
- Create: `lib/presentation/contacts/running_summary_sheet.dart`
- Modify: `lib/presentation/contacts/contact_screen.dart`
- Test: `test/presentation/running_summary_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `runningSummary`, `RunningSummaryRow` (`lib/domain/running_summary.dart`), `formatMoney`, `Balance`, `Currency`, existing l10n `homeTotalOwedToMe`/`homeTotalOwedByMe`/`balanceOwedToMe`/`balanceOwedByMe`/`balanceSettled`, new `summaryTitle`.
- Produces:
  - `void showRunningSummarySheet(BuildContext context, {required List<Entry> entries, required Entry tapped, required Currency currency})` — computes the ascending series, slices to the tapped entry, and shows a modal bottom sheet: dated rows oldest→newest with the tapped entry anchored at the bottom (reverse-scroll), and the two gross totals + net balance pinned at the very bottom.
- Wire: entry `ListTile` gains `onTap: () => showRunningSummarySheet(context, entries: entries, tapped: entry, currency: widget.currency)`. Because tap must pass the **full** entry list (not the filtered `visible`), `_entryTile` needs the full `entries` list; thread it through `_dismissibleEntry`/`_entryTile` as a parameter.

- [ ] **Step 1: Write the failing widget test** — create `test/presentation/running_summary_sheet_test.dart`:

```dart
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/running_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e({
  required int id,
  Direction direction = Direction.owedToMe,
  required double amount,
  required DateTime when,
}) => Entry(
  id: id, contactId: 1, amount: amount, direction: direction,
  currency: Currency.sar, createdAt: when,
);

void main() {
  testWidgets('sheet shows gross totals and net up to the tapped entry',
      (tester) async {
    final entries = [
      e(id: 1, amount: 200, when: DateTime(2026, 3, 1)),
      e(id: 2, direction: Direction.owedByMe, amount: 50, when: DateTime(2026, 3, 2)),
      e(id: 3, amount: 190, when: DateTime(2026, 3, 3)),
    ];

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showRunningSummarySheet(
                context,
                entries: entries,
                tapped: entries[1], // up to Mar 2
                currency: Currency.sar,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Up to Mar 2: gross owed-to-me 200, gross owed-by-me 50, net 150 owed-to-me.
    expect(find.textContaining('Owed to you'), findsWidgets);
    expect(find.textContaining('You owe'), findsWidgets);
    expect(find.textContaining('200'), findsWidgets);
    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('150'), findsWidgets); // net closing balance
    // The later entry (id 3, Mar 3) is NOT included.
    expect(find.textContaining('190'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/running_summary_sheet_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../running_summary_sheet.dart'`.

- [ ] **Step 3: Write the sheet** — create `lib/presentation/contacts/running_summary_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/balance.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../domain/running_summary.dart';
import '../../l10n/gen/app_localizations.dart';
import '../money_format.dart';

const Color _green = Color(0xFF2E7D5B);
const Color _red = Color(0xFFC0392B);

/// Shows the running summary up to [tapped]: dated rows oldest→newest with the
/// tapped entry anchored at the bottom (older history scrolls up), and the two
/// gross directional totals + net closing balance pinned at the bottom. The
/// series is built from the full currency-scoped [entries]; [tapped] selects
/// how far it runs. See CONTEXT.md (Statement) and issue #16.
void showRunningSummarySheet(
  BuildContext context, {
  required List<Entry> entries,
  required Entry tapped,
  required Currency currency,
}) {
  final full = runningSummary(entries);
  final cut = full.indexWhere((r) => r.entry.id == tapped.id);
  final rows = cut < 0 ? full : full.sublist(0, cut + 1);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _RunningSummaryBody(rows: rows, currency: currency),
  );
}

class _RunningSummaryBody extends StatelessWidget {
  const _RunningSummaryBody({required this.rows, required this.currency});

  final List<RunningSummaryRow> rows;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final last = rows.isEmpty ? null : rows.last;
    final tappedDate = last == null
        ? ''
        : DateFormat.yMMMd(locale).format(last.entry.createdAt);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l10n.summaryTitle(tappedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            // Reverse list: newest (the tapped entry) pinned at the bottom,
            // older history scrolling upward.
            Flexible(
              child: ListView.separated(
                reverse: true,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[rows.length - 1 - index]; // newest first visually at bottom
                  return _summaryRowTile(context, locale, row);
                },
              ),
            ),
            const Divider(height: 1),
            _PinnedTotals(row: last, currency: currency),
          ],
        ),
      ),
    );
  }

  Widget _summaryRowTile(
    BuildContext context,
    String locale,
    RunningSummaryRow row,
  ) {
    final e = row.entry;
    final toMe = e.direction == Direction.owedToMe;
    final color = toMe ? _green : _red;
    final date = DateFormat.yMMMd(locale).format(e.createdAt);
    final sign = toMe ? '+' : '−';
    return ListTile(
      dense: true,
      title: Text(e.description?.isNotEmpty == true ? e.description! : date),
      subtitle: Text(date),
      trailing: Text(
        '$sign${formatMoney(e.amount, e.currency)}',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The two gross directional totals + net closing balance, pinned at the bottom.
class _PinnedTotals extends StatelessWidget {
  const _PinnedTotals({required this.row, required this.currency});

  final RunningSummaryRow? row;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = row;
    final toMe = r?.cumulativeOwedToMe ?? 0;
    final byMe = r?.cumulativeOwedByMe ?? 0;
    final balance = r?.balance ?? const Balance(0);

    String netLabel() {
      if (balance.isSettled) return l10n.balanceSettled;
      final amount = formatMoney(balance.magnitude, currency);
      return balance.isOwedToMe
          ? l10n.balanceOwedToMe(amount)
          : l10n.balanceOwedByMe(amount);
    }

    final netColor = balance.isSettled
        ? Theme.of(context).colorScheme.outline
        : (balance.isOwedToMe ? _green : _red);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _totalColumn(
                  context, l10n.homeTotalOwedToMe, formatMoney(toMe, currency), _green),
              ),
              Expanded(
                child: _totalColumn(
                  context, l10n.homeTotalOwedByMe, formatMoney(byMe, currency), _red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            netLabel(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: netColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _totalColumn(
    BuildContext context, String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          amount,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the sheet test to verify it passes**

Run: `flutter test test/presentation/running_summary_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the tap into the Contact page** — in `lib/presentation/contacts/contact_screen.dart`:

Add the import:

```dart
import 'running_summary_sheet.dart';
```

Thread the full entry list into the tile. Change `_dismissibleEntry` and `_entryTile` signatures to accept the full `entries` list, and set `onTap` on the `ListTile`:

- Update the `itemBuilder` call:

```dart
                        itemBuilder: (context, index) =>
                            _dismissibleEntry(context, l10n, entries, visible[index]),
```

- Update `_dismissibleEntry(...)` to take `List<Entry> allEntries` and pass it to `_entryTile`:

```dart
  Widget _dismissibleEntry(
    BuildContext context,
    AppLocalizations l10n,
    List<Entry> allEntries,
    Entry entry,
  ) {
    // ...unchanged Dismissible wrapper...
      child: _entryTile(context, l10n, allEntries, entry),
    );
  }
```

- Update `_entryTile(...)` signature and add `onTap` to its `ListTile`:

```dart
  Widget _entryTile(
    BuildContext context,
    AppLocalizations l10n,
    List<Entry> allEntries,
    Entry entry,
  ) {
    // ...existing colour/date/sign code unchanged...
    return ListTile(
      onTap: () => showRunningSummarySheet(
        context,
        entries: allEntries,
        tapped: entry,
        currency: widget.currency,
      ),
      leading: /* unchanged */,
      title: /* unchanged */,
      subtitle: /* unchanged */,
      trailing: /* unchanged */,
    );
  }
```

- [ ] **Step 6: Add a Contact-page tap test and run all Contact tests**

Append to `test/presentation/contact_screen_test.dart`:

```dart
  testWidgets('tapping an entry opens the running summary sheet', (tester) async {
    await entries.add(seed(contact.id!, Direction.owedToMe, 120));

    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Summary up to'), findsOneWidget);
    expect(find.textContaining('Owed to you'), findsWidgets);
  });
```

Run: `flutter test test/presentation/contact_screen_test.dart test/presentation/running_summary_sheet_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/contacts/running_summary_sheet.dart lib/presentation/contacts/contact_screen.dart test/presentation/running_summary_sheet_test.dart test/presentation/contact_screen_test.dart
git commit -m "feat: running-summary bottom sheet on entry tap (#16)"
```

---

### Task 11: Home — swipe edit/delete on Contact tiles (#5)

**Files:**
- Modify: `lib/presentation/home/home_screen.dart`
- Test: `test/presentation/home_screen_test.dart` (create)

**Interfaces:**
- Consumes: `ContactRepository.delete`, `ContactRepository.update`, `ContactRepository.entryCount`, `EntryRepository.listByContact`, `EntryRepository.add`, `AddContactScreen(existing:)`.
- Produces: each contact tile wrapped in a `Dismissible` keyed by `ValueKey('contact-${contact.id}')`. `startToEnd` = delete: fetch `entryCount`, show a confirm dialog whose body is `l10n.deleteContactMessage(count)`; on confirm, capture the contact's entries, delete (cascade), show an undo SnackBar that re-adds the contact and its entries. `endToStart` = edit name/phone via `AddContactScreen(existing: contact)`. Tap unchanged. New helpers: `_editContact(Contact)`, `_confirmDeleteContact(Contact) → Future<bool>`, `_deleteContact(Contact)`.

- [ ] **Step 1: Write the failing widget test** — create `test/presentation/home_screen_test.dart`:

```dart
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ContactRepository contacts;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });

  tearDown(() => appDb.close());

  testWidgets('swipe-to-delete a contact warns with the entry count', (tester) async {
    final contact = await contacts.add(const Contact(name: 'Sami'));
    await entries.add(Entry(
      contactId: contact.id!, amount: 10, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 7, 13),
    ));
    await entries.add(Entry(
      contactId: contact.id!, amount: 20, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 7, 14),
    ));

    await tester.pumpWidget(_wrap(
      HomeScreen(repository: contacts, entryRepository: entries),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible).first, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete contact?'), findsOneWidget);
    expect(find.textContaining('2 entries'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sami'), findsNothing);
    expect(await contacts.list(), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/home_screen_test.dart`
Expected: FAIL — no `Dismissible` found.

- [ ] **Step 3: Implement swipe edit/delete on contact tiles** — in `lib/presentation/home/home_screen.dart`:

Add imports:

```dart
import '../../domain/entry.dart';
```

(`add_contact_screen.dart` and `entry_repository.dart` are already imported.)

Wrap `_contactTile`'s `ListTile` in a `Dismissible`. Change the `itemBuilder` to call a new `_dismissibleContact`:

```dart
                        itemBuilder: (context, index) {
                          final contact = data.contacts[index];
                          final balance =
                              data.balances[contact.id] ?? const Balance(0);
                          return _dismissibleContact(context, l10n, contact, balance);
                        },
```

Add to `_HomeScreenState`:

```dart
  Widget _dismissibleContact(
    BuildContext context,
    AppLocalizations l10n,
    Contact contact,
    Balance balance,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('contact-${contact.id}'),
      background: Container(
        color: _red.withValues(alpha: 0.90),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 20),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      secondaryBackground: Container(
        color: Colors.blue.withValues(alpha: 0.85),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return _confirmDeleteContact(l10n, contact);
        } else {
          await _editContact(contact);
          return false;
        }
      },
      onDismissed: (_) => _deleteContact(contact),
      child: _contactTile(context, l10n, contact, balance),
    );
  }

  Future<bool> _confirmDeleteContact(AppLocalizations l10n, Contact contact) async {
    final count = await widget.entryRepository
        .listByContact(contact.id!)
        .then((list) => list.length);
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteContactTitle),
        content: Text(l10n.deleteContactMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteContact(Contact contact) async {
    // Capture the entries first so undo can restore the cascade.
    final removedEntries =
        await widget.entryRepository.listByContact(contact.id!);
    await widget.repository.delete(contact.id!);
    if (!mounted) return;
    setState(_load);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.contactDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            final restored =
                await widget.repository.add(contact.copyWith(id: null));
            for (final e in removedEntries) {
              await widget.entryRepository
                  .add(e.copyWith(id: null, contactId: restored.id));
            }
            if (mounted) setState(_load);
          },
        ),
      ));
  }

  Future<void> _editContact(Contact contact) async {
    final updated = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) =>
            AddContactScreen(repository: widget.repository, existing: contact),
      ),
    );
    if (updated != null && mounted) setState(_load);
  }
```

> The confirm dialog uses `listByContact(...).length` (all currencies via no `currency` arg) rather than `entryCount` to reuse an already-imported method and keep the captured list consistent with the count shown. This is equivalent to `entryCount`. (`entryCount` from Task 2 remains available for other callers, e.g. #10's statement.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/home/home_screen.dart test/presentation/home_screen_test.dart
git commit -m "feat: swipe to edit/delete contacts with cascade warning + undo (#5)"
```

---

### Task 12: Full verification, live device check, docs, merge

**Files:**
- Modify: `CONTEXT.md` (add the running-summary term)
- (No code changes unless verification uncovers a defect.)

- [ ] **Step 1: Full analyze + test sweep**

Run: `flutter analyze && flutter test`
Expected: analyze reports no issues; all tests pass. Fix anything red before proceeding.

- [ ] **Step 2: Document the new domain term** — add to `CONTEXT.md` under the glossary (after the `Statement` entry):

```markdown
### Running summary
An on-screen, per-Contact, per-currency preview of the [[Statement]] up to a
chosen Entry's date: the dated entries oldest→newest (tapped entry anchored at
the bottom) with the two **gross** directional running totals (owed-to-me and
owed-by-me) and the net closing [[Balance]]. Built by a pure series function
reused by the [[Analysis graph]] (#8) and the PDF [[Statement]] (#10).

- Arabic: الملخّص الجاري
```

Commit:

```bash
git add CONTEXT.md
git commit -m "docs: define the running summary term (#16)"
```

- [ ] **Step 3: Build and install on the device**

```bash
flutter build apk --debug
# adb alias if needed: Set-Alias adb (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe")
adb -s ZY22LN3RN6 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s ZY22LN3RN6 shell am start -n cloud.smapp.debt_ledger/.MainActivity
```

- [ ] **Step 4: Drive the five acceptance flows live (Arabic RTL)**

Screenshot after each with `adb -s ZY22LN3RN6 exec-out screencap -p > out.png` then Read the png. Device is 1220×2712; earlier screenshots displayed at 900×2000 → multiply taps by ~1.36. Use `input swipe X1 Y1 X2 Y2` for the swipe gestures.

Verify:
1. **Edit an entry** (swipe toward start on an entry) → change amount → balance recomputes.
2. **Swipe-delete an entry** (swipe toward end) → confirm dialog → confirm → undo SnackBar → tap Undo → entry restored, balance back.
3. **Delete a Contact** (swipe toward end on a home tile) → dialog states the entry count → confirm → contact + its entries gone (check the other currency lens too).
4. **Tap an entry** → running-summary sheet: dated rows, tapped entry at bottom, two gross totals + net pinned.
5. **RTL swipe direction**: confirm in Arabic the red delete reveal is on the "end" swipe and edit on the "start" swipe (mirrored from LTR), for both entries and contacts.

- [ ] **Step 5: Update issue acceptance + finish the branch**

Confirm every acceptance checkbox in #5, #15, #16. Then use the **superpowers:finishing-a-development-branch** skill to merge `--no-ff` into `main` with `closes #5 closes #15 closes #16` in the merge commit, push, and post acceptance-summary comments via `gh issue comment`.

---

## Self-Review

**Spec coverage:**
- #5 edit Entry each field + balance recompute → Task 6 (edit form) + Task 9 (wire) ✓
- #5 delete Entry confirm + undo → Task 9 ✓
- #5 edit Contact name/phone → Task 7 + Task 11 (wire) ✓
- #5 delete Contact warns with count + cascade → Task 2 (repo cascade/count) + Task 11 ✓
- #5 repo cascade test + widget delete-confirm test → Task 2 + Task 9/Task 11 ✓
- #15 search box filters description → Task 4 + Task 8 ✓
- #15 sort date/value/description asc+desc → Task 4 + Task 8 ✓
- #15 pure comparators unit-tested → Task 4 ✓
- #16 tap → summary up to date → Task 10 ✓
- #16 gross totals + net, per currency → Task 3 + Task 10 ✓
- #16 ascending, tapped anchored bottom, history up → Task 10 (reverse ListView) ✓
- #16 pure series builder unit-tested → Task 3 ✓
- No schema migration; RTL via directional widgets; l10n both files → Tasks 5, 9, 11, 12 ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. The `_entryTile`/`_dismissibleEntry` edits in Task 10 reference "unchanged" only for blocks fully written in Task 9 (same file, sequential) — acceptable since the engineer has the prior task's code in the file.

**Type consistency:** `runningSummary` → `List<RunningSummaryRow>` with `entry`/`cumulativeOwedToMe`/`cumulativeOwedByMe`/`balance` used identically in Tasks 3 and 10. `sortEntries`/`filterEntriesByDescription`/`EntrySortField` signatures match between Tasks 4 and 8. `EntryRepository.update(Entry)`/`delete(int)` and `ContactRepository.update/delete/entryCount` consistent across Tasks 1–2 and 6–11. `AddEntryScreen(existing:)`/`AddContactScreen(existing:)` consistent across Tasks 6–7 and 9–11.

**Note on Task 11 count source:** uses `listByContact(id).length` (all currencies) for the warning to keep the shown count and the captured undo list identical; `entryCount` from Task 2 is still built and tested for #10's reuse.
