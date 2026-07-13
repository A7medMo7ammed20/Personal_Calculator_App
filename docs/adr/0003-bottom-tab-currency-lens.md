# 3. Currency lens as swipeable bottom tabs; rarely-used destinations behind an overflow menu

Date: 2026-07-13

## Status

Accepted. **Amended 2026-07-13 by [ADR 0004](0004-analysis-graph-rendering-and-windowing.md):** the
Analysis graph (#8) is an **all-Contacts** view, so it is *not* placed inside the Contact screen as
the Decision below anticipated — it is a global destination behind the home overflow (⋮), alongside
Settings and Backup. Per-contact Statements (#10) remain inside the Contact screen as written.

**Also amended 2026-07-13 by [ADR 0005](0005-row-swipe-actions-and-tap-only-currency-lens.md):** the
currency lens is **no longer swipeable** — horizontal swipe is reassigned to per-row swipe-to-reveal
actions, and currency switches by **tapping** a bottom tab (restyled as a floating pill with an
animated indicator). The lens-in-the-bottom-bar and overflow-⋮ decisions below stand.

## Context

Currency is a **global lens**: the app shows exactly one of SAR / YER at a time, and the
two are never summed (see [CONTEXT.md](../../CONTEXT.md) — Currency). The original home
screen stacked five full-width control bands before any content: currency
`SegmentedButton` → two totals boxes → period selector → search/sort → the contact list.
Controls dominated; the list was squeezed. The UX rework needed a home to the point.

Two questions had to be answered together:

1. **Where does the currency lens live?** It is switched constantly, so it wants to be
   fast and thumb-reachable.
2. **Where do non-ledger destinations live?** Settings (new, hosting the accent +
   brightness pickers) and Backup — and later the Analysis graph (#8) and per-contact
   Statements (#10) — are *rarely* accessed and should not compete for attention.

Options considered for the lens:

- **A. Keep a top segmented control.** Conventional, but it's one of the stacked bands
  that made the screen feel control-heavy, and it's a top-of-screen reach.
- **B. Move currency into the app bar.** Frees a band, but the app bar is a cramped,
  top-reach spot and can't show an animated active-tab affordance well.
- **C. Swipeable bottom tabs for SAR / YER** with an animated active-tab indicator.
  Thumb-reachable, one-handed, and swiping the body changes currency.

Options for the other destinations: bottom-nav sections, a left drawer, or an app-bar
overflow menu.

## Decision

- **Currency is a swipeable bottom tab bar** (SAR / YER) with an animated indicator on
  the active tab; horizontal swipe of the body changes currency. This is **Option C**.
- **The bottom bar is currency and nothing else.** Daftar is effectively a single
  section (the ledger) with two currencies, so the bottom bar is spent on the lens rather
  than on app sections.
- **Rarely-used global destinations (Settings, Backup) hide behind a single app-bar
  overflow menu (⋮).** Per-contact Statements and the future Analysis graph belong
  *inside* the Contact screen, not on home, so home stays minimal.
- The home body reduces to: unified **summary card** (the active currency's two
  directional totals, or Flow lent/received when a period is bounded) → one **toolbar**
  (period chip · search · sort icon) → single-line **contact rows** (avatar · name ·
  colored signed balance; phone is *not* shown — it is used only in PDF/WhatsApp).

## Consequences

- **Positive:** Switching currency is a one-handed thumb tap or swipe, with a clear
  animated "which currency am I in" affordance. The home screen sheds control bands and
  becomes list-forward.
- **Positive:** Keeping rarely-used features behind ⋮ matches the "keep it simplest" goal
  — they exist but don't draw the eye.
- **Negative / unconventional:** A bottom bar normally holds top-level *sections*, not a
  two-value data filter. New contributors (and some users) may expect the bottom tabs to
  be app areas. Accepted because the app genuinely has one section and constant currency
  switching.
- **Negative:** If Daftar later grows several real top-level sections, the bottom bar is
  already occupied by currency and the IA would need revisiting (currency would likely
  demote to a top tab strip). This decision is scoped to the current single-section app.
- **Negative:** Swiping the list horizontally to change currency can conflict with other
  horizontal gestures (e.g. swipe-to-act on a row); row gestures must be chosen so they
  don't fight the page swipe.
