# Context — Personal Debt Ledger

A personal debt/IOU ledger for Android (Flutter). You track money owed **to you** and **by you**, organized per person, in Saudi Riyal (SAR) and Yemeni Riyal (YER), and export per-person PDF statements. Bilingual (Arabic / English), local-only (SQLite), light/dark themes.

This is **not** a category-based expense tracker. It is people-first: the primary object is a person, and every line is a debt in one direction.

## Glossary

### Contact
A person you have dealings with — has a name and phone number. In the UI, one Contact **is** one ledger (Contact and Account are the same thing to the user). Also referred to loosely as a "record" in early conversation; the canonical term is **Contact**.

- Arabic: جهة الاتصال / الطرف

### Entry
A single line item: an amount owed in one direction, on a date/time, with a description. Replaces the earlier fuzzy word "expense" — entries are **debts**, not expenses (nobody is spending; money is owed or repaid).

- Arabic: حركة / معاملة

### Direction
Whether an Entry is owed **to me** or **by me**. Set per Entry (not per Contact) — the same Contact can have entries in both directions.

- Owed to me — the Contact owes me. (Arabic: لي / لِيَّ)
- Owed by me — I owe the Contact. (Arabic: عليَّ)

### Currency
SAR or YER. Chosen per Entry. A single Contact may hold entries in both currencies, but each currency has its **own independent balance** — the two are never summed together. In the UI, currency is a **global lens**: a switch at the top of the home screen selects SAR or YER, and the entire app (people list, per-currency grand totals, each Contact's entries and balance) reflects only the selected currency. Switching the global lens refilters everything. The Contact page inherits this global selection rather than having its own tab.

The home header shows two per-currency totals for the selected currency: **Total owed to you** and **Total you owe**.

- SAR — Saudi Riyal (ر.س)
- YER — Yemeni Riyal (ر.ي)

### Statement
A per-Contact, per-currency PDF export of a Contact's entries (date | description | owed-to-me | owed-by-me columns) with the closing balance. Language follows the app; Arabic renders RTL. Optional date-range filter (default: all time). Distinct from the quick **WhatsApp share** — a tap-to-WhatsApp deep link with a pre-filled balance message for informal nudges.

### Profile
The single local app owner (you). Name (required — appears as creditor on statements) + optional phone. No account, login, or email.

### Backup
Manual export/import of the whole database to a shareable file, plus a rolling on-device auto-backup. Local-only; no cloud sync. See [ADR 0001](docs/adr/0001-local-only-storage-with-manual-backup.md).

### App lock
Optional biometric/device-PIN lock (off by default) via the OS. No custom PIN is stored.

### Period filter
A time-range selector (This month / Last month / This year / Custom / All time) shared by the home screen and the analysis graph.

On the **home screen** it is a **visibility filter**, never a balance filter: it controls which Contacts appear (those with activity in range) and turns the grand-total header into a **flow** figure for the range (total lent / total received), while each Contact row still shows its **true, all-time outstanding Balance**. A Balance is cumulative and all-time by definition — it is never recomputed over a window (a windowed balance would falsely read 0 for an old, unpaid debt). Windowed math lives only in the analysis graph.

### Analysis graph
A per-currency (following the global currency lens) chart of the **cumulative net balance over time** — the running total position across all Contacts. Rising = net owed-to-me increasing; falling = repayments or new owed-by-me. X-axis range follows the [[period filter]]. Never mixes currencies into one line. **Drill-down:** tapping a point shows a **contact-level breakdown** of the entries in that interval (who drove the increase/decrease). Optional secondary flow-bars view is deferred.

### Balance
The running total for one Contact in one currency — the sum of all signed Entry amounts (repayment is just an opposite-direction Entry; there is no separate settle concept).

**Sign convention:** positive = **owed to me** (they owe me); negative = **owed by me** (I owe them).

**Display:** the number is always shown as a positive magnitude; direction is carried by **color + label**, not the sign:
- Owed to me → green, "لك N ر.س" (EN: "owes you N")
- Owed by me → red, "عليك N ر.س" (EN: "you owe N")

The raw signed value still exists underneath for sorting and PDF.
