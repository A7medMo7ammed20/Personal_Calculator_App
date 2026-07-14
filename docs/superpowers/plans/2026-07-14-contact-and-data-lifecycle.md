# Contact & Data Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship PRD #25 — a contact-and-data lifecycle (reset / archive / erase), a faster home-first add flow, two Arabic PDF statement fixes, and a shorter splash — on the Daftar (دفتر) debt ledger.

**Architecture:** Flutter, clean layers — pure `domain/` (no Flutter/DB), `data/` repositories over SQLite (`sqflite`), `presentation/` widgets + `ChangeNotifier` controllers. New behavior is pushed into pure functions (settle builder, statement-period formatter) and repository queries wherever possible, keeping widgets thin. Archived-contact exclusion happens **in the SQL queries** (a `contact_id IN (SELECT id FROM contacts WHERE archived = 0)` sub-filter), never by hiding rows, so totals/analysis can't leak an archived balance.

**Tech Stack:** Flutter, `sqflite` / `sqflite_common_ffi` (tests), `intl`, `pdf` + `printing`, `flutter_slidable`, `url_launcher`, gen-l10n (ARB → `AppLocalizations`).

## Global Constraints

- **Terminology** follows CONTEXT.md. Use the cycle's new glossary vocabulary in code + UI: **Reset account** (تصفير الحساب; settle Entry description تسوية), **Archive** (أرشفة / الأرشيف), **Delete contact** (حذف), **Erase all data** (مسح جميع البيانات). Entry = معاملة; Contact = جهة الاتصال.
- **Every new user-facing string is localized in both `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`** and must render under RTL. `app_en.arb` carries `@key` metadata; `app_ar.arb` is bare key→value. After editing ARB files run `flutter gen-l10n` (or `flutter pub get`) to regenerate `lib/l10n/gen/`. All new keys are catalogued once in **Appendix A** — add them all in Task 0 so later tasks can reference `l10n.<key>` freely.
- **Currency is per active lens.** Reset settles only the active lens; home-added معاملة inherits the active lens; the two currencies never sum.
- **Balance is all-time, never windowed.** Reset appends a balancing Entry (never a special record). Statement closing balance stays all-time even under a date filter.
- **Schema migrations** live in `AppDatabase._migrate` as `if (from < N)` blocks; a fresh install (`from == 0`) runs every block, so fresh + upgraded land identically. Bump `AppDatabase.schemaVersion` when adding the block.
- **Test factories:** repository/pure DB tests use `databaseFactoryFfi`; **widget** tests that touch the DB use `databaseFactoryFfiNoIsolate` (a `testWidgets` FakeAsync zone can't drive sqflite's background isolate). Always `setUpAll(sqfliteFfiInit)` and `addTearDown`/`tearDown` `appDb.close`.
- **TDD, frequent commits.** Each task: red → green → commit. Run `flutter analyze` before each commit; keep it clean.
- Commit message convention (from history): `feat:`/`fix:`/`refactor:`/`test:`/`style:`/`build:` + short imperative, suffixed `(#25)`.

---

## File Structure

**New files**
- `lib/domain/settle.dart` — pure `buildSettleEntry(...)` (Reset account).
- `lib/domain/statement_period.dart` — pure `statementPeriodLabel(...)` (Arabic PDF header).
- `lib/presentation/entries/entry_fields.dart` — extracted shared entry-form fields (amount/direction/date-time/description), reused by add-entry, quick-add-معاملة, and add-contact's optional first entry.
- `lib/presentation/entries/add_transaction_screen.dart` — home-first *Add معاملة* (inline contact picker + entry fields).
- `lib/presentation/home/quick_add_speed_dial.dart` — the home "＋" speed-dial (two labeled actions).
- `lib/presentation/contacts/archived_contacts_screen.dart` — the Archived view.
- Tests mirroring each under `test/…`.

**Modified files**
- `lib/branding/daftar_splash.dart` — shorten + tap-to-skip.
- `lib/presentation/statements/statement_pdf.dart` — period line + totals-row footer.
- `lib/domain/contact.dart` — add `archived`.
- `lib/data/app_database.dart` — schema v5 (`archived` column) + `eraseAll()`.
- `lib/data/contact_repository.dart` — active-only `list()`, `listArchived()`, `setArchived()`.
- `lib/data/entry_repository.dart` — archived-exclusion in the four aggregate queries.
- `lib/presentation/contacts/contact_screen.dart` — overflow ⋮ menu (Reset + Archive), auto-unarchive on add-entry.
- `lib/presentation/contacts/add_contact_screen.dart` — optional first-معاملة section.
- `lib/presentation/entries/add_entry_screen.dart` — consume `EntryFields`.
- `lib/presentation/home/home_screen.dart` — speed-dial FAB; Archived-view menu entry; Erase wiring pass-through.
- `lib/presentation/settings/settings_screen.dart` — Erase-all-data section (type-to-confirm).
- `lib/app.dart` / `lib/main.dart` — pass `AppDatabase` + erase orchestration; controllers reload to defaults.
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` — new strings.

---

## Task 0: Localized strings + baseline docs

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Modify: `CONTEXT.md` (already edited in working tree), `docs/adr/0009-contact-and-data-lifecycle.md` (already in working tree)

- [ ] **Step 1: Add every new key** from **Appendix A** to `app_en.arb` (with `@key` metadata blocks) and `app_ar.arb` (bare key→value). Keep existing trailing-comma/format style.
- [ ] **Step 2: Regenerate l10n.** Run: `flutter gen-l10n`. Expected: `lib/l10n/gen/app_localizations*.dart` updated, no errors.
- [ ] **Step 3: Analyze.** Run: `flutter analyze`. Expected: no issues.
- [ ] **Step 4: Commit** the design baseline + strings together.

```bash
git add CONTEXT.md docs/adr/0009-contact-and-data-lifecycle.md \
        lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/gen
git commit -m "feat(l10n): lifecycle glossary + strings for reset/archive/erase/quick-add (#25)"
```

---

# Phase 1 — Splash speed-up (isolated, lowest risk)

## Task 1: Shorten the splash and make it tap-to-skip

**Files:**
- Modify: `lib/branding/daftar_splash.dart`
- Test: `test/branding/daftar_splash_test.dart` (create)

**Interfaces:**
- Produces: `DaftarSplash({VoidCallback? onDone, Duration duration = 700ms, Duration hold = 300ms})` — `onDone` fires **at most once** (auto-complete OR tap, whichever first).

- [ ] **Step 1: Write the failing test.**

```dart
// test/branding/daftar_splash_test.dart
import 'package:debt_ledger/branding/daftar_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the splash skips to done immediately', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: DaftarSplash(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 100)); // mid-animation
    await tester.tap(find.byType(DaftarSplash));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('completes on its own within ~1s', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: DaftarSplash(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 700)); // draw
    await tester.pump(const Duration(milliseconds: 350)); // hold
    expect(done, 1);
  });

  testWidgets('never calls onDone twice (tap then auto-complete)', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: DaftarSplash(onDone: () => done++)));
    await tester.tap(find.byType(DaftarSplash));
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`done` stays 0 on tap; current defaults are 2200/600 so the ~1s test fails too). Run: `flutter test test/branding/daftar_splash_test.dart`
- [ ] **Step 3: Implement.** In `daftar_splash.dart`: change constructor defaults to `duration = const Duration(milliseconds: 700)` and `hold = const Duration(milliseconds: 300)`. Add a `bool _finished = false;` and a guarded finisher; route both the auto-complete and a new tap through it; wrap the body in an opaque `GestureDetector`.

