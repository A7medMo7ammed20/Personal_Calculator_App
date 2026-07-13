# 2. Token-based design system with user-switchable accent themes; fixed money semantics

Date: 2026-07-13

## Status

Accepted

## Context

Daftar's UI grew slice-by-slice with no shared visual language. Concretely:

- Colour was a single `ColorScheme.fromSeed` green seed (`#2E7D5B`), and that **same
  green** was reused as the semantic "owed to me" colour, with red for "owed by me".
  So the app's brand chrome (app bar, FAB, selection) and its money-direction signal
  were the *same* colour — a green FAB reads as "positive money" everywhere and dilutes
  the green→"someone owes you" meaning.
- Spacing was bare magic numbers (16/12/8/4) inlined across every widget.
- `_green` / `_red` were re-declared as private constants in multiple files.

We want a real design system (brand, colour roles, spacing, type) before building more
slices, and the user is unsure which single brand colour is best.

Forces:

- **Brand vs. meaning.** If the brand colour equals a semantic colour, the two signals
  compete and neither is trustworthy.
- **Indecision on brand hue.** No single accent is obviously right for the audience.
- **Money semantics must be stable.** Green=owed-to-me / red=owed-by-me is the core
  reading of every screen and the PDF statement; it cannot vary or the same colour would
  mean different things in different states.
- **Maintainability.** Scattered literals make any change a find-and-replace.

Options considered:

- **A. One fixed brand colour, keep green as brand+semantic.** Least work; preserves the
  colour collision above.
- **B. One fixed brand colour, distinct from green/red.** Fixes the collision but forces
  a single-hue decision the user isn't ready to make.
- **C. Several user-switchable accent themes, brand distinct from fixed semantics,
  tokens via `ThemeExtension`.** Resolves the collision *and* the indecision by letting
  the user pick; costs a settings surface and a token layer.

## Decision

Adopt **Option C**.

- **Brand accent is separate from money semantics.** The accent themes the app *chrome*
  (primary, app bar, FAB, selection, logo). Green (`owed to me`), red (`owed by me`) and
  a neutral (`settled`) are **semantic colours that stay fixed across every theme**,
  resolved per brightness for legibility.
- **Four shipped accents, user-switchable in Settings:** Teal `#14746F` (default),
  Indigo `#3538CD`, Plum `#6D28D9`, Ocean Blue `#0369A1`. Each theme =
  `ColorScheme.fromSeed(seedColor: accent, brightness: …)`; the seed drives chrome only.
- **Brightness is an independent axis:** System (default) / Light / Dark.
- **Tokens live in `ThemeExtension`s** (`AppSpacing`, `AppRadius`, `AppSemanticColors`),
  implementing `lerp` so they animate across theme changes. Widgets read
  `Theme.of(context).extension<…>()`; no more inline literals or per-file `_green`.
- **The baked launcher icon and first-run splash use the default Teal** — a launcher icon
  cannot follow a per-user accent, so the *installed* identity is fixed while the in-app
  chrome re-tints on switch.
- **Selected accent + brightness persist in a `settings` table in the existing SQLite**,
  so they travel with the [Backup](0001-local-only-storage-with-manual-backup.md) and add
  no new dependency.

Concrete token values live in [docs/design-system.md](../design-system.md).

## Consequences

- **Positive:** The green→"owed to you" signal is never diluted by brand chrome. Users
  who dislike teal can pick another accent without the app ever changing what a colour
  *means*. One-line token edits replace find-and-replace.
- **Positive:** `ThemeExtension` + `fromSeed` is idiomatic Material 3; adding a fifth
  accent later is a one-entry change.
- **Negative:** More surface than a single theme — a Settings screen, a persisted
  preference, and semantic colours that must be *deliberately* kept out of the accent
  system every time a new component is built.
- **Negative:** The launcher icon can look "teal" to a user who has chosen, say, Plum in
  the app. Accepted: the installed identity is a brand constant, not a personalisation.
- **Negative:** Semantic colours resolved per brightness must be hand-tuned so red/green
  stay distinguishable (and colour-blind-safe) in dark mode.
