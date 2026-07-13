# PRD — UI enhancements: animated currency lens, row swipe-to-reveal, معاملة term

Date: 2026-07-13
Status: Ready for implementation
Related: [ADR 0005](../adr/0005-row-swipe-actions-and-tap-only-currency-lens.md), [ADR 0003](../adr/0003-bottom-tab-currency-lens.md), [ADR 0002](../adr/0002-design-system-and-switchable-accent-themes.md), [CONTEXT.md](../../CONTEXT.md)

## Problem Statement

Three friction points in the Daftar UI:

1. **The bottom currency tabs feel flat and static.** Switching between SAR and YER gives no
   satisfying "where am I now" motion, and the bar doesn't feel like a deliberate, modern control.
2. **Row actions are undiscoverable.** To Edit or Delete a Contact or an Entry you must *long-press*,
   which then floats buttons above/around the row. Users don't discover the long-press, and the
   floating buttons read as awkward. The expected gesture — swipe the row to reveal actions — is missing.
3. **"حركة" is meaningless to users.** The Arabic label for an Entry (`إضافة حركة`, `حذف الحركة؟`, …)
   uses حركة, which is both vague and overloaded (it also names Flow, `الحركة`). Users can't tell what
   it refers to.

## Solution

1. **Restyle the currency lens** as a floating pill bar whose active-tab indicator **animates/slides**
   to the selected currency, tinted with the user's chosen accent. Currency switches by **tapping**.
2. **Swipe-to-reveal row actions** on **both** the Home contact list and a Contact's entries list:
   swipe a row → **Edit + Delete** appear **beside** it → tap one → the row springs back. The old
   long-press overlay is removed. Horizontal body-swipe (previously "change currency") is retired.
3. **Rename the Entry label** from حركة to **معاملة** everywhere in Arabic; `حركة/الحركة` is reserved
   for Flow only.

## User Stories

1. As a user, I want the active currency tab to visibly animate when I switch, so that I always know
   which currency lens I'm in.
2. As a user, I want the currency bar to use my chosen accent color, so that it matches my theme.
3. As a user, I want to tap a currency tab to switch, so that switching is predictable and unambiguous.
4. As a user, I want a person's entries and my contact list to react only to the selected currency,
   so that SAR and YER never mix (unchanged behavior, preserved after the gesture change).
5. As a user, I want to swipe a **contact** row to reveal Edit and Delete beside it, so that I can act
   on a contact without hunting for a long-press.
6. As a user, I want to swipe an **entry** row to reveal Edit and Delete beside it, so that row actions
   feel the same everywhere in the app.
7. As a user, I want the swipe direction to feel natural in Arabic (RTL) and English (LTR), so that the
   gesture mirrors correctly per language.
8. As a user, I want tapping **Edit** on a revealed row to open the same edit screen as before, so that
   editing is unchanged apart from how I reach it.
9. As a user, I want deleting a **contact** to still warn me how many entries will be removed and let me
   undo, so that I don't lose data by accident.
10. As a user, I want deleting an **entry** to be immediate but undoable via a SnackBar, so that a
    deliberate tap on the revealed Delete isn't slowed by an extra dialog.
11. As a user, I want the revealed row to close when I tap elsewhere or act, so that the list stays tidy.
12. As an Arabic user, I want the "Add" button and all Entry dialogs to say **معاملة**, so that I
    understand I'm adding/editing/deleting a transaction.
13. As an Arabic user, I want delete-count messages to read naturally with معاملة/معاملات, so that the
    plural grammar is correct.
14. As an English user, I want no change to my labels ("Entry"/"Add"), so that nothing regresses for me.
15. As a user, I want the currency lens to keep working after the swipe gesture is removed from the body,
    so that I lose nothing functional — only the body-swipe shortcut.

## Implementation Decisions

- **New dependency:** add `flutter_slidable` to `pubspec.yaml` (first UI package). Chosen for its
  RTL-aware start/end action panes over a hand-built reveal widget (ADR 0005).
- **Currency lens (`_CurrencyLens` in `home_screen.dart`):** replace the plain M3 `NavigationBar` with a
  floating, rounded pill bar. The active indicator animates its position to the selected currency and is
  tinted with `colorScheme.primary` (the resolved accent, ADR 0002). Tap-to-select only.
- **Remove body-swipe:** delete the currency `GestureDetector` and its `_swipeDx`/`_onSwipeEnd` logic
  from `HomeScreen`. Currency changes only via the lens taps.
- **Row actions — both lists:** wrap each contact tile (`home_screen.dart`) and each entry tile
  (`contact_screen.dart`) in a `Slidable` with one action pane holding **Edit** and **Delete**,
  declared with start/end semantics so it mirrors under RTL/LTR. Reuse the existing handlers
  (`_editContact`/`_deleteContactWithConfirm`, `_editEntry`/`_deleteEntry`).
- **Delete confirmation by stakes:** Contact delete keeps the cascade-count confirm dialog + undo
  SnackBar; Entry delete drops the confirm dialog and keeps the undo SnackBar only.
- **Remove `item_actions_overlay.dart`** and its long-press wiring (`_showContactActions`,
  `_showEntryActions`, the `onLongPress` handlers) from both screens.
- **Term change:** in `lib/l10n/app_ar.arb`, replace حركة/الحركة with معاملة/المعاملة in `addEntry`,
  `editEntry`, `deleteEntryTitle`, `deleteEntryMessage`, `entryDeleted`, and the `deleteContactMessage`
  plural forms (معاملة/معاملتان/معاملات per Arabic plural rules). Regenerate `app_localizations_ar.dart`.
  English ARB untouched.

## Testing Decisions

Good tests here assert **external behavior** through the existing widget-test seams — what the user
sees and can do — not widget internals.

- **`test/presentation/home_screen_test.dart`** — assert a contact row can be swiped to reveal Edit and
  Delete, tapping Delete triggers the confirm+undo path, tapping Edit navigates to the edit screen; and
  that the currency lens still switches by tapping a tab. (Prior art: existing home_screen swipe/tap tests.)
- **`test/presentation/contact_screen_test.dart`** — same swipe-to-reveal assertions for entry rows;
  Delete is immediate + undoable (no confirm dialog). (Prior art: existing contact_screen tests that
  previously drove `Dismissible`, per slice-5 history.)
- **`test/presentation/currency_lens_test.dart`** — the lens renders both currencies, reflects the
  selected one, and switches on tap. (Prior art: existing currency_lens test.)
- **Term:** assert the Arabic `addEntry`/delete strings contain معاملة (and not حركة) via an ARB/l10n
  test, or a widget test pumping the `ar` locale. (Prior art: existing localized widget tests.)
- **Delete** `test/presentation/item_actions_overlay_test.dart` — the overlay is gone.

## Out of Scope

- Any change to app **sections/IA** — the bottom bar stays the 2-currency lens (ADR 0003).
- A raised center CTA / 5-tab structure from the reference image — not applicable.
- English wording changes.
- Running-summary and WhatsApp shortcuts — untouched; not added to the swipe pane.
- Schema/data changes — none.

## Further Notes

- The `contact_screen.dart` doc comment "the currency lens arrives in #4" is stale but out of scope here.
- Watch RTL: verify the swipe pane and the animated lens indicator both mirror correctly under `ar`.
- After the ARB edit, run the localization codegen (`flutter gen-l10n` / build) so `app_localizations_ar.dart`
  regenerates rather than hand-editing the generated file.
