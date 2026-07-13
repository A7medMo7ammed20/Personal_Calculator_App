# 4. Analysis graph: bespoke CustomPainter, opening-balance carry-in, adaptive calendar buckets

Date: 2026-07-13

## Status

Accepted. Revises the placement clause of [ADR 0003](0003-bottom-tab-currency-lens.md).

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
