# PRD — Personal Debt Ledger (Android / Flutter)

Status: Ready for build · Date: 2026-07-13 · Terminology: see [CONTEXT.md](../CONTEXT.md) · Decisions: see [ADR 0001](adr/0001-local-only-storage-with-manual-backup.md)

> Note: intended for a project issue tracker with the `ready-for-agent` label. No tracker is configured for this repo yet, so the PRD lives here as a file. Move it when a tracker exists.

## Problem Statement

I lend and borrow money with friends, family, and acquaintances, in two currencies (Saudi Riyal and Yemeni Riyal). I can't reliably remember who owes me, who I owe, how much, or since when. When I want to settle up or remind someone, I have nothing clear to show them, and no way to review my overall position over time. Paper notes get lost; general finance apps are complex, English-only, mix currencies, and aren't built around *people*.

## Solution

A very simple, offline, bilingual (Arabic/English) Android app that is a **people-first debt ledger**. I keep one ledger per **Contact**, log each debt as a directional **Entry** (owed to me / owed by me), and always see a clear per-person, per-currency **Balance** shown in green/red with a plain-language label. I switch the whole app between SAR and YER with a global **currency lens** so the two never mix. I can export a clean per-person **PDF statement**, send a quick **WhatsApp** balance nudge, filter my home view by **time period**, and view an **analysis graph** of my net position over time with drill-down into who caused each change. My data stays on my device (SQLite) with **manual backup/restore** so I can recover after losing my phone.

## User Stories

### Contacts
1. As a user, I want to add a Contact with a name (required) and phone number (optional), so that I can start a ledger for a person even if I don't have their number.
2. As a user, I want to edit a Contact's name and phone, so that I can fix mistakes or add a number later.
3. As a user, I want to delete a Contact, so that I can remove people I no longer deal with.
4. As a user, I want a confirmation warning that tells me how many Entries will be deleted when I delete a Contact, so that I don't wipe a ledger by accident.
5. As a user, I want to search my Contacts by name or phone on the home screen, so that I can find a person quickly when I have many.
6. As a user, I want my Contact list sorted by most recent activity by default, so that people I'm actively dealing with are at the top.
7. As a user, I want to optionally sort Contacts by name or by balance size, so that I can review my ledger in different ways.

### Entries
8. As a user, I want to add an Entry with an amount, so that I can record a debt.
9. As a user, I want to set each Entry's direction (owed to me / owed by me) with a clear green/red toggle defaulting to "owed to me", so that I capture who owes whom with one tap.
10. As a user, I want each Entry to carry a date and time defaulting to now but changeable, so that I can log past dealings accurately.
11. As a user, I want to add an optional description to an Entry, so that I can note what it was for without being forced to.
12. As a user, I want to enter decimal amounts, so that I can record fractional currency values.
13. As a user, I want a new Entry to automatically use the currency I'm currently viewing (the lens), so that I never have to pick a currency in the form.
14. As a user, I want to record a repayment simply as an opposite-direction Entry, so that the balance nets down without any special "settle" step.
15. As a user, I want to edit any field of an existing Entry in place, so that I can correct errors.
16. As a user, I want to delete an Entry with a confirmation and a brief undo option, so that I can remove mistakes safely.

### Balance & currency
17. As a user, I want each Contact to show a per-currency Balance that nets all their Entries, so that I see the single number that matters.
18. As a user, I want the Balance shown as a positive magnitude with color and a plain label ("owes you N" in green / "you owe N" in red, Arabic "لك / عليك"), so that direction is unambiguous even in Arabic.
19. As a user, I want a global currency lens (SAR/YER) at the top of the home screen, so that the whole app shows one currency at a time and never mixes them.
20. As a user, I want a Contact that has both SAR and YER dealings to keep two entirely separate balances, so that the currencies are never summed.
21. As a user, I want switching the lens to refilter the entire app (list, totals, contact pages, graph), so that everything stays consistent to the selected currency.
22. As a user, I want a home header showing per-currency grand totals — total owed to me and total I owe — so that I see my overall position at a glance.

### Period filter
23. As a user, I want to filter my home view by time period (This month / Last month / This year / Custom range / All time), so that I can focus on a timeframe.
24. As a user, I want the home period filter to control which Contacts appear (those active in range), so that I see who I've dealt with lately.
25. As a user, I want each Contact row to keep showing its true all-time outstanding Balance even when a period filter is active, so that I never see a misleading windowed balance.
26. As a user, I want the grand-total header to become a flow figure (lent / received in the selected range) when a period is applied, so that I understand activity in that window.

### Analysis graph
27. As a user, I want a per-currency analysis graph of my cumulative net balance over time, so that I can see whether my overall position is rising or falling.
28. As a user, I want the graph to follow the global currency lens and never mix currencies into one line, so that each currency is read on its own.
29. As a user, I want the graph's time range to follow the same period filter, so that home and analysis stay in sync.
30. As a user, I want to tap a point on the graph and see a contact-level breakdown of the Entries in that interval, so that I know who drove an increase or decrease.

### Statements & sharing
31. As a user, I want to export a PDF statement for one Contact in one currency, so that I have a clean formal record matching what I'm viewing.
32. As a user, I want the statement to show my name, the Contact's name and phone, the currency, a dated table of entries with owed-to-me / owed-by-me columns, and the closing balance, so that it reads like a bank statement.
33. As a user, I want the statement language to follow the app language with correct RTL layout in Arabic, so that it's readable to the recipient.
34. As a user, I want to optionally limit the statement to a date range (default all time), so that I can produce a focused statement.
35. As a user, I want a one-tap WhatsApp share that opens WhatsApp with a pre-filled balance message to the Contact, so that I can send an informal nudge without writing it.
36. As a user, I want to tap a Contact's phone to call them, so that I can reach out directly.

