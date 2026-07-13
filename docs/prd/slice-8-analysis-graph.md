# PRD — Slice #8: Analysis graph (cumulative net balance)

> Synthesized from the grilling session on 2026-07-13. Design decisions are recorded in
> [ADR 0004](../docs/adr/0004-analysis-graph-rendering-and-windowing.md) and the
> `[[Analysis graph]]` entry in `CONTEXT.md`. This PRD is the implementation spec.

## Problem Statement

As a Daftar user I can see each Contact's current [[Balance]] and, since #7, windowed
[[Flow]] on home — but I have no way to see **how my overall position has moved over time**.
I can't tell whether I'm drifting further into being owed money or clawing it back, when
the turning points happened, or **who** drove a given rise or fall. The ledger shows the
present; it doesn't show the trajectory.

## Solution

A per-currency **Analysis graph** — a single line of my **cumulative net balance across all
Contacts over time**, in the currency of the active lens. Rising means net owed-to-me is
increasing; falling means repayments or new owed-by-me. I reach it from the home overflow
menu (⋮). The line is a view onto my *real* running balance: under a bounded period it
carries in the position I already held before the window, so it never lies about where I
stand. Tapping any point drills into that interval and lists **who moved the line and which
way**, as a per-Contact net delta. The two currencies are never mixed into one line.

## User Stories

1. As a Daftar user, I want to open an analysis graph from the home overflow (⋮) menu, so that I can review my position without cluttering the home screen.
2. As a Daftar user, I want the graph to show my cumulative net balance across all Contacts over time, so that I can see my overall trajectory, not just per-Contact snapshots.
3. As a Daftar user, I want a rising line to mean my net owed-to-me is increasing and a falling line to mean repayments or new owed-by-me, so that the shape reads intuitively.
4. As a Daftar user, I want the graph to show only the active lens currency (SAR or YER), so that two independent currencies are never summed into one misleading line.
5. As a Daftar user, I want to switch the currency lens from the graph screen via a top segmented toggle and see the line redraw, so that I can compare my SAR and YER positions without leaving the screen.
6. As a Daftar user, I want changing the lens or period on the graph to carry back to home, so that the app keeps one consistent view of which currency and period I'm looking at.
7. As a Daftar user, I want the graph's time range to follow the same period filter as home (This month / Last month / This year / Custom / All time), so that the analysis matches the window I'm already thinking in.
8. As a Daftar user, I want to change the period from the graph screen using the same selector as home, so that I can reframe the analysis in place.
9. As a Daftar user, I want the line under a bounded period to start from the balance I already held before the window (carry-in), so that the graph shows my true position over time rather than a false zero origin.
10. As a Daftar user, I want the All-time view to span from my first entry to today, so that I see my whole history in that currency.
11. As a Daftar user, I want the horizontal axis to be split into sensible time buckets that adapt to the span (days for a month, weeks for a year, months for many years), so that the line is readable at any zoom.
12. As a Daftar user, I want a bucket with no activity to hold the line flat at the prior balance, so that quiet periods don't look like the balance dropped to zero.
13. As a Daftar user, I want to tap a point on the line and see a breakdown of that interval's entries grouped by Contact, so that I understand what caused the movement.
14. As a Daftar user, I want each Contact in the breakdown shown as a net delta, colored green (owed-to-me) or red (owed-by-me) and sorted by magnitude, so that the biggest movers are obvious.
15. As a Daftar user, I want the per-Contact deltas in a breakdown to add up to that segment's rise or fall, so that the drill-down is trustworthy.
16. As a Daftar user, I want a calm empty state when the active currency has no entries yet, so that an empty graph isn't confusing.
17. As a Daftar user, I want the graph to still render when I have only one entry or a single day of activity, so that early use isn't a broken screen.
18. As an Arabic user, I want the graph, its labels, its toggle, and the breakdown sheet to render right-to-left with Arabic labels and a locale-appropriate week start, so that it feels native.
19. As a Daftar user in a dark theme, I want the graph to use the app's existing colors and accent, so that it matches the rest of the app.

## Implementation Decisions

