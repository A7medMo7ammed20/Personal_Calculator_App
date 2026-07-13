# Slice 5 Design — Edit/Delete + entry search/sort + running summary

**Date:** 2026-07-13
**Branch:** `slice-5-edit-delete`
**Issues:** #5 (edit/delete, base) · #15 (entry search/sort, new) · #16 (running summary, new)

## Goal

Make Entries and Contacts editable and deletable safely, and enrich the Contact
page with per-Contact entry search/sort and a tap-to-view running summary
(statement preview). All three ship in one branch and close together on merge.

Editing is in place with **no audit trail**. Deletion is the one irreversible
action and carries confirmation friction (Entry: confirm + undo; Contact:
confirm stating cascade count + undo). These are locked decisions from slices
1–4 and issue #5.

## Scope

| Issue | Feature | Notes |
|-------|---------|-------|
| #5  | Edit/delete Entries and Contacts | Base spec; authoritative acceptance criteria unchanged. |
| #15 | Per-Contact entry search + sort | New tracked issue; ships in this branch. |
| #16 | Running summary / statement preview | New tracked issue; ships in this branch. |

Out of scope: the Analysis **chart** (#8) — but the running-summary series
builder here is the pure seam #8 (and the PDF Statement #10) will reuse.

## Domain layer (pure, test-first)

### Running summary series — `lib/domain/running_summary.dart` (NEW)

A pure builder over **date-ascending** entries (single currency). For each
entry it emits a row carrying:

- the `Entry` itself,
- **cumulative owed-to-me** (gross sum of `owedToMe` amounts up to & incl. this entry),
- **cumulative owed-by-me** (gross sum of `owedByMe` amounts up to & incl. this entry),
- **net balance** after this entry (`Balance`, reusing the sign convention).

The two cumulative figures are **gross directional running totals** (total lent
vs. total repaid/owed-by-me), matching the PDF Statement's two columns
(owed-to-me | owed-by-me) plus closing balance. This is the on-screen precursor
to the Statement (#10) and reuses the same mental model. Scoped to the active
currency lens (caller passes already-filtered entries).

Tested in the house style of `balanceOf` / `totalsOf`: empty list, single
entry, mixed directions, repayment crossing zero, magnitude/net correctness at
each step.

### Entry sort/filter comparators — `lib/domain/entry_sort.dart` (NEW)

Pure functions:

- Sort by **date**, **value** (signed amount magnitude), **description**; each
  with ascending/descending.
- Description substring filter (case-insensitive, trims).

Kept pure and independently tested so #6 (home Contacts search/sort) can reuse
the same comparator style cheaply.

## Data layer

- `lib/data/entry_repository.dart`: add `update(Entry)` and `delete(int id)`,
  mirroring `add` (row-map stays here). Undo re-inserts the deleted Entry.
- `lib/data/contact_repository.dart`: add `update(Contact)`, `delete(int id)`,
  and `entryCount(int contactId)` — a count of **all** the contact's entries
  (every currency; cascade ignores the lens) for the delete warning.
- No schema migration — schema stays at version 3; edit/delete add no columns.
  `PRAGMA foreign_keys = ON` already cascades Contact → Entries (proven in slice 3).

## Presentation layer

### Contact page — `lib/presentation/contacts/contact_screen.dart`

Main canvas for all three features.

**Search + sort (#15).** A search box (filters entry descriptions) and a sort
control at the top of the page. Sort cycles Date / Value / Description; tapping
the active field toggles asc↔desc. Filtering and sorting are applied in-memory
to the loaded currency-scoped list via the pure comparators — no new query.

**Swipe edit/delete (#5).** Each entry tile wrapped in a `Dismissible`:

- swipe → **end**: **delete** (red background, trash icon). `confirmDismiss`
  shows a confirmation dialog; on confirm the entry is deleted and a brief
  **undo** SnackBar re-inserts it. Balance recomputes.
- swipe → **start**: **edit** (blue background, pencil icon). `confirmDismiss`
  navigates to the edit form and returns `false` (tile is not dismissed);
  balance recomputes on return.

Directions are chosen by semantic `startToEnd` / `endToStart`, so they flip
correctly under Arabic RTL. Tested in both locales.

**Running summary on tap (#16).** Entry tiles gain `onTap` (they have none
today) → opens a **bottom sheet**:

- Dated rows, oldest → newest, built from the running-summary series up to &
  including the tapped entry. The tapped entry is anchored at the **bottom**;
  older history scrolls **up** (reverse-scroll list).
- Pinned at the very bottom: the two gross directional totals ("Owed to you N"
  / "You owe N") as of the tapped date, plus the net closing balance.
- Dismissed by swiping down / tapping the scrim.

`onTap` (summary) and horizontal swipe (edit/delete) are a clean, non-conflicting
gesture split.

### Add/Edit forms

- `lib/presentation/entries/add_entry_screen.dart`: accept an optional existing
  `Entry`; when present, prefill all fields and call `repository.update`
  instead of `add`. Currency lens still inherited (no in-form picker). Title and
  primary action adapt (Add vs Save).
- `lib/presentation/contacts/add_contact_screen.dart`: same generalization for a
  Contact's name and phone.

### Home — `lib/presentation/home/home_screen.dart`

Contact tiles wrapped in `Dismissible` (same gesture language as entries):

- swipe → **end**: **delete** — dialog **states the cascade entry count**
  (from `entryCount`) and, on confirm, cascade-deletes; undo SnackBar re-inserts
  the Contact (and, on undo, its entries too — see Undo note).
- swipe → **start**: **edit** name/phone.
- tap unchanged (opens Contact page).

## Undo semantics

- **Entry delete undo:** re-insert the deleted `Entry` (re-add via repository).
  Simple; a new row id is fine — nothing references entry ids.
- **Contact delete undo:** deleting a Contact cascades its entries. Undo must
  restore the Contact **and** its entries. Capture the contact + its full entry
  list before delete; on undo, re-insert the contact then re-add each entry
  under the new contact id. (If this proves fiddly, fall back to a longer
  confirm and drop Contact-undo — but attempt full restore first.)

## l10n

New strings (Edit entry/contact, Delete, confirm dialogs, cascade-count
message, undo, search hint, sort labels, running-summary labels) added to
**both** `lib/l10n/app_en.arb` and `app_ar.arb`; run `flutter gen-l10n`. Import
`package:debt_ledger/l10n/gen/app_localizations.dart`.

## Testing

Unit/domain (pure):
- Running-summary series: empty, single, mixed directions, repayment crossing
  zero; gross totals and net correct at each step.
- Sort comparators: date/value/description asc+desc; description filter.

Repository:
- Entry `update` reflects new values; `delete` removes the row.
- Contact `update`; `delete` cascade-deletes entries (extends slice-3 test);
  `entryCount` correct across currencies.

Widget:
- Entry delete confirmation dialog appears; undo restores (both locales for
  swipe direction).
- Contact delete dialog shows the entry count.
- Running-summary sheet shows dated rows + pinned totals for a tapped entry.

Live device (per handoff, device `ZY22LN3RN6`, Arabic RTL):
- Edit an entry → balance recomputes.
- Swipe-delete an entry → confirm + undo restores.
- Delete a Contact → count warning → cascade removes its entries.
- Tap an entry → running summary bottom sheet.
- Swipe directions behave correctly in RTL.

## Acceptance criteria

**#5**
- [ ] Edit each field of an Entry; Balance recomputes.
- [ ] Delete an Entry asks confirmation + offers short undo; undo restores.
- [ ] Edit a Contact's name and phone.
- [ ] Deleting a Contact warns with the count of entries to be deleted.
- [ ] Confirming Contact delete cascade-removes the Contact and its entries.
- [ ] Repository tests verify cascade delete; widget test verifies delete confirm.

**#15**
- [ ] Search box filters the Contact's entries by description.
- [ ] Sort by date / value / description, ascending and descending.
- [ ] Comparators are pure and unit-tested.

**#16**
- [ ] Tapping an entry opens a summary up to that entry's date.
- [ ] Summary shows gross owed-to-me and owed-by-me totals (per active currency)
      plus the net closing balance.
- [ ] Dated rows ascending by date, tapped entry anchored at bottom, older
      history scrolling up.
- [ ] Running-summary series builder is pure and unit-tested.

## Gotchas (carried from handoff)

1. Widget tests must use `databaseFactoryFfiNoIsolate`.
2. l10n import path is `l10n/gen/`.
3. `Dismissible` + RTL: choose directions by semantic (start/end); test both locales.
4. Live device locale is Arabic (RTL); assert typed strings in widget tests, not live input.
5. Analyzer excludes `lib/l10n/gen/**`; generated files are committed.