```dart
// defaults
this.duration = const Duration(milliseconds: 700),
this.hold = const Duration(milliseconds: 300),
```
```dart
// _DaftarSplashState
bool _finished = false;

void _finish() {
  if (_finished) return;
  _finished = true;
  widget.onDone?.call();
}
```
Replace the `whenComplete` tail:
```dart
_c.forward().whenComplete(() async {
  await Future<void>.delayed(widget.hold);
  if (mounted) _finish();
});
```
Wrap the scaffold body:
```dart
return Scaffold(
  backgroundColor: DaftarColors.teal,
  body: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _finish,
    child: Center(
      child: AnimatedBuilder(/* …unchanged… */),
    ),
  ),
);
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/branding/daftar_splash_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/branding/daftar_splash.dart test/branding/daftar_splash_test.dart
git commit -m "feat: splash ~1s + tap-to-skip (#25)"
```

---

# Phase 2 — PDF Arabic statement-period header

## Task 2: Pure statement-period formatter

**Files:**
- Create: `lib/domain/statement_period.dart`
- Test: `test/domain/statement_period_test.dart`

**Interfaces:**
- Produces: `String statementPeriodLabel({required DateRange? range, required DateFormat dateFormat, required String allTimeLabel})` — null range → `allTimeLabel`; else each date wrapped in FSI(`⁨`)…PDI(`⁩`) isolates, start before end, printed end = last **included** day (`endExclusive − 1 day`).

- [ ] **Step 1: Write the failing test.**

```dart
// test/domain/statement_period_test.dart
import 'package:debt_ledger/domain/period.dart';
import 'package:debt_ledger/domain/statement_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  const fsi = '⁨', pdi = '⁩';

  test('wraps each date in bidi isolates, start before end', () {
    final fmt = DateFormat.yMMMd('ar');
    final label = statementPeriodLabel(
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      dateFormat: fmt,
      allTimeLabel: 'كل الوقت',
    );
    expect(fsi.allMatches(label).length, 2);
    expect(pdi.allMatches(label).length, 2);
    final start = fmt.format(DateTime(2026, 7, 1));
    final end = fmt.format(DateTime(2026, 7, 31)); // exclusive end − 1 day
    expect(label, contains('$fsi$start$pdi'));
    expect(label, contains('$fsi$end$pdi'));
    expect(label.indexOf(start), lessThan(label.indexOf(end)));
  });

  test('all-time range renders the plain all-time label', () {
    expect(
      statementPeriodLabel(
        range: null,
        dateFormat: DateFormat.yMMMd('en'),
        allTimeLabel: 'All time',
      ),
      'All time',
    );
  });

  test('printed end is the last included day, not the exclusive end', () {
    final fmt = DateFormat.yMMMd('en');
    final label = statementPeriodLabel(
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      dateFormat: fmt,
      allTimeLabel: 'All time',
    );
    expect(label, contains(fmt.format(DateTime(2026, 7, 31))));
    expect(label, isNot(contains(fmt.format(DateTime(2026, 8, 1)))));
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`statement_period.dart` doesn't exist). Run: `flutter test test/domain/statement_period_test.dart`
- [ ] **Step 3: Implement.**

```dart
// lib/domain/statement_period.dart
import 'package:intl/intl.dart';

import 'period.dart';

const String _fsi = '⁨'; // First Strong Isolate
const String _pdi = '⁩'; // Pop Directional Isolate

/// Formats a statement's period value (ADR 0009). Each date is wrapped in bidi
/// isolates so the mix of Latin digits, Arabic month names and the neutral dash
/// never reorders under RTL, and the pair always reads start-then-end. Returns
/// [allTimeLabel] for a null (all-time) [range]. Pure — no PDF, unit-testable.
String statementPeriodLabel({
  required DateRange? range,
  required DateFormat dateFormat,
  required String allTimeLabel,
}) {
  if (range == null) return allTimeLabel;
  final start = dateFormat.format(range.start);
  final end = dateFormat.format(
    range.endExclusive.subtract(const Duration(days: 1)),
  );
  return '$_fsi$start$_pdi – $_fsi$end$_pdi';
}
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/domain/statement_period_test.dart`
- [ ] **Step 5: Commit.**

```bash
git add lib/domain/statement_period.dart test/domain/statement_period_test.dart
git commit -m "feat: pure statement-period formatter with bidi isolates (#25)"
```

## Task 3: Render the period on its own labeled line

**Files:**
- Modify: `lib/presentation/statements/statement_pdf.dart:124-150` (`_header`)
- Test: `test/presentation/statement_pdf_test.dart` (add a filtered-RTL smoke case)

**Interfaces:**
- Consumes: `statementPeriodLabel(...)` (Task 2), `l10n.statementPeriod`, `l10n.periodAllTime`.

- [ ] **Step 1: Add the failing smoke test** (a filtered Arabic statement must still render a valid PDF).

```dart
// add inside test/presentation/statement_pdf_test.dart main()
testWidgets('renders a valid PDF for a filtered RTL statement', (tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  final doc = buildStatement(
    profile: const Profile(name: 'Ahmed'),
    contact: const Contact(id: 1, name: 'Khaled'),
    entries: [_entry(100, Direction.owedToMe, DateTime(2026, 7, 5), id: 1)],
    currency: Currency.sar,
    range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
    isRtl: true,
  );
  final bytes = await renderStatementPdf(doc, l10n, 'ar');
  expect(_isPdf(bytes), isTrue);
});
```
Add the import `import 'package:debt_ledger/domain/period.dart';` to the test file.

- [ ] **Step 2: Run — expect FAIL** (`l10n.statementPeriod` compiles only after Task 0; if Task 0 done, this test passes trivially against the *old* header — so treat Step 2 as: run the full `statement_pdf_test.dart` and confirm green before refactor, then refactor and keep green). Run: `flutter test test/presentation/statement_pdf_test.dart`
- [ ] **Step 3: Implement the header change.** In `_header`, replace the `period` computation and the combined currency/period line:

```dart
// was: final range = doc.dateRange; final period = range == null ? … : '… – …';
final period = statementPeriodLabel(
  range: doc.dateRange,
  dateFormat: dateFormat,
  allTimeLabel: l10n.periodAllTime,
);
```
and the trailing children of the header `Column` (replace the single `pw.Text('${doc.currency.code} · $period')`):
```dart
pw.Text('${l10n.statementFrom}: ${doc.creditorName}'),
pw.Text('${l10n.statementTo}: $to'),
pw.Text(doc.currency.code),
pw.Text('${l10n.statementPeriod}: $period'),
```
Add `import '../../domain/statement_period.dart';` at the top.

- [ ] **Step 4: Run — expect PASS** (all four smoke cases). Run: `flutter test test/presentation/statement_pdf_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/statements/statement_pdf.dart test/presentation/statement_pdf_test.dart
git commit -m "fix: Arabic statement period on its own labeled line, bidi-isolated (#25)"
```

---

# Phase 3 — PDF total-row footer

## Task 4: Total row reads as a statement footer

**Files:**
- Modify: `lib/presentation/statements/statement_pdf.dart:184-194` (totals `TableRow` in `_entriesTable`)
- Test: `test/presentation/statement_pdf_test.dart` (existing smokes cover render; add an all-time footer smoke)

**Interfaces:**
- Consumes: `doc.closingBalance`, `balanceAmount`, `balanceColor` (already threaded into `_entriesTable`). NOTE: `_entriesTable` currently receives `balanceAmount`/`balanceColor` — reuse them; no signature change needed.

- [ ] **Step 1: Add a smoke assertion** that a rendered statement is valid with the new footer (LTR + RTL already covered by existing tests, which will re-exercise the changed row). Add:

```dart
// add inside test/presentation/statement_pdf_test.dart main()
testWidgets('renders a valid PDF after the footer rework (RTL)', (tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  final bytes = await renderStatementPdf(_doc(isRtl: true), l10n, 'ar');
  expect(_isPdf(bytes), isTrue);
});
```

- [ ] **Step 2: Run — expect PASS pre-change** (baseline green). Run: `flutter test test/presentation/statement_pdf_test.dart`
- [ ] **Step 3: Implement.** Replace the totals `TableRow` (the one decorated `PdfColors.grey100`) so the الإجمالي label sits in the **description** cell, the date cell is empty, gross totals stay under their columns, and the **balance** cell terminates with the closing balance:

```dart
// Footer row: label in the description cell, gross totals under their columns,
// and the closing balance terminating the balance column (ADR 0009).
pw.TableRow(
  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
  children: [
    _cell(''),
    _cell(l10n.statementTotal, bold: true),
    _cell(money(doc.totalOwedToMe), align: pw.TextAlign.end, bold: true),
    _cell(money(doc.totalOwedByMe), align: pw.TextAlign.end, bold: true),
    _cell(
      balanceAmount(doc.closingBalance),
      color: balanceColor(doc.closingBalance),
      align: pw.TextAlign.end,
      bold: true,
    ),
  ],
),
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/presentation/statement_pdf_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/statements/statement_pdf.dart test/presentation/statement_pdf_test.dart
git commit -m "fix: statement totals row reads as a footer, closing balance in balance column (#25)"
```

---

# Phase 4 — Reset account

## Task 5: Pure settle-entry builder

**Files:**
- Create: `lib/domain/settle.dart`
- Test: `test/domain/settle_test.dart`

**Interfaces:**
- Produces: `Entry? buildSettleEntry({required int contactId, required Balance balance, required Currency currency, required DateTime createdAt, required String description})` — returns `null` when `balance.isSettled`; else an Entry of the **opposite** direction, `amount = balance.magnitude`, in `currency`, so `balanceOf([...history, settle]).isSettled` is true.

- [ ] **Step 1: Write the failing test.**

```dart
// test/domain/settle_test.dart
import 'package:debt_ledger/domain/balance.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/settle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final when = DateTime(2026, 7, 14, 12);

  test('owed-to-me balance settles with an owed-by-me entry of equal magnitude', () {
    final settle = buildSettleEntry(
      contactId: 7,
      balance: const Balance(300),
      currency: Currency.sar,
      createdAt: when,
      description: 'تسوية',
    )!;
    expect(settle.contactId, 7);
    expect(settle.direction, Direction.owedByMe);
    expect(settle.amount, 300);
    expect(settle.currency, Currency.sar);
    expect(settle.createdAt, when);
    expect(settle.description, 'تسوية');
    expect(balanceOf([const Entry(contactId: 7, amount: 300, direction: Direction.owedToMe, currency: Currency.sar, createdAt: DateTimeStub.epoch), settle]).isSettled, isTrue);
  });

  test('owed-by-me balance settles with an owed-to-me entry', () {
    final settle = buildSettleEntry(
      contactId: 1, balance: const Balance(-42.5), currency: Currency.yer,
      createdAt: when, description: 'تسوية')!;
    expect(settle.direction, Direction.owedToMe);
    expect(settle.amount, 42.5);
    expect(settle.currency, Currency.yer);
  });

  test('a settled balance yields no settle entry', () {
    expect(
      buildSettleEntry(contactId: 1, balance: const Balance(0), currency: Currency.sar, createdAt: when, description: 'تسوية'),
      isNull,
    );
  });
}
```
Replace the inline `DateTimeStub.epoch` with a literal `DateTime(2026, 1, 1)` — the balance-settles assertion only needs any timestamp. (Final test: use `createdAt: DateTime(2026, 1, 1)` in the history entry.)

- [ ] **Step 2: Run — expect FAIL** (`settle.dart` missing). Run: `flutter test test/domain/settle_test.dart`
- [ ] **Step 3: Implement.**

```dart
// lib/domain/settle.dart
import 'balance.dart';
import 'currency.dart';
import 'entry.dart';