### Profile & settings
37. As a user, I want an editable profile with my name (required) and optional phone, so that my identity appears correctly as the creditor on statements.
38. As a user, I want to set a default currency, so that the app opens on the lens I use most.
39. As a user, I want to choose Arabic or English (default: follow system), so that I use the app in my language.
40. As a user, I want to choose light/dark theme (default: follow system), so that the app matches my preference.

### Onboarding & first run
41. As a user, I want to start using the app immediately with an empty ledger, so that I'm not gated behind a setup form.
42. As a user, I want to be prompted for my name only the first time I export a PDF, so that setup happens exactly when it's needed.

### Data safety
43. As a user, I want to export a full backup file I can save off-device (Drive, email), so that I can recover my ledger after losing my phone.
44. As a user, I want to restore from a backup file, so that I can bring my data back on a new device.
45. As a user, I want the app to keep a rolling on-device auto-backup, so that I have a recovery point even if I never tap Backup.

### Security
46. As a user, I want an optional biometric/PIN app lock (off by default) using my device's own authentication, so that someone holding my phone can't read my ledger.

## Implementation Decisions

- **Platform:** Flutter, Android only. Local-first, no server, no network calls except the WhatsApp/tel deep links opened via the OS.
- **Persistence:** SQLite. Two core tables — Contacts and Entries. Entry stores amount, currency (SAR/YER), direction (to-me / by-me), timestamp, optional description, and a foreign key to Contact with cascade delete. No separate "payment/settlement" table — repayment is an opposite-direction Entry (see CONTEXT.md).
- **Balance:** always computed, never stored — sum of signed Entry amounts per Contact per currency. Sign convention: positive = owed to me. UI shows magnitude + color + label; sign is internal only.
- **Currency lens:** a single app-level state (default from settings) that filters every query and view. Entries inherit the lens on creation. No per-Entry currency picker.
- **Period filter:** app-level state shared by home and analysis. On home it is a *visibility* filter (which Contacts appear) plus a flow-total header; it never recomputes Balances over a window. Windowed aggregation exists only for the analysis graph.
- **Analysis:** cumulative net-balance series computed per currency from time-ordered Entries; drill-down queries Entries within a tapped interval grouped by Contact.
- **Statement:** a pure builder turns (profile, contact, entries, currency, range, locale) into a statement document model; a renderer produces the PDF via the `pdf`/`printing` packages. RTL flag derived from locale.
- **Backup/restore:** manual export of the whole DB to a shareable file via the share sheet; restore replaces the local DB (full replace, not merge). Rolling on-device auto-backup keeps the last N. File format (SQLite vs JSON) and encryption deferred — see ADR 0001.
- **App lock:** `local_auth` against device biometric/PIN; setting off by default; no custom secret stored.
- **Localization:** Flutter `intl`/ARB with `ar` and `en`; full RTL support. Arabic-Indic vs Western numeral rendering deferred (minor, changeable later).
- **Likely packages:** `sqflite` (or `drift`), `pdf` + `printing`, `fl_chart`, `local_auth`, `share_plus`, `url_launcher`, `intl`. Final choice at scaffold time.
- **Architecture intent:** keep money math and query logic in pure Dart layers (domain + repository) separated from widgets, so the highest-value logic is testable without the UI.

## Testing Decisions

Good tests here assert **external behavior**, not implementation details: given Entries in, assert the Balance/series/statement-model out. Money correctness is the priority.

- **Domain logic seam (pure Dart) — primary.** Unit-test balance netting (mixed directions), per-currency separation (SAR and YER never combine), period-flow aggregation (lent/received in range), and cumulative-series generation (monotonic time ordering, correct up/down movement). Pure functions over in-memory fixtures; no DB, no widgets.
- **Repository seam (SQLite).** Test `ContactRepository` / `EntryRepository` against a temporary/in-memory database: CRUD, cascade delete on Contact removal, "contacts active in range" query, and "entries within interval grouped by contact" query.
- **Statement-builder seam (pure Dart).** Assert the statement document *model* is structurally correct (rows in date order, owed-to-me / owed-by-me columns, closing balance, RTL flag from locale) without rendering pixels.
- **Widget/golden layer — thin.** A few smoke tests: lens switch refilters the list, delete shows a confirmation, home header shows the right totals. Golden tests only where visual regression matters (statement layout, RTL).
- **Prior art:** none yet (greenfield). These seams establish the pattern; later features should reuse them rather than testing through the UI.

## Out of Scope

- iOS / web / desktop builds (Android only for now).
- Cloud sync, accounts, login, multi-device (ADR 0001 — local-only with manual backup).
- Mixing currencies or currency conversion between SAR and YER.
- Debt-to-payment linking / partial-settlement matching (repayment is a plain opposite-direction Entry).
- Audit trail / edit history (edits are in place).
- Scheduled or automated reminders/notifications (WhatsApp share is manual, one tap).
- Categories, tags, budgets, or expense-by-category analytics.
- Multiple app users / staff accounts / shared ledgers.
- Additional currencies beyond SAR and YER.
- Secondary flow-bars chart view (deferred; cumulative line only for v1).

## Further Notes

- Terminology is authoritative in [CONTEXT.md](../CONTEXT.md); use Contact / Entry / Direction / Balance / currency lens / period filter consistently in code and UI copy.
- Two small decisions intentionally deferred to build time: backup file format + encryption (noted in ADR 0001), and Arabic-Indic vs Western numeral display.
- Design priority throughout is simplicity: when a feature can be added with real complexity or omitted, prefer omission unless a user story above requires it.
