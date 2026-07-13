# 5. Row swipe-to-reveal actions; the currency lens becomes tap-only

Date: 2026-07-13

## Status

Accepted. **Amends [ADR 0003](0003-bottom-tab-currency-lens.md):** the currency lens is no
longer *swipeable* — it switches by tapping a bottom tab. Horizontal swipe is reassigned to
per-row actions. ADR 0003's other decisions (currency lives in the bottom bar; rarely-used
destinations behind the overflow ⋮) stand.

## Context

Two facts collided.

1. **ADR 0003** put the currency lens (SAR / YER) in the bottom bar and let a **horizontal
   swipe of the body** switch currency. It explicitly warned: "Swiping the list horizontally
   to change currency can conflict with … swipe-to-act on a row; row gestures must be chosen
   so they don't fight the page swipe."
2. Row actions (Edit / Delete) had, since slice 5, moved to a **long-press floating overlay**
   (`item_actions_overlay.dart`) — precisely to avoid that collision. But users found the
   long-press overlay unintuitive: the buttons appear *above/around* the row with no
   discoverable affordance. The request was the now-standard **swipe-to-reveal** pattern
   (drag the row a short distance; it slides and holds open, exposing stationary Edit/Delete
   buttons beside the row; tap one; the row springs back).

Only one of the two can own the horizontal swipe. We had to choose.

Options for the gesture conflict:

- **A. Keep swipe-for-currency; keep long-press for rows.** No swipe-to-reveal — leaves the
  original complaint unaddressed.
- **B. Keep swipe-for-currency; give only the *entries* list swipe-to-reveal.** Splits the app
  into two row-action gestures (swipe for entries, long-press for Home contacts) — inconsistent,
  and the user's complaint was specifically about the **Home** list.
- **C. Reassign horizontal swipe to row actions everywhere; currency switches by tapping the
  bottom tab.** One consistent row gesture across the whole app; no collision.
- **D. Both, disambiguated by zone** (rows swipe; currency-swipe survives only on non-row
  areas). Currency-swipe becomes unreliable on a list-full screen.

## Decision

- **Option C.** Horizontal swipe belongs to **row actions**. **Both** lists — Home contacts and
  a Contact's entries — use **swipe-to-reveal**: swiping a row exposes **two buttons beside it**,
  **Edit** and **Delete**, in a single action pane. Implemented with the **`flutter_slidable`**
  package (the first UI dependency), declared with start/end **semantics** so it mirrors
  correctly under RTL (Arabic) and LTR (English).
- **The currency lens becomes tap-only.** The bottom bar keeps its two tabs and gains a
  **restyled, floating pill** look with an **animated indicator that slides** to the active
  currency (using the user's chosen accent, per [ADR 0002](0002-design-system-and-switchable-accent-themes.md),
  not a hardcoded colour). Tapping a tab switches; there is no body-swipe.
- **The long-press overlay is removed** (`item_actions_overlay.dart` and its test) — nothing
  uses it after this.
- **Delete confirmation differs by stakes:** deleting a **Contact** cascades its entries, so it
  keeps the confirm dialog + undo SnackBar. Deleting an **Entry** drops the confirm dialog
  (tapping a revealed button is already deliberate) and relies on the **undo SnackBar** alone.

## Consequences

- **Positive:** One discoverable, consistent row gesture across the whole app; the swipe
  affordance is standard and expected. The gesture collision ADR 0003 flagged is gone.
- **Positive:** The bottom tabs still switch currency in one thumb tap, now with a clearer
  animated "which currency am I in" affordance.
- **Negative:** Loses swipe-to-change-currency — a fast shortcut some users may have learned.
  Judged an acceptable trade for a working row gesture and app-wide consistency.
- **Negative:** Adds `flutter_slidable`, the app's first UI package (storage/intl aside). Accepted
  as the standard, RTL-aware choice over a hand-built reveal widget.
- **Cost:** The `حركة`→`معاملة` term change (see [CONTEXT.md](../../CONTEXT.md) — Entry) is
  unrelated to the gesture work but shipped in the same UI pass.