/// Builds the single balancing [Entry] that zeroes [balance] in [currency]
/// (Reset account, ADR 0009): opposite direction, magnitude `|balance|`, with a
/// recognizable settle [description] (Arabic تسوية). Returns `null` when the
/// balance is already settled — the caller disables Reset in that case. A settle
/// *is* just an Entry: the statement and analysis need no special case. Pure.
Entry? buildSettleEntry({
  required int contactId,
  required Balance balance,
  required Currency currency,
  required DateTime createdAt,
  required String description,
}) {
  if (balance.isSettled) return null;
  return Entry(
    contactId: contactId,
    amount: balance.magnitude,
    direction: balance.isOwedToMe ? Direction.owedByMe : Direction.owedToMe,
    currency: currency,
    createdAt: createdAt,
    description: description,
  );
}
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/domain/settle_test.dart`
- [ ] **Step 5: Commit.**

```bash
git add lib/domain/settle.dart test/domain/settle_test.dart
git commit -m "feat: pure settle-entry builder for Reset account (#25)"
```

## Task 6: Reset action in a Contact-screen overflow (⋮) menu

**Files:**
- Modify: `lib/presentation/contacts/contact_screen.dart` (AppBar actions; add `_resetAccount`)
- Test: `test/presentation/contact_reset_test.dart` (create)

**Interfaces:**
- Consumes: `buildSettleEntry(...)`, `EntryRepository.add`, `l10n.resetAccount/reset/resetAccountTitle/resetAccountMessage/settleEntryDescription`.
- Produces: an AppBar `PopupMenuButton<_ContactMenuAction>` whose `_ContactMenuAction.reset` item is **disabled** when the current lens balance `isSettled`.

- [ ] **Step 1: Write the failing widget test.** (Host `ContactScreen` over a NoIsolate in-memory DB with one owed-to-me entry, so balance = owed-to-me 300.)

```dart
// test/presentation/contact_reset_test.dart
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/contact_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase appDb;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    entries = EntryRepository(appDb);
  });
  tearDown(() => appDb.close());

  Widget host(Contact c) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ContactScreen(contact: c, repository: entries, currency: Currency.sar),
      );

  testWidgets('reset settles the balance by adding one settle entry', (tester) async {
    const c = Contact(id: 1, name: 'Ali');
    await entries.add(const Entry(contactId: 1, amount: 300, direction: Direction.owedToMe, currency: Currency.sar, createdAt: _t));
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset account'));
    await tester.pumpAndSettle();
    // Confirm dialog names the amount, then confirm.
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    final all = await entries.listByContact(1);
    expect(all.length, 2); // original + settle
    expect(find.text('Settled'), findsWidgets); // balance header now settled
  });

  testWidgets('reset item is disabled when already settled', (tester) async {
    const c = Contact(id: 1, name: 'Ali'); // no entries → settled
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-overflow')));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem>(find.widgetWithText(PopupMenuItem, 'Reset account'));
    expect(item.enabled, isFalse);
  });
}