**Placement & navigation**
- The Analysis graph is a **global, all-Contacts destination** reached from the home app-bar overflow (⋮) menu, alongside Settings and Backup. It is *not* a per-Contact view. This **revises ADR 0003** (which had anticipated it inside the Contact screen) and is recorded in **ADR 0004**.
- The screen reads the current lens + period, hosts its own compact controls — a **top SAR/YER segmented toggle** (the bottom tab bar stays home's identity) and the **shared period chip/selector** reused from home — and on pop **returns** the possibly-changed lens/period. Home adopts them via its existing `setState(_load)` reload. Lens/period remain `HomeScreen` locals; **no lifted global controller** in this slice.

**Rendering**
- The chart is a **bespoke `CustomPainter`**: one windowed line, a few axis labels, tap hit-testing against bucket points, themed with existing design tokens (semantic green/red, brand accent, spacing/radius). **No charting dependency is added** — the app keeps its zero-third-party-UI-dependency posture.

**Windowing semantics (the golden rule)**
- The line is a **view onto the real all-time running [[Balance]], windowed only in X**. Under a bounded [[Period filter]] the left edge is the **true opening balance carried in** from before the window. The balance is **clipped in view, never recomputed** over the window (honoring CONTEXT's rule that a Balance is cumulative and all-time). At All time, X spans **first-entry-date → today**.

**Points & bucketing**
- Points are **adaptive calendar buckets**, granularity chosen from the visible span: **≤ 62 days → daily**, **63–400 days → weekly**, **> 400 days → monthly**. Boundaries are **calendar-aligned in local time**; **week start is locale-aware** via `intl`. Each point's Y is the cumulative balance **at the bucket's end**. **Empty buckets carry the balance forward** (flat segment, never a drop to zero).

**Drill-down**
- Tapping a point opens a **bottom sheet styled like the existing running-summary sheet**, listing the bucket's entries as a **per-Contact net delta** (green/red, sorted by magnitude), with the interval's total net movement as the header. Deltas sum to the segment's rise/fall.

**Modules built / modified**
- **New domain (pure):** `cumulativeSeries(entries, {range, now})` → `List<BalancePoint>` — the single high seam owning granularity selection, bucketing, opening-balance carry-in, and empty-bucket carry-forward, built on top of `runningSummary`. `intervalBreakdown(entries)` → `List<ContactDelta>` — groups a bucket's entries by `contactId` into sorted net deltas.
- **New repository read:** `EntryRepository.listByCurrency(currency, {upTo})` — all entries in one currency, ascending by `created_at`, optionally up to an exclusive instant (to supply carry-in). Thin SQL, kept dumb.
- **Reused unchanged:** `runningSummary`, `entriesInRange(currency, range)`, `resolvePeriod`, the home period-selector widget, the running-summary sheet styling, semantic color / theme tokens.
- **New presentation:** `AnalysisGraphScreen`, the line `CustomPainter`, the drill-down sheet, the ⋮ menu entry on home, and EN/AR `.arb` strings.

**No schema change.** The existing `entries` table (currency, direction, amount, created_at, contact_id) is sufficient.

## Testing Decisions

Good tests here assert **external behavior of the pure seams**, not painter internals or widget tree shape. The design deliberately pushes all logic into two pure functions so the `CustomPainter` stays a dumb renderer that needs no automated coverage.

- **`cumulativeSeries`** (mirrors the existing `runningSummary` / `flowTotalsOf` / `balanceOf` pure-function tests):
  - Time ordering — points emitted oldest → newest; ties broken deterministically as `runningSummary` already does.
  - Correct up/down movement — an owed-to-me entry raises the line, owed-by-me lowers it.
  - Opening-balance carry-in — a bounded range starts at the pre-window closing balance, not zero.
  - Empty-bucket carry-forward — a bucket with no entries repeats the prior balance (flat), never drops to zero.
  - Granularity thresholds — spans at the 62-day and 400-day boundaries select daily / weekly / monthly as specified.
  - All-time bounds — first-entry-date → `now`.
  - Degenerate — zero entries → empty series; single entry → a valid short series.
- **`intervalBreakdown`**:
  - Grouping — entries collapse to one row per Contact.
  - Net sign & sort — each row's delta is the signed net; rows sorted by magnitude.
  - Sum property — the deltas sum to the interval's net movement (ties the breakdown to the line).
- **Prior art:** `test/` already contains pure-domain unit tests for balances, flow, running summary, and period resolution; these follow the same style (construct `Entry` fixtures, call the function, assert on the result — no DB, no widgets).

`listByCurrency` is a thin SQL passthrough exercised indirectly; the `AnalysisGraphScreen` and painter are verified by running the app (manual), consistent with how existing screens are handled.

## Out of Scope

- The optional **secondary flow-bars view** (gross lent/received bars) — explicitly deferred in CONTEXT.
- Any **lifted global lens/period controller** — this slice keeps lens/period as `HomeScreen` locals and syncs via return-on-pop.
- **Pinch-zoom, pan, or multi-series** interactions — a single windowed line only.
- **Mixing currencies** into one line — forbidden by the currency-lens rule.
- **Per-Contact** analysis graphs — the graph is all-Contacts; per-Contact insight lives in the running summary / statement (#10).
- Changes to the **home period filter or Flow header** themselves (delivered in #7).

## Further Notes

- Blocked-by #7 is **closed**; the period infrastructure (`resolvePeriod`, `DateRange`, the selector widget) this slice depends on is in place.
- Respect the RTL/bilingual and light/dark obligations from the design system — the painter must read tokens, not hard-coded colors, and axis/label layout must mirror in Arabic.
- Keep the deltas-sum-to-movement invariant as the linchpin that makes the drill-down trustworthy; it's both a unit test and a correctness guarantee.
