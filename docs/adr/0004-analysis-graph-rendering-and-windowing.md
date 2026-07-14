# 4. Analysis graph: bespoke CustomPainter, opening-balance carry-in, adaptive calendar buckets

Date: 2026-07-13

## Status

Accepted. Revises the placement clause of [ADR 0003](0003-bottom-tab-currency-lens.md).
Amended 2026-07-14 — the point/drill-down decisions below are superseded by the
**Amendment** at the end (per-entry line + by-contact bars).

## Context

Slice #8 adds an **analysis graph**: a per-currency line of the **cumulative net
[[Balance]] over time across all Contacts**, following the global currency lens, with
its X range following the home [[Period filter]], and a tap-to-drill-down that lists an
interval's entries by Contact. Several decisions had genuine alternatives:

1. **Placement.** ADR 0003 anticipated the graph living *inside* the Contact screen. But
   #8 is explicitly **all-Contacts** ("who caused the increase"), which is a global
   destination, not a per-Contact one.
2. **Rendering.** The app is deliberately dependency-light — runtime deps are only
   `sqflite`, `path`, `intl`, with **no third-party UI packages**. A chart could add
   `fl_chart` (batteries-included touch/tooltips/grids) or be hand-rolled.
3. **Windowing semantics.** CONTEXT's golden rule: a Balance is cumulative and all-time
   and is **never recomputed over a window**. What does the line show at a bounded
   period's left edge — the carried-in real position, or zero?
4. **Point granularity.** A running balance only changes at an entry, but the drill-down
   needs a non-degenerate "interval" of entries per point.

## Decision