const _t = DateTimeConst();
```
Replace `_t`/`DateTimeConst()` with a real `DateTime(2026, 7, 1)` constant expression: declare `final _t = DateTime(2026, 7, 1);` outside `main` and drop the `const` on the entry (use a non-const `Entry(...)`).

- [ ] **Step 2: Run — expect FAIL** (no overflow menu). Run: `flutter test test/presentation/contact_reset_test.dart`
- [ ] **Step 3: Implement.** In `contact_screen.dart`:
  - Add `enum _ContactMenuAction { reset }` (Archive joins in Task 16).
  - Add imports: `import '../../domain/settle.dart';`.
  - In `build`, compute the current balance (already available as `balance` inside the `FutureBuilder`; but the AppBar is outside it). Track the loaded balance on state: reuse `_loaded` (the mirror list) → `balanceOf(_loaded)`. Add the overflow button to `AppBar.actions` after the export button:

```dart
PopupMenuButton<_ContactMenuAction>(
  key: const Key('contact-overflow'),
  onSelected: (a) {
    switch (a) {
      case _ContactMenuAction.reset:
        _resetAccount(balanceOf(_loaded));
    }
  },
  itemBuilder: (context) => [
    PopupMenuItem(
      value: _ContactMenuAction.reset,
      enabled: !balanceOf(_loaded).isSettled,
      child: Text(l10n.resetAccount),
    ),
  ],
),
```
  - Add the handler (import `balanceOf` already present via `balance.dart`):

```dart
Future<void> _resetAccount(Balance balance) async {
  final l10n = AppLocalizations.of(context);
  final amount = formatMoney(balance.magnitude, widget.currency);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.resetAccountTitle),
      content: Text(l10n.resetAccountMessage(amount)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.reset)),
      ],
    ),
  );
  if (confirmed != true || !mounted) return;
  final settle = buildSettleEntry(
    contactId: widget.contact.id!,
    balance: balance,
    currency: widget.currency,
    createdAt: DateTime.now(),
    description: l10n.settleEntryDescription,
  );
  if (settle == null) return;
  await widget.repository.add(settle);
  if (mounted) setState(_load);
}
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/presentation/contact_reset_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/contacts/contact_screen.dart test/presentation/contact_reset_test.dart
git commit -m "feat: Reset account from the Contact overflow menu (#25)"
```

---

# Phase 5 — Quick-add (home-first)

## Task 7: Extract shared `EntryFields`

**Files:**
- Create: `lib/presentation/entries/entry_fields.dart`
- Modify: `lib/presentation/entries/add_entry_screen.dart` (consume it)
- Test: existing `test/presentation/add_entry_screen_test.dart` must stay green (behavior-preserving refactor).

**Interfaces:**
- Produces: a stateless `EntryFields` that renders amount + direction + date/time + description, driven by parent-owned state:

```dart
class EntryFields extends StatelessWidget {
  const EntryFields({
    super.key,
    required this.amountController,
    required this.descriptionController,
    required this.direction,
    required this.onDirectionChanged,
    required this.when,
    required this.onPickDateTime,
    this.amountAutofocus = true,
  });
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final Direction direction;
  final ValueChanged<Direction> onDirectionChanged;
  final DateTime when;
  final VoidCallback onPickDateTime;
  final bool amountAutofocus;
  // …build() = the amount TextFormField + SegmentedButton<Direction> +
  //   date OutlinedButton + description TextFormField, lifted verbatim from
  //   AddEntryScreen (same validators, keys, formatters, labels).
}
```

- [ ] **Step 1: Run existing entry tests to capture green baseline.** Run: `flutter test test/presentation/add_entry_screen_test.dart`. Expected: PASS.
- [ ] **Step 2: Create `entry_fields.dart`** by lifting the four field widgets out of `AddEntryScreen.build` verbatim (amount `TextFormField` with its validator + `inputFormatters`, the `SegmentedButton<Direction>` with its style, the date `OutlinedButton.icon`, the description `TextFormField`). The amount validator uses `l10n.amountRequired`/`amountInvalid`; the date label uses `DateFormat.yMMMd(locale).add_jm().format(when)`.
- [ ] **Step 3: Rewrite `AddEntryScreen.build`** to own the state (`_amountController`, `_descriptionController`, `_direction`, `_when`, `_pickDateTime`, `_save` unchanged) and render `EntryFields(...)` inside its `Form`, followed by the existing Save `FilledButton`. No behavior change.
- [ ] **Step 4: Run — expect PASS (unchanged behavior).** Run: `flutter test test/presentation/add_entry_screen_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/entries/entry_fields.dart lib/presentation/entries/add_entry_screen.dart
git commit -m "refactor: extract shared EntryFields from AddEntryScreen (#25)"
```

## Task 8: Add-معاملة screen with inline contact picker

**Files:**
- Create: `lib/presentation/entries/add_transaction_screen.dart`
- Test: `test/presentation/add_transaction_screen_test.dart`

**Interfaces:**
- Consumes: `ContactRepository.list()` (active-only after Phase 6; active-only is exactly what this picker wants — see PRD), `filterContacts` (`domain/contact_sort.dart`), `EntryFields`, `EntryRepository.add`, `AddContactScreen` (for the no-match create path).
- Produces: `AddTransactionScreen({required ContactRepository contactRepository, required EntryRepository entryRepository, required Currency currency})`; pops with the saved `Entry` or null.

Behavior: a search field at top filters contacts as you type; tapping a result selects it (chip/selected state); with a name that matches nothing, a "＋ Add ‘‹name›’ as a new contact" tile pushes `AddContactScreen` and, on return, selects the new contact. Below, `EntryFields`. Save is disabled/invalid until a contact is chosen; on save books an `Entry` in `widget.currency` against the chosen contact and pops it.

- [ ] **Step 1: Write the failing widget test.**

```dart
// test/presentation/add_transaction_screen_test.dart
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/entries/add_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase appDb;
  late ContactRepository contacts;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });
  tearDown(() => appDb.close());

  Widget host() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddTransactionScreen(
          contactRepository: contacts, entryRepository: entries, currency: Currency.sar),
      );

  testWidgets('search, pick a contact, save books an entry in the lens', (tester) async {
    final ali = await contacts.add(const Contact(name: 'Ali'));
    await contacts.add(const Contact(name: 'Sara'));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tx-contact-search')), 'Ali');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-amount')), '150');
    await tester.tap(find.byKey(const Key('tx-save')));
    await tester.pumpAndSettle();

    final booked = await entries.listByContact(ali.id!);
    expect(booked.single.amount, 150);
    expect(booked.single.currency, Currency.sar);
  });

  testWidgets('a no-match name offers to create the contact', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tx-contact-search')), 'Zed');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tx-create-contact')), findsOneWidget);
  });
}
```
Give the amount field in `EntryFields` a `key: const Key('entry-amount')` (add this key in Task 7's amount `TextFormField`).

- [ ] **Step 2: Run — expect FAIL** (screen missing). Run: `flutter test test/presentation/add_transaction_screen_test.dart`
- [ ] **Step 3: Implement `AddTransactionScreen`.** A `StatefulWidget` that:
  - `initState` loads `_all = await contactRepository.list()`, holds `Contact? _selected`, `_query`, and `EntryFields` state (`_amountController`, `_descriptionController`, `_direction = Direction.owedToMe`, `_when = now-to-minute`).
  - Renders a search `TextField` (`key: Key('tx-contact-search')`). When `_selected == null`: show a filtered list `filterContacts(_all, _query)` as tappable `ListTile`s; when the query is non-empty and no contact matches, show a create tile `ListTile(key: Key('tx-create-contact'), leading: Icon(Icons.person_add), title: Text(l10n.quickAddCreateContact(_query)))` that pushes `AddContactScreen(repository: contactRepository)` and on non-null return sets `_selected` + refreshes `_all`. When `_selected != null`: show a compact selected row with a change/clear affordance.
  - Below: `EntryFields(...)` wired to the state; a Save `FilledButton(key: Key('tx-save'))` that validates the form **and** `_selected != null` (otherwise show `l10n.contactRequired` via a `SnackBar` or inline error), then `entryRepository.add(Entry(contactId: _selected!.id!, amount: …, direction: _direction, currency: widget.currency, createdAt: _when, description: …))` and pops the saved entry.
  - Reuse the `_nowToMinute` / `_pickDateTime` helpers (copy from `AddEntryScreen`).

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/presentation/add_transaction_screen_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/entries/add_transaction_screen.dart test/presentation/add_transaction_screen_test.dart lib/presentation/entries/entry_fields.dart
git commit -m "feat: Add معاملة — inline contact picker + shared entry fields (#25)"
```

## Task 9: Add-contact optional first-معاملة section

**Files:**
- Modify: `lib/presentation/contacts/add_contact_screen.dart`
- Test: `test/presentation/add_contact_first_entry_test.dart` (create); keep `test/presentation/add_contact_screen_test.dart` green.

