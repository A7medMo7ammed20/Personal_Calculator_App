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

The lens has a persisted **default currency** (set in Settings, #12) that seeds which currency is *active* when the app opens. The **active** lens and the **default** are distinct: tapping the bottom tabs moves the active lens for the current session only and never rewrites the default, whereas changing the default in Settings both live-switches the active lens *and* persists it as the launch default. So the two can diverge within a session and re-converge on the next launch. The default rides the [[Backup]] like the other settings (ADR 0002).

The home header shows two per-currency totals for the selected currency: **Total owed to you** and **Total you owe**.

- SAR — Saudi Riyal (ر.س)
- YER — Yemeni Riyal (ر.ي)

### Statement
A per-Contact, per-currency PDF export of a Contact's entries: a dated table (date | description | owed-to-me | owed-by-me | running [[Balance]]) with an **opening balance**, the two gross directional **totals** (owed-to-me / owed-by-me), and the net **closing [[Balance]]**. Built by the same pure [[Running summary]] series as the on-screen preview and the [[Analysis graph]] (#8), so the three never disagree about what a [[Balance]] is. The creditor name on the header comes from the [[Profile]]; the Contact's name and phone identify the counterparty.

Under an optional date-range filter (default: all time) the rows are **clipped in view** but the balance is **never recomputed over the window**: the statement **carries in the opening balance** from before the range, the running [[Balance]] and closing [[Balance]] stay the true all-time position, and only the two gross totals cover the in-range activity (opening + period activity = closing). This mirrors [ADR 0004](docs/adr/0004-analysis-graph-rendering-and-windowing.md) and upholds the [[Balance]] invariant — a windowed balance would falsely read 0 for an old, unpaid debt.

Language follows the app; Arabic renders RTL. Distinct from the quick [[WhatsApp share]] — a tap-to-WhatsApp deep link with a pre-filled balance message for informal nudges.

### Running summary
An on-screen, per-Contact, per-currency preview of the [[Statement]] up to a
chosen Entry's date: the dated entries oldest→newest (tapped entry anchored at
the bottom) with the two **gross** directional running totals (owed-to-me and
owed-by-me) and the net closing [[Balance]]. Built by a pure series function
reused by the [[Analysis graph]] (#8) and the PDF [[Statement]] (#10).

- Arabic: الملخّص الجاري

### WhatsApp share
A one-tap informal nudge from a [[Contact]] (#11): opens WhatsApp via a `wa.me`
deep link to the Contact's phone, with a pre-filled **balance message** the user
can freely edit in WhatsApp before sending. The message is written **from the
owner to the Contact**, so its perspective is the *mirror* of the on-screen
[[Balance]] labels — here "you" is the Contact, not the owner:

- Contact owes the owner (owed-to-me) → "you owe me {amount}"
- Owner owes the Contact (owed-by-me) → "I owe you {amount}"
- [[Balance]] settled → a friendly settled note, no amount

The amount is in the **active [[Currency]] lens** — per-lens like everything
else, so a net-zero lens reads as settled even when the other currency is
unsettled. Distinct from the formal PDF [[Statement]]: the share is informal,
editable, and free-text-friendly, not a dated table.

- Arabic: مشاركة واتساب

### Tap-to-call
Tapping a [[Contact]]'s displayed phone number opens the device dialer via a
`tel:` link (populated, not auto-dialed). Sits beside the [[WhatsApp share]] in a
small action strip on the Contact screen; the whole strip is **hidden** when the
Contact has no phone. Both actions hand off to another app through the OS — Daftar
itself makes no network call, so they stay within the local-only stance of
[ADR 0001](docs/adr/0001-local-only-storage-with-manual-backup.md).

- Arabic: اتصال بلمسة

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
A per-currency (following the global currency lens) analysis of the net [[Balance]] across all Contacts, with a **chart-type toggle** between two views. Never mixes currencies into one chart.

**Over time** — a line of the **cumulative net balance over time**. Rising = net owed-to-me increasing; falling = repayments or new owed-by-me. It is a **view onto the real all-time running [[Balance]], windowed only in X**: under a bounded [[Period filter]] the line **carries in the opening balance** from before the window (July starts at June's closing position, not at zero) — the balance is never *recomputed* over the window, only *clipped* in view. At **All time** the X axis spans first-entry-date → today. It plots **one vertex per Entry** (evenly spaced by index, so same-day entries never collapse to a single dot — the failure that a calendar-bucket line hit on this app's dense same-day data). **Drill-down:** tapping a vertex opens that Entry's contact, signed amount, date, and note — who moved the line here, and which way.

**By contact** — a **diverging horizontal bar** per Contact of their **all-time net balance** (green toward owed-to-me, red toward owed-by-me, sorted by magnitude). Being a snapshot it is immune to same-day clustering. Because a [[Balance]] is all-time and **never windowed**, the period chip is hidden on this view. (Pie/donut was rejected — a slice can't carry debt *direction*.)

A currency with no entries (or, on the bars, no unsettled contacts) shows a calm per-lens empty state. The graph is a **global (all-Contacts) destination** reached from the home overflow (⋮), not a per-Contact view (see [ADR 0004](docs/adr/0004-analysis-graph-rendering-and-windowing.md), amended 2026-07-14; this revises [ADR 0003](docs/adr/0003-bottom-tab-currency-lens.md)).

### Balance
The running total for one Contact in one currency — the sum of all signed Entry amounts (repayment is just an opposite-direction Entry; there is no separate settle concept).

**Sign convention:** positive = **owed to me** (they owe me); negative = **owed by me** (I owe them).

**Display:** the number is always shown as a positive magnitude; direction is carried by **color + label**, not the sign:
- Owed to me → green, "لك N ر.س" (EN: "owes you N")
- Owed by me → red, "عليك N ر.س" (EN: "you owe N")

The raw signed value still exists underneath for sorting and PDF.

### Reset account
Zeroing one [[Contact]]'s [[Balance]] in the **active [[Currency]] lens** by appending a single balancing [[Entry]] — opposite direction, magnitude equal to the current balance. Consistent with the [[Balance]] rule that a settle *is* just an Entry (never a special record): the whole history is preserved and the settle line appears in the entry list, the PDF [[Statement]], and the [[Analysis graph]] like any other Entry. Scoped to the **active lens** — the other currency's balance is untouched — and disabled when that lens is already settled (nothing to zero). Undone by removing the settle Entry (it is a normal Entry). Distinct from [[Delete contact]] (removes the person) and [[Archive]] (hides them); a reset keeps the Contact and its past.

- Arabic: تصفير الحساب (the settle Entry's description reads تسوية)

### Archive
A whole-person "set aside" state for a [[Contact]] — spans **both** currencies, unlike the per-lens [[Reset account]]. An archived Contact leaves the home list, the grand-total header, and the [[Analysis graph]] entirely, living instead under a separate **Archived** view reached from the home overflow (⋮). **Soft-gated:** allowed even with an unsettled [[Balance]], but the confirm dialog names any outstanding balance first ("Ali still owes you 300 ر.س. Archive anyway?"), so a live debt never leaves the totals silently. Reversible — unarchive from the Archived view, and adding a new [[Entry]] to an archived Contact **auto-unarchives** them (dealing with them again makes them active).

- Arabic: أرشفة / الأرشيف

### Delete contact
Permanently removes a [[Contact]] and cascade-deletes all their [[Entry]] rows in both currencies (undoable only via the immediate Snackbar). The hard end of the contact lifecycle: [[Reset account]] keeps the person and their history, [[Archive]] hides the person but keeps the data, delete destroys both.

- Arabic: حذف
