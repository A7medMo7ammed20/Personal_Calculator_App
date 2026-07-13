# Context — Daftar (دفتر)

**Daftar** (Arabic: دفتر, "ledger/notebook") is the product name — a single wordmark
that serves both scripts. "Personal Debt Ledger" remains the plain descriptor.

A personal debt/IOU ledger for Android (Flutter). You track money owed **to you** and **by you**, organized per person, in Saudi Riyal (SAR) and Yemeni Riyal (YER), and export per-person PDF statements. Bilingual (Arabic / English), local-only (SQLite), light/dark themes.

This is **not** a category-based expense tracker. It is people-first: the primary object is a person, and every line is a debt in one direction.

## Glossary

### Contact
A person you have dealings with — has a name and phone number. In the UI, one Contact **is** one ledger (Contact and Account are the same thing to the user). Also referred to loosely as a "record" in early conversation; the canonical term is **Contact**.

- Arabic: جهة الاتصال / الطرف

### Entry
A single line item: an amount owed in one direction, on a date/time, with a description. Replaces the earlier fuzzy word "expense" — entries are **debts**, not expenses (nobody is spending; money is owed or repaid).

- Arabic: **معاملة** (transaction). Covers both directions (a debt *or* a repayment). The older label حركة is retired for Entry — it was overloaded with [[Flow]] (الحركة) and read as meaningless to users; حركة/الحركة now means Flow only.

### Direction
Whether an Entry is owed **to me** or **by me**. Set per Entry (not per Contact) — the same Contact can have entries in both directions.

- Owed to me — the Contact owes me. (Arabic: لي / لِيَّ)
- Owed by me — I owe the Contact. (Arabic: عليَّ)

### Currency
SAR or YER. Chosen per Entry. A single Contact may hold entries in both currencies, but each currency has its **own independent balance** — the two are never summed together. In the UI, currency is a **global lens**: **bottom tabs** (SAR / YER) — a floating pill bar with an animated indicator that slides to the active currency — select the currency, and the entire app (people list, per-currency grand totals, each Contact's entries and balance) reflects only the selected currency. The lens switches by **tapping** a tab (not by swiping the body; horizontal swipe is reserved for row actions — see [ADR 0005](docs/adr/0005-row-swipe-actions-and-tap-only-currency-lens.md)). Switching the global lens refilters everything. The Contact page inherits this global selection rather than having its own tab.

The home header shows two per-currency totals for the selected currency: **Total owed to you** and **Total you owe**.

- SAR — Saudi Riyal (ر.س)
- YER — Yemeni Riyal (ر.ي)

### Statement
A per-Contact, per-currency PDF export of a Contact's entries (date | description | owed-to-me | owed-by-me columns) with the closing balance. Language follows the app; Arabic renders RTL. Optional date-range filter (default: all time). Distinct from the quick **WhatsApp share** — a tap-to-WhatsApp deep link with a pre-filled balance message for informal nudges.

### Running summary
An on-screen, per-Contact, per-currency preview of the [[Statement]] up to a
chosen Entry's date: the dated entries oldest→newest (tapped entry anchored at
the bottom) with the two **gross** directional running totals (owed-to-me and
owed-by-me) and the net closing [[Balance]]. Built by a pure series function
reused by the [[Analysis graph]] (#8) and the PDF [[Statement]] (#10).

- Arabic: الملخّص الجاري

### Profile
The single local app owner (you). Name (required — appears as creditor on statements) + optional phone. No account, login, or email.

### Backup
Manual export/import of the whole database to a shareable file, plus a rolling on-device auto-backup. Local-only; no cloud sync. See [ADR 0001](docs/adr/0001-local-only-storage-with-manual-backup.md).

### App lock
Optional biometric/device-PIN lock (off by default) via the OS. No custom PIN is stored.

### Period filter
A time-range selector (This month / Last month / This year / Custom / All time) shared by the home screen and the analysis graph.

On the **home screen** it is a **visibility filter**, never a balance filter: it controls which Contacts appear (those with activity in range) and turns the grand-total header into a [[Flow]] figure for the range (total lent / total received), while each Contact row still shows its **true, all-time outstanding Balance**. A Balance is cumulative and all-time by definition — it is never recomputed over a window (a windowed balance would falsely read 0 for an old, unpaid debt). Windowed math lives only in the analysis graph.

At **All time** (the default) the header is *not* flow — it shows the all-time net-position totals ([[Balance]]-based "owed to you" / "you owe"). The header switches to [[Flow]] only when a **bounded** period (This/Last month, This year, Custom) is active. Periods are calendar ranges in local time; the filter composes as period → search → sort, and the flow header follows the period alone (search never changes it).

### Flow
The **gross directional movement** of money over a window, in one currency: **Lent** = the sum of every **owed-to-me** [[Entry]] amount in range; **Received** = the sum of every **owed-by-me** amount in range. Gross, not netted — a Contact who took +1000 and repaid −300 in the window contributes 1000 to Lent *and* 300 to Received. Distinct from [[Balance]] (a net, all-time position): flow is per-entry and windowed. Shown as the home header under a bounded [[Period filter]] and as the basis of the [[Analysis graph]] (#8).

- Arabic: الحركة (المدفوع / المقبوض)

### Activity
A Contact's **most recent [[Entry]] date within the current currency lens** — the
newest `created_at` among their entries in the selected [[Currency]]. Drives the
home screen's default sort (most-recent-activity first). A Contact with no entry
in the selected currency has **no activity** in that lens and sorts last (then by
name). Lens-scoped, like everything else on home: the same Contact can be "active"
under YER and inactive under SAR. The [[Period filter]]'s "activity in range" is
this concept restricted to a time window.

- Arabic: النشاط

### Analysis graph
A per-currency (following the global currency lens) chart of the **cumulative net balance over time** — the running total position across all Contacts. Rising = net owed-to-me increasing; falling = repayments or new owed-by-me. Never mixes currencies into one line.

It is a **view onto the real all-time running [[Balance]], windowed only in X**: under a bounded [[Period filter]] the line **carries in the opening balance** from before the window (July starts at June's closing position, not at zero) — the balance is never *recomputed* over the window, only *clipped* in view. At **All time** the X axis spans first-entry-date → today. A currency with no entries shows a calm per-lens empty state.

Points are **adaptive calendar buckets** whose granularity follows the visible span (daily for month-scale, weekly for quarter/year-scale, monthly for multi-year); empty buckets **carry the balance forward** (a flat segment, never a drop to zero). **Drill-down:** tapping a point lists that interval's entries as a **per-Contact net delta** (green/red, sorted by magnitude), and the deltas sum to the segment's rise/fall — answering *who moved the line, and which way*.

The graph is a **global (all-Contacts) destination** reached from the home overflow (⋮), not a per-Contact view (see [ADR 0004](docs/adr/0004-analysis-graph-rendering-and-windowing.md); this revises [ADR 0003](docs/adr/0003-bottom-tab-currency-lens.md)). Optional secondary flow-bars view is deferred.

### Balance
The running total for one Contact in one currency — the sum of all signed Entry amounts (repayment is just an opposite-direction Entry; there is no separate settle concept).

**Sign convention:** positive = **owed to me** (they owe me); negative = **owed by me** (I owe them).

**Display:** the number is always shown as a positive magnitude; direction is carried by **color + label**, not the sign:
- Owed to me → green, "لك N ر.س" (EN: "owes you N")
- Owed by me → red, "عليك N ر.س" (EN: "you owe N")

The raw signed value still exists underneath for sorting and PDF.