**Interfaces:**
- Produces: `AddContactScreen({required ContactRepository repository, Contact? existing, EntryRepository? entryRepository, Currency? currency})`. When `entryRepository != null && currency != null && existing == null`, render an optional first-معاملة section (`EntryFields`, amount **not** required). On save: create the contact; if an amount was entered, book its first `Entry`. Returns the created `Contact` (unchanged pop contract).

- [ ] **Step 1: Write the failing test.**

```dart
// test/presentation/add_contact_first_entry_test.dart
// host AddContactScreen with entryRepository + currency; enter name + amount;
// tap Save; assert a Contact AND one Entry exist. Then a second case: name only
// (no amount) → Contact exists, zero entries.
```
Concretely:

```dart
testWidgets('name + amount books contact and its first entry', (tester) async {
  await tester.pumpWidget(host()); // AddContactScreen(repository, entryRepository, currency: SAR)
  await tester.enterText(find.byKey(const Key('contact-name')), 'Omar');
  await tester.enterText(find.byKey(const Key('entry-amount')), '200');
  await tester.tap(find.byKey(const Key('contact-save')));
  await tester.pumpAndSettle();
  final all = await contacts.list();
  expect(all.single.name, 'Omar');
  expect((await entries.listByContact(all.single.id!)).single.amount, 200);
});

testWidgets('name only books just the contact', (tester) async {
  await tester.pumpWidget(host());
  await tester.enterText(find.byKey(const Key('contact-name')), 'Nada');
  await tester.tap(find.byKey(const Key('contact-save')));
  await tester.pumpAndSettle();
  final all = await contacts.list();
  expect(all.single.name, 'Nada');
  expect(await entries.listByContact(all.single.id!), isEmpty);
});
```
Add `key: const Key('contact-name')` to the name field and `key: const Key('contact-save')` to the Save button in `AddContactScreen` (they have none today).

- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/presentation/add_contact_first_entry_test.dart`
- [ ] **Step 3: Implement.** Add the two optional constructor params + fields. Convert to owning `EntryFields` state (`_amountController`, `_descriptionController`, `_direction`, `_when`) only when the section is shown. In `build`, after the phone field, conditionally render `_SectionHeader(l10n.firstEntrySection)` + `EntryFields(amountAutofocus: false, …)`. In `_save`, after creating the contact, if `entryRepository != null && amountText.isNotEmpty`, `await entryRepository!.add(Entry(contactId: result.id!, amount: double.parse(amountText), direction: _direction, currency: currency!, createdAt: _when, description: …))`. The amount field must **not** be required here — give `EntryFields` an optional-amount mode, or validate amount only when non-empty (parse-guard). Simplest: in the shared amount validator, when the field is empty return `null` if a `requireAmount == false` flag is set; thread `requireAmount` through `EntryFields` (default true; false here).
- [ ] **Step 4: Run — expect PASS** (new test + existing add-contact test). Run: `flutter test test/presentation/add_contact_first_entry_test.dart test/presentation/add_contact_screen_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/contacts/add_contact_screen.dart lib/presentation/entries/entry_fields.dart test/presentation/add_contact_first_entry_test.dart
git commit -m "feat: Add جهة اتصال with an optional opening معاملة on one screen (#25)"
```

## Task 10: Home speed-dial FAB

**Files:**
- Create: `lib/presentation/home/quick_add_speed_dial.dart`
- Modify: `lib/presentation/home/home_screen.dart` (replace the single FAB; add `_addTransaction`)
- Test: `test/presentation/home_quick_add_test.dart` (create); keep `home_screen_test.dart` green.

**Interfaces:**
- Produces: `QuickAddSpeedDial({required VoidCallback onAddTransaction, required VoidCallback onAddContact})` — a "＋" FAB that toggles open to reveal two labeled mini-actions (keys `quick-add-transaction`, `quick-add-contact`) over a tap-to-dismiss scrim; the main button's icon animates `add`↔`close`.

- [ ] **Step 1: Write the failing test.**

```dart
// test/presentation/home_quick_add_test.dart — host HomeScreen (as home_screen_test does),
// tap the speed-dial FAB, expect both actions, tap Add معاملة → AddTransactionScreen appears.
testWidgets('speed-dial reveals both add actions', (tester) async {
  await tester.pumpWidget(host()); // same wiring as home_screen_test
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home-speed-dial')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('quick-add-transaction')), findsOneWidget);
  expect(find.byKey(const Key('quick-add-contact')), findsOneWidget);
});
```
(Model `host()` on the existing `test/presentation/home_screen_test.dart` setup — copy its `CurrencyController` + repo wiring.)

- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/presentation/home_quick_add_test.dart`
- [ ] **Step 3: Implement `QuickAddSpeedDial`** (an `AnimatedController`-free `StatefulWidget` toggling a `bool _open`; when open, a full-screen `GestureDetector` scrim + a `Column` of two `FloatingActionButton.extended` mini-actions above the main `FloatingActionButton(key: Key('home-speed-dial'))`). Then in `home_screen.dart` replace the `floatingActionButton:` with `QuickAddSpeedDial(onAddTransaction: _addTransaction, onAddContact: _addContact)`, and add:

```dart
Future<void> _addTransaction() async {
  final saved = await Navigator.of(context).push<Entry>(MaterialPageRoute(
    builder: (_) => AddTransactionScreen(
      contactRepository: widget.repository,
      entryRepository: widget.entryRepository,
      currency: _currency,
    ),
  ));
  if (saved != null && mounted) setState(_load);
}
```
Wire `_addContact` to pass the first-entry params too (so "Add جهة اتصال" can book an opening معاملة): update the existing `_addContact` to `AddContactScreen(repository: widget.repository, entryRepository: widget.entryRepository, currency: _currency)`. Import `AddTransactionScreen` and `domain/entry.dart`.

- [ ] **Step 4: Run — expect PASS** (new + `home_screen_test.dart`). Run: `flutter test test/presentation/home_quick_add_test.dart test/presentation/home_screen_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/home/quick_add_speed_dial.dart lib/presentation/home/home_screen.dart test/presentation/home_quick_add_test.dart
git commit -m "feat: home ＋ speed-dial — Add معاملة / Add جهة اتصال (#25)"
```

---

# Phase 6 — Archive (highest risk: schema + query exclusion)

## Task 11: `archived` on the `Contact` domain model

**Files:**
- Modify: `lib/domain/contact.dart`
- Test: `test/domain/contact_test.dart` (add archived round-trip through copyWith/==)

**Interfaces:**
- Produces: `Contact({int? id, required String name, String? phone, bool archived = false})`; `copyWith({… bool? archived})`; `archived` in `==`/`hashCode`/`toString`.

- [ ] **Step 1: Write failing test** asserting the default is `false`, `copyWith(archived: true)` flips it and keeps other fields, and two contacts differing only by `archived` are unequal.
- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/domain/contact_test.dart`
- [ ] **Step 3: Implement.** Add `final bool archived;` (default `false` in the const ctor), thread through `copyWith`, `==`, `hashCode`, `toString`.
- [ ] **Step 4: Run — expect PASS** (and the whole suite compiles — `Contact` is widely constructed but all call-sites use named args, so the defaulted param is source-compatible). Run: `flutter test test/domain/contact_test.dart`
- [ ] **Step 5: Commit.**

```bash
git add lib/domain/contact.dart test/domain/contact_test.dart
git commit -m "feat: Contact carries an archived flag (default false) (#25)"
```

## Task 12: Schema v5 — `archived` column + migration

**Files:**
- Modify: `lib/data/app_database.dart` (bump to 5; add `if (from < 5)` block)
- Test: `test/data/app_database_test.dart` (migration + fresh-install parity)

**Interfaces:**
- Produces: `contacts.archived INTEGER NOT NULL DEFAULT 0`.

- [ ] **Step 1: Write failing tests.**

```dart
// test/data/app_database_test.dart — add:
test('v5 fresh install has the archived column defaulting to 0', () async {
  final appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  addTearDown(appDb.close);
  final db = await appDb.open();
  final id = await db.insert('contacts', {'name': 'X'});
  final row = (await db.query('contacts', where: 'id = ?', whereArgs: [id])).single;
  expect(row['archived'], 0);
  expect(await db.getVersion(), 5);
});

