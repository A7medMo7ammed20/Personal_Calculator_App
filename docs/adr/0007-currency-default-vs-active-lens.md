# 7. Currency default persisted and live-applied via a global controller, distinct from the active lens

Date: 2026-07-14

## Status

Accepted. Extends the currency-lens model of
[ADR 0003](0003-bottom-tab-currency-lens.md) (amended by 0004/0005) and rides the
`settings` table / Backup of [ADR 0002](0002-design-system-and-switchable-accent-themes.md)
and [ADR 0001](0001-local-only-storage-with-manual-backup.md).

## Context

Slice #12 adds a **Settings** screen for the app-wide defaults: default currency,
language, theme. Theme was already a live global (`ThemeController`, ADR 0002);
default currency and language were not.

- The currency lens lived as **`HomeScreen` local State hardcoded to SAR**. A
  "default currency" must (a) seed which lens is active on launch and (b) —
  the behaviour chosen for this slice — **live-switch** the active lens the moment
  it is changed in Settings.
- Tension: the lens is *also* toggled constantly via the bottom tabs. Does a tab
  tap rewrite the default? Two models were on the table — **sticky / last-used**
  (one value; every change, tab or Settings, persists) versus an **explicit
  default** (only Settings persists; tab taps are transient).

## Decision

- **Promote the lens to a global `CurrencyController`** (`ChangeNotifier`),
  mirroring `ThemeController`. It holds `active` + `defaultCurrency`, **both seeded
  from the persisted default at startup**.
- **Bottom tabs call `setActive`** — move the active lens for the current session
  only; never persist.
- **Settings' Default currency calls `setDefault`** — live-switch the active lens
  **and** persist the new launch default.
- So `default` and `active` can **diverge within a session and re-converge on the
  next launch**. We chose the **explicit default** over sticky/last-used so that
  "Default currency" means exactly what the user set, not "whatever I last tapped."
- **Persistence:** a `default_currency` key in the `settings` table (degrades to
  SAR on an unknown/missing value, like the other prefs), riding the Backup.
- **Language follows the same shape:** a `LocaleController`
  (`LanguageChoice { system, arabic, english }`, default `system`) drives
  `MaterialApp.locale`, persisted as a `language` key, re-localizing and flipping
  RTL/LTR live. Theme is unchanged — it was already this pattern.

## Consequences

- **Positive:** one consistent controller pattern for every live app-wide setting.
  #12's AC — "the default-currency setting drives the initial lens" — becomes a
  clean testable seam: seed the controller, pump the app, assert the opening lens.
- **Positive:** the tabs stay a fast, transient view control while the default is a
  deliberate, persisted preference — the two roles no longer fight for one value.
- **Negative:** the lens is now a global rather than `HomeScreen` State — home and
  the Contact screen read it from the controller, and `main`/root wire three
  controllers. A small but real refactor.
- **Negative:** the default-vs-active split can momentarily surprise ("I set YER as
  the default but I'm still on SAR after tapping SAR"). Accepted as the correct
  reading of the word *default*.