- **Placement — global, behind ⋮.** The graph is a global destination reached from the
  home app-bar overflow menu, alongside Settings and Backup. It reads the current lens +
  period, hosts its own compact controls (a top SAR/YER **segmented toggle** — the bottom
  tab bar stays home's identity — and the shared period chip), and on pop **returns** the
  possibly-changed lens/period so home adopts them. This follows the existing
  push → return-result → reload idiom; lens/period stay `HomeScreen` locals (no lifted
  global controller this slice).
- **Rendering — bespoke `CustomPainter`.** One windowed line, a few axis labels, and
  tap hit-testing against bucket points, themed with existing tokens. No charting
  dependency is added.
- **Windowing — carry in the opening balance.** The line is a **view onto the real
  all-time running balance, windowed only in X**. Under a bounded period the left edge is
  the true position carried in from before the window; the balance is clipped in view,
  never recomputed. All time spans first-entry-date → today. This reuses the existing pure
  `runningSummary` seam; a thin `listByCurrency(currency, {upTo})` read supplies all
  entries up to the window end.
- **Points — adaptive calendar buckets**, granularity from the visible span: **≤ 62 days
  → daily**, **63–400 → weekly**, **> 400 → monthly**; boundaries calendar-aligned in
  local time; week start is locale-aware via `intl`; **empty buckets carry the balance
  forward** (flat segment, never a drop to zero). Each point's Y is the cumulative balance
  at the bucket's end.
- **Drill-down — per-Contact net delta.** Tapping a point reuses `entriesInRange` for the
  bucket's `[start, end)` and a pure group-by-Contact function that emits each Contact's
  **net delta** (green/red, sorted by magnitude); deltas sum to the segment's movement.
  Shown in a bottom sheet styled like the existing running-summary sheet.

## Consequences

- **Positive:** No new dependency; the local-only, austere, "calm notebook" ethos holds,
  and the chart themes with existing tokens with no styling-API impedance or RTL surprises.
- **Positive:** Carry-in keeps the graph honest with the all-time-balance rule — it shows
  *position over time*, not a false in-window origin, so "rising = owed-to-me increasing"
  stays true.
- **Positive:** Series and breakdown are **pure functions** over `runningSummary` /
  `entriesInRange`, unit-testable without DB or UI (satisfies #8's test AC directly).
- **Negative / cost:** Hand-rolling axis scaling, calendar bucketing, and tap hit-testing
  is our code to maintain; richer interactions (pinch-zoom, multi-series) would be more
  work than with a library. Accepted — the requirement is a single windowed line.
- **Negative:** Lens/period sync is "on return," not live-simultaneous. Acceptable since
  only one screen is visible at a time; if a lifted lens controller is later introduced,
  this screen adopts it with no semantic change.

## Amendment — 2026-07-14: per-entry line + a by-contact bar view

### Context

On-device with real seed data the shipped line looked **empty**. The cause: this
ledger's data clusters on ~1 calendar day, and a **daily-bucket** point plots one vertex
per calendar day — so eleven same-day entries collapsed into a single dot with nothing to
draw between. Calendar bucketing optimises for a shape (activity spread over weeks/months)
this app rarely has. The user asked to **switch between chart types** and to pick the ones
that suit this project.

### Decision (supersedes the "Points" and "Drill-down" bullets above)

- **Over-time line — one vertex per Entry, not per calendar bucket.** The series steps at
  every Entry (evenly spaced **by index**, so a same-timestamp cluster never overlaps),
  which is always visible regardless of how the dates bunch up. Carry-in is unchanged and
  now *inherent*: it reuses the existing `runningSummary` seam (ascending cumulative
  balance per Entry) and, under a bounded period, simply **filters** the points to the
  window — the running total already carried the opening balance in. `BucketGranularity`,
  `bucketGranularityForSpanDays`, and `cumulativeSeries` are removed in favour of a small
  `runningBalanceSeries(entries, {range})`.
- **A second view — by-contact diverging bars.** A horizontal bar per Contact of their
  **all-time net [[Balance]]** (green = owed-to-me to one side of a centre zero line,
  red = owed-by-me to the other), sorted by magnitude. Being a **snapshot**, it is immune
  to the same-day-clustering problem the line suffers. It reads the existing
  `EntryRepository.balancesByCurrency` through a pure `contactBalancesSorted` seam
  (settled contacts dropped, sorted by magnitude then contact id). Because a Balance is
  **all-time and never windowed** (CONTEXT.md's golden rule), the period chip is **hidden**
  on this view.
- **Chart-type toggle.** A segmented control at the top of the screen switches
  over-time ↔ by-contact, alongside the currency segmented toggle.
- **Pie/donut rejected.** A pie can't encode debt **direction** (a slice has no sign), and
  bars compare magnitudes across contacts far better. Diverging bars keep the green/red
  direction language the rest of the app uses.
- **Rendering — the line stays a bespoke `CustomPainter`; the bars are plain widgets.**
  Still **no charting dependency** (the ADR's core constraint holds). The bars are built
  from `Stack`/`Positioned`/`DecoratedBox` rather than a painter so contact labels, RTL,
  and per-bar hit-testing come for free — a painter would re-implement all three.
- **Drill-down — simplified to the tapped Entry.** Tapping a line vertex opens a sheet with
  that Entry's contact, signed amount, date, and note — replacing the interval-breakdown
  sheet. `intervalBreakdown` / `ContactDelta` and the breakdown use of `entriesInRange` are
  removed.

### Consequences

- **Positive:** The line is robust to this app's real data shape (dense same-day activity)
  — the original AC "the line is always visible" now holds by construction.
- **Positive:** Two complementary questions answered — *how did my position move over time?*
  (line) and *who am I most exposed to right now?* (bars) — with one lens and one toggle.
- **Positive:** Both remain **pure seams** (`runningBalanceSeries`, `contactBalancesSorted`)
  over `runningSummary` / `balancesByCurrency`, unit-tested without DB or UI.
- **Neutral:** We lose calendar-aligned x-spacing; the line is now ordinal (by entry index),
  not strictly time-proportional. Accepted — for this data an always-legible ordinal line
  beats a time-accurate one that renders as a dot. End-date labels still show real dates.