test('upgrading from v4 adds archived defaulting to 0', () async {
  // Open at v4 by inserting a contact through a v4-shaped db, then reopen at 5.
  final path = inMemoryDatabasePath;
  final v4 = await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(
    version: 4,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT)');
    },
  ));
  await v4.insert('contacts', {'name': 'Legacy'});
  await v4.close();
  final appDb = AppDatabase(factory: databaseFactoryFfi, path: path);
  addTearDown(appDb.close);
  final db = await appDb.open();
  final row = (await db.query('contacts', where: "name = ?", whereArgs: ['Legacy'])).single;
  expect(row['archived'], 0);
});
```
NOTE: `inMemoryDatabasePath` is a shared in-memory handle; if the two-open trick proves flaky in-memory, use a temp file path via `sqflite_common_ffi`'s factory (`(await appDb) ` — or write to a `Directory.systemTemp` file and delete in tearDown). Keep whichever is green.

- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/data/app_database_test.dart`
- [ ] **Step 3: Implement.** In `app_database.dart`: `static const int schemaVersion = 5;` and append to `_migrate`:

```dart
if (from < 5) {
  // Archive (ADR 0009): a whole-person set-aside flag. 0 = active, 1 = archived.
  await db.execute(
    'ALTER TABLE contacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
  );
}
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/data/app_database_test.dart`
- [ ] **Step 5: Commit.**

```bash
git add lib/data/app_database.dart test/data/app_database_test.dart
git commit -m "feat: schema v5 adds contacts.archived with migration (#25)"
```

## Task 13: `ContactRepository` — active-only list, archived list, set-archived

**Files:**
- Modify: `lib/data/contact_repository.dart`
- Test: `test/data/contact_repository_test.dart` (add cases)

**Interfaces:**
- Produces: `list()` returns **non-archived** only, newest-first (unchanged order); `listArchived()` returns **archived** only; `setArchived(int id, {required bool archived})`. `_toRow` now writes `archived`; `_fromRow` reads it.

- [ ] **Step 1: Write failing tests.** Add a contact, archive it via `setArchived(id, archived: true)`; assert `list()` excludes it, `listArchived()` returns exactly it, and the round-tripped `Contact.archived` is true; unarchive restores it to `list()`.
- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/data/contact_repository_test.dart`
- [ ] **Step 3: Implement.**

```dart
Future<List<Contact>> list() async {
  final db = await _appDb.open();
  final rows = await db.query(table, where: 'archived = 0', orderBy: 'id DESC');
  return rows.map(_fromRow).toList();
}

Future<List<Contact>> listArchived() async {
  final db = await _appDb.open();
  final rows = await db.query(table, where: 'archived = 1', orderBy: 'id DESC');
  return rows.map(_fromRow).toList();
}

Future<void> setArchived(int id, {required bool archived}) async {
  final db = await _appDb.open();
  await db.update(table, {'archived': archived ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
}
```
Update `_toRow` to include `'archived': c.archived ? 1 : 0` and `_fromRow` to read `archived: (row['archived'] as int? ?? 0) == 1`.

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/data/contact_repository_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/data/contact_repository.dart test/data/contact_repository_test.dart
git commit -m "feat: ContactRepository active/archived lists + setArchived (#25)"
```

## Task 14: Archived-contact exclusion in the aggregate queries

**Files:**
- Modify: `lib/data/entry_repository.dart` (`balancesByCurrency`, `lastActivityByCurrency`, `listByCurrency`, `entriesInRange`)
- Test: `test/data/entry_repository_test.dart` (add exclusion cases)

**Interfaces:** each of the four aggregate queries filters out entries whose contact is archived, via `contact_id IN (SELECT id FROM contacts WHERE archived = 0)`. **`listByContact` is unchanged** — an archived contact's own history stays fully visible.

- [ ] **Step 1: Write failing tests.** Two contacts each with a SAR entry; archive one (`ContactRepository.setArchived`). Assert:
  - `balancesByCurrency(SAR)` omits the archived contact's id.
  - `lastActivityByCurrency(SAR)` omits it.
  - `listByCurrency(SAR)` (analysis series) omits its entries.
  - `entriesInRange(SAR, wideRange)` omits its entries.
  - `listByContact(archivedId)` still returns its entries (control).

```dart
test('archived contacts drop out of every aggregate but keep their own history', () async {
  final contactsRepo = ContactRepository(appDb);
  final a = await contactsRepo.add(const Contact(name: 'Active'));
  final z = await contactsRepo.add(const Contact(name: 'Archived'));
  await entries.add(inCurrency(a.id!, Currency.sar, DateTime(2026, 7, 1)));
  await entries.add(inCurrency(z.id!, Currency.sar, DateTime(2026, 7, 2)));
  await contactsRepo.setArchived(z.id!, archived: true);

  expect((await entries.balancesByCurrency(Currency.sar)).keys, [a.id]);
  expect((await entries.lastActivityByCurrency(Currency.sar)).keys, [a.id]);
  expect((await entries.listByCurrency(Currency.sar)).map((e) => e.contactId), [a.id]);
  final wide = DateRange(DateTime(2026, 1, 1), DateTime(2027, 1, 1));
  expect((await entries.entriesInRange(Currency.sar, wide)).map((e) => e.contactId), [a.id]);
  expect(await entries.listByContact(z.id!), isNotEmpty); // history preserved
});
```

- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/data/entry_repository_test.dart`
- [ ] **Step 3: Implement.** Add the archived sub-filter to each of the four queries. Examples:
  - `balancesByCurrency` raw SQL: `WHERE currency = ? AND contact_id IN (SELECT id FROM ${ContactRepository.table} WHERE archived = 0)`.
  - `lastActivityByCurrency` raw SQL: same added clause.
  - `listByCurrency` (`db.query` form): change `where` to `'currency = ? AND contact_id IN (SELECT id FROM ${ContactRepository.table} WHERE archived = 0)'` (and the `upTo` variant appends `AND created_at < ?`).
  - `entriesInRange` (`db.query` form): append the same `AND contact_id IN (...)` to the `where`.
  Import `ContactRepository` (already imported for `entryCount`? No — add `import 'contact_repository.dart';` if absent) or inline the literal table name `'contacts'`. Prefer the literal `'contacts'` to avoid a new import cycle — matches the existing `EntryRepository.table` string style.

- [ ] **Step 4: Run — expect PASS** (new case + all existing repo tests, which use non-archived contacts and stay green). Run: `flutter test test/data/entry_repository_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/data/entry_repository.dart test/data/entry_repository_test.dart
git commit -m "feat: exclude archived contacts from balances/activity/analysis/flow queries (#25)"
```

## Task 15: Archive action + auto-unarchive on the Contact screen

**Files:**
- Modify: `lib/presentation/contacts/contact_screen.dart` (add `archive` to `_ContactMenuAction`; add optional `ContactRepository? contactRepository`; auto-unarchive after add-entry)
- Test: `test/presentation/contact_archive_test.dart` (create)

**Interfaces:**
- Consumes: `ContactRepository.setArchived`, balance for the soft-gate copy, `l10n.archive/archiveContactTitle/archiveContactMessage/archiveOutstandingOwedToMe/archiveOutstandingOwedByMe`.
- Produces: `ContactScreen(… , ContactRepository? contactRepository, ValueChanged<bool>? onArchivedChanged)`. Archiving pops back to home with a signal so home refreshes; adding an entry to an archived contact auto-unarchives.

- [ ] **Step 1: Write failing tests.**
  - Archiving an **unsettled** contact shows a dialog naming the outstanding amount; confirming calls `setArchived(id, archived: true)` and pops.
  - Archiving a **settled** contact shows a plain confirm.
  - Opening an archived contact and adding an entry calls `setArchived(id, archived: false)` (auto-unarchive).

```dart
testWidgets('archiving an unsettled contact surfaces the outstanding amount', (tester) async {
  final c = await contacts.add(const Contact(name: 'Ali'));
  await entries.add(Entry(contactId: c.id!, amount: 300, direction: Direction.owedToMe, currency: Currency.sar, createdAt: DateTime(2026,7,1)));
  await tester.pumpWidget(host(c)); // ContactScreen with contactRepository wired
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('contact-overflow')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Archive'));
  await tester.pumpAndSettle();
  expect(find.textContaining('owes you'), findsOneWidget); // outstanding named
});
```

- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/presentation/contact_archive_test.dart`
- [ ] **Step 3: Implement.**
  - Add `archive` to `_ContactMenuAction` and a menu item `PopupMenuItem(value: _ContactMenuAction.archive, child: Text(l10n.archive))` (always enabled). Guard the whole overflow button behind `widget.contactRepository != null` so focused entry tests without a contact repo are unaffected.
  - `_archive(Balance balance)`: build the confirm message — settled → `archiveContactMessage(name)`; owed-to-me → `archiveOutstandingOwedToMe(name, amount)`; owed-by-me → `archiveOutstandingOwedByMe(name, amount)`. On confirm: `await widget.contactRepository!.setArchived(widget.contact.id!, archived: true)`, then `Navigator.pop(context)` (return to home) and let home refresh.
  - Auto-unarchive: in `_addEntry`, after a successful save, `await widget.contactRepository?.setArchived(widget.contact.id!, archived: false)`.
  - Thread `contactRepository` from `home_screen.dart` `_openContact` (`contactRepository: widget.repository`) and from the Archived view (Task 16).

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/presentation/contact_archive_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/contacts/contact_screen.dart lib/presentation/home/home_screen.dart test/presentation/contact_archive_test.dart
git commit -m "feat: Archive from the Contact overflow menu; auto-unarchive on new entry (#25)"
```

## Task 16: Archived view + home menu entry

**Files:**
- Create: `lib/presentation/contacts/archived_contacts_screen.dart`
- Modify: `lib/presentation/home/home_screen.dart` (`_HomeMenuAction.archived` entry → open it)
- Test: `test/presentation/archived_contacts_screen_test.dart` (create)

**Interfaces:**
- Produces: `ArchivedContactsScreen({required ContactRepository contactRepository, required EntryRepository entryRepository, required Currency currency, ProfileController? profileController})` — lists `listArchived()`; each row opens `ContactScreen` (which auto-unarchives on add); an inline **Unarchive** action calls `setArchived(id, archived: false)` and removes the row. Empty state uses `l10n.archivedEmpty`.

- [ ] **Step 1: Write failing tests.** Archive a contact via repo; pump `ArchivedContactsScreen`; expect the contact listed; tap Unarchive → row disappears and `list()` (active) contains it again. Empty-state case shows `archivedEmpty`.
- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/presentation/archived_contacts_screen_test.dart`
- [ ] **Step 3: Implement** the screen (a `FutureBuilder` over `listArchived()`, `ListTile`s with a trailing `TextButton`/`IconButton` `key: Key('unarchive-<id>')` calling `setArchived(..., archived: false)` then `setState`), and add to `home_screen.dart`:
  - Extend `enum _HomeMenuAction { analysis, settings, archived }`, add a `PopupMenuItem` (`Icon(Icons.archive_outlined)` + `l10n.archivedTitle`), and in `_onMenuAction` push `ArchivedContactsScreen(contactRepository: widget.repository, entryRepository: widget.entryRepository, currency: _currency, profileController: widget.profileController)`; on return `setState(_load)` (an unarchive/new-entry may have changed the active set).
- [ ] **Step 4: Run — expect PASS** (new + `home_screen_test.dart`). Run: `flutter test test/presentation/archived_contacts_screen_test.dart test/presentation/home_screen_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/contacts/archived_contacts_screen.dart lib/presentation/home/home_screen.dart test/presentation/archived_contacts_screen_test.dart
git commit -m "feat: Archived view from home overflow; unarchive restores to active (#25)"
```

---

# Phase 7 — Erase all data

## Task 17: `AppDatabase.eraseAll()`

**Files:**
- Modify: `lib/data/app_database.dart`
- Test: `test/data/app_database_test.dart` (erase empties every table)

**Interfaces:**
- Produces: `Future<void> eraseAll()` — deletes all rows from `entries`, `contacts`, and `settings` (schema unchanged; a subsequent read returns the empty/first-run state).

- [ ] **Step 1: Write failing test.** Insert a contact, an entry, and a settings row; call `eraseAll()`; assert all three tables are empty and the DB still opens at v5.
- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/data/app_database_test.dart`
- [ ] **Step 3: Implement.**

```dart
/// Wipes every table to a genuine first-run state (Erase all data, ADR 0009).
/// Schema is left intact; only rows are dropped. Irreversible.
Future<void> eraseAll() async {
  final db = await open();
  await db.delete('entries');
  await db.delete('contacts');
  await db.delete('settings');
}
```

- [ ] **Step 4: Run — expect PASS.** Run: `flutter test test/data/app_database_test.dart`
- [ ] **Step 5: Commit.**

```bash
git add lib/data/app_database.dart test/data/app_database_test.dart
git commit -m "feat: AppDatabase.eraseAll wipes all tables to first-run (#25)"
```

## Task 18: Erase-all-data in Settings (type-to-confirm) + app wiring

**Files:**
- Modify: `lib/presentation/settings/settings_screen.dart` (Data section + type-to-confirm dialog)
- Modify: `lib/app.dart`, `lib/main.dart` (pass `AppDatabase`; erase orchestration reloads controllers)
- Modify: `lib/presentation/home/home_screen.dart` (thread `onEraseAllData` to Settings)
- Test: `test/presentation/settings_erase_test.dart` (create); keep `settings_screen_test.dart` green.

**Interfaces:**
- Produces: `SettingsScreen(… , Future<void> Function()? onEraseAllData)`. When supplied, renders a Data section with an **Erase all data** button opening a dialog whose confirm button (`key: Key('erase-confirm')`) stays **disabled** until the user types `l10n.eraseConfirmWord`; on confirm it calls `onEraseAllData()` then pops to home. When null, the section is hidden (focused theme tests unaffected).
- `DebtLedgerApp` gains `final AppDatabase appDatabase;` and orchestrates erase:

```dart
Future<void> _eraseAllData() async {
  await appDatabase.eraseAll();
  await themeController.load();
  await profileController.load();
  await currencyController.load(); // notifies → HomeScreen refetches empty
  await localeController.load();
}
```
passed down `HomeScreen(onEraseAllData: _eraseAllData)` → `SettingsScreen(onEraseAllData: widget.onEraseAllData)`. `main.dart` passes the already-created `appDatabase` into `DebtLedgerApp`.

- [ ] **Step 1: Write the failing widget test** (gating is the testable UI contract; the wipe itself is covered by Task 17).

```dart
// test/presentation/settings_erase_test.dart
testWidgets('erase confirm stays disabled until the confirmation word is typed', (tester) async {
  var erased = 0;
  await tester.pumpWidget(hostWithErase(() async => erased++)); // SettingsScreen(onEraseAllData: …)
  await tester.pumpAndSettle();
  await tester.tap(find.text('Erase all data'));
  await tester.pumpAndSettle();

  final btn = () => tester.widget<TextButton>(find.byKey(const Key('erase-confirm')));
  expect(btn().enabled, isFalse);

  await tester.enterText(find.byKey(const Key('erase-confirm-field')), 'ERASE');
  await tester.pumpAndSettle();
  expect(btn().enabled, isTrue);

  await tester.tap(find.byKey(const Key('erase-confirm')));
  await tester.pumpAndSettle();
  expect(erased, 1);
});
```
`TextButton.enabled` is `onPressed != null`; toggle `onPressed` between `null` and a real callback based on the typed text (use a `StatefulBuilder` inside the dialog).

- [ ] **Step 2: Run — expect FAIL.** Run: `flutter test test/presentation/settings_erase_test.dart`
- [ ] **Step 3: Implement.**
  - `SettingsScreen`: add `final Future<void> Function()? onEraseAllData;`. When non-null, append a Data section (`_SectionHeader(l10n.settingsData)` + a destructive `OutlinedButton.icon`/`ListTile` `Text(l10n.eraseAllData)` with subtitle `l10n.eraseAllDataSubtitle`) that opens `_confirmErase`. Implement `_confirmErase(BuildContext, AppLocalizations, Future<void> Function())` returning an `AlertDialog` built inside a `StatefulBuilder`, holding `var typed = '';` a `TextField(key: Key('erase-confirm-field'), onChanged: (v) => setLocal(() => typed = v))`, and a confirm `TextButton(key: Key('erase-confirm'), onPressed: typed.trim() == l10n.eraseConfirmWord ? () => Navigator.pop(context, true) : null, child: Text(l10n.erase))`. On `true`: `await onEraseAllData!()`, then if the Settings route can pop, `Navigator.of(context).pop()` back to home.
  - `home_screen.dart`: add `final Future<void> Function()? onEraseAllData;` to `HomeScreen`; pass it into the `SettingsScreen(...)` construction in `_onMenuAction`.
  - `app.dart`: add `final AppDatabase appDatabase;` field + `_eraseAllData` (above); pass `onEraseAllData: _eraseAllData` when building `HomeScreen`. Import `data/app_database.dart`.
  - `main.dart`: pass `appDatabase: appDatabase` into `DebtLedgerApp(...)`.

- [ ] **Step 4: Run — expect PASS** (new + `settings_screen_test.dart`). Run: `flutter test test/presentation/settings_erase_test.dart test/presentation/settings_screen_test.dart`
- [ ] **Step 5: Analyze + commit.**

```bash
flutter analyze
git add lib/presentation/settings/settings_screen.dart lib/presentation/home/home_screen.dart lib/app.dart lib/main.dart test/presentation/settings_erase_test.dart
git commit -m "feat: Erase all data — type-to-confirm factory reset, controllers reload to defaults (#25)"
```

---

## Task 19: Full-suite green + manual verification

**Files:** none (verification).

- [ ] **Step 1: Run the whole suite.** Run: `flutter test`. Expected: all pass.
- [ ] **Step 2: Analyze.** Run: `flutter analyze`. Expected: no issues.
- [ ] **Step 3: Drive the app** (`/run` or `flutter run`) and manually confirm each PRD flow: splash ~1s + tap-skip; speed-dial → Add معاملة (inline search + create), Add جهة اتصال (+ opening معاملة); Reset (settled reads, one settle entry, disabled when settled); Archive (leaves list/totals/graph; Archived view; unarchive; auto-unarchive on entry; soft-gate names outstanding); Erase (type-to-confirm, returns to empty first-run); Arabic PDF under a date filter (period on its own labeled line, totals footer with closing balance).
- [ ] **Step 4: Commit any doc touch-ups**, then hand off to finishing-a-development-branch.

---

## Appendix A — New localized strings

Add all of these in **Task 0**. `en` values (with `@`-metadata) go in `app_en.arb`; `ar` values (bare) go in `app_ar.arb`.

| key | en | ar |
|-----|----|----|
| `statementPeriod` | Period | الفترة |
| `resetAccount` | Reset account | تصفير الحساب |
| `reset` | Reset | تصفير |
| `resetAccountTitle` | Reset account? | تصفير الحساب؟ |
| `resetAccountMessage` (placeholder `amount`) | A settling entry of {amount} will be added so the balance reads settled. Your history is kept. | ستُضاف معاملة تسوية بقيمة {amount} ليصبح الرصيد مسدَّدًا. يبقى سجلّك كما هو. |
| `settleEntryDescription` | Settlement | تسوية |
| `archive` | Archive | أرشفة |
| `unarchive` | Unarchive | إلغاء الأرشفة |
| `archivedTitle` | Archived | الأرشيف |
| `archiveContactTitle` | Archive contact? | أرشفة جهة الاتصال؟ |
| `archiveContactMessage` (placeholder `name`) | {name} will be set aside and leave your list, totals and analysis. | سيتم وضع {name} جانبًا وسيغادر قائمتك وإجمالياتك وتحليلك. |
| `archiveOutstandingOwedToMe` (placeholders `name`, `amount`) | {name} still owes you {amount}. Archive anyway? | {name} لا يزال مدينًا لك بـ {amount}. أرشفة على أي حال؟ |
| `archiveOutstandingOwedByMe` (placeholders `name`, `amount`) | You still owe {name} {amount}. Archive anyway? | لا تزال مدينًا لـ {name} بـ {amount}. أرشفة على أي حال؟ |
| `archivedEmpty` | No archived contacts | لا توجد جهات اتصال مؤرشفة |
| `contactArchived` | Contact archived | تمت أرشفة جهة الاتصال |
| `contactUnarchived` | Contact restored | تمت استعادة جهة الاتصال |
| `quickAddSearchHint` | Search or add a contact | ابحث أو أضف جهة اتصال |
| `quickAddCreateContact` (placeholder `name`) | Add “{name}” as a new contact | إضافة «{name}» كجهة اتصال جديدة |
| `contactRequired` | Choose or add a contact | اختر أو أضف جهة اتصال |
| `firstEntrySection` | First entry (optional) | أول معاملة (اختياري) |
| `settingsData` | Data | البيانات |
| `eraseAllData` | Erase all data | مسح جميع البيانات |
| `eraseAllDataSubtitle` | Delete everything and start fresh | حذف كل شيء والبدء من جديد |
| `eraseAllDataTitle` | Erase all data? | مسح جميع البيانات؟ |
| `eraseAllDataMessage` (placeholder `word`) | This permanently deletes all contacts, entries, your profile and settings. Type {word} to confirm — this cannot be undone. | سيؤدي هذا إلى حذف جميع جهات الاتصال والمعاملات وملفك وإعداداتك نهائيًا. اكتب {word} للتأكيد — لا يمكن التراجع. |
| `eraseConfirmWord` | ERASE | مسح |
| `erase` | Erase | مسح |

The speed-dial reuses the existing `addEntry` ("Add entry" / "إضافة معاملة") and `addContact` ("Add contact" / "إضافة جهة اتصال") labels.

---

## Self-Review notes (author)

- **Spec coverage:** Splash (Task 1) ✓; Arabic PDF header (2–3) ✓; PDF footer (4) ✓; Reset (5–6) ✓ incl. per-lens, disabled-when-settled, amount-in-confirm, undo-via-swipe-delete (existing); Archive (11–16) ✓ incl. schema, query exclusion across balances/activity/analysis/flow, soft-gate, Archived view, unarchive, auto-unarchive; Quick-add (7–10) ✓ incl. shared fields, inline search, no-match create, active-only picker, lens inheritance, optional opening entry; Erase (17–18) ✓ incl. type-to-confirm + controller reload to first-run.
- **Out of scope respected:** no Backup export-before-erase; reset stays per-lens; no bulk actions; splash preload untouched; archived contacts open full history (no read-only mode); Statement definition unchanged (render-only).
- **Type consistency:** `setArchived(int id, {required bool archived})`, `listArchived()`, `buildSettleEntry(...) → Entry?`, `statementPeriodLabel(...) → String`, `Contact.archived` used identically across tasks.
- **Risk order:** isolated splash/PDF first; schema/query-invasive Archive placed late; Erase last (touches app root wiring).
