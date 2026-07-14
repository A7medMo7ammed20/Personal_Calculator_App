# 6. PDF statements via `pdf`/`printing` with an embedded Arabic font, and a lazy Profile name prompt

Date: 2026-07-14

## Status

Accepted. Builds on the carry-in windowing rule of
[ADR 0004](0004-analysis-graph-rendering-and-windowing.md) and the local-only,
offline constraint of [ADR 0001](0001-local-only-storage-with-manual-backup.md).

## Context

Slices #9 (Profile & first-run name prompt) and #10 (PDF statement) ship together
and depend on each other: the [[Statement]]'s header names the creditor, which is
the [[Profile]] name, and #9's rule is that the name is requested **only at the
moment it is first needed** — the first PDF export — never as a setup gate. Several
decisions had genuine alternatives:

1. **PDF toolchain.** Rendering a bilingual document with **Arabic RTL** while
   staying fully offline (ADR 0001) rules out anything network-backed. Options:
   the `pdf` + `printing` packages, `syncfusion_flutter_pdf`, HTML-to-PDF via
   `Printing.convertHtml`, or rasterising a Flutter widget to an image.
2. **Model vs. rendering.** #10's test AC asserts document *structure* (row order,
   columns, opening/closing balance, totals, RTL flag) **without rendering pixels**.
3. **Date-range semantics.** A statement can be filtered to a [[Period filter]]
   range. CONTEXT's golden rule: a [[Balance]] is all-time and **never recomputed
   over a window**. What does a windowed statement show at its top edge?
4. **Where the Profile lives, and when the name is asked.** The single owner is one
   record; #9 forbids a setup form and requires "prompt once, on first export."

## Decision

- **Toolchain — `pdf` + `printing` (davbfr/dart_pdf).** Idiomatic, fully offline,
  and it renders **Arabic RTL with automatic glyph shaping** (isolated/initial/
  medial/final forms + LAM-ALEF ligatures) when given a real Arabic TTF and
  `TextDirection.rtl`. No charting/office dependency, consistent with the app's
  austere dependency set.
- **RTL via the already-bundled font.** The renderer loads the bundled
  **IBM Plex Sans Arabic** TTF into a `pw.Font` (via `fontFromAssetBundle`) and sets
  the page/table `textDirection` from an `isRtl` flag derived from the app locale
  (`ar` → RTL, `en` → LTR). The font is now also listed as a loadable **asset** (it
  was previously declared only under pubspec `fonts:`, which the widget theme reads
  but `fontFromAssetBundle` cannot).
- **Pure model + thin renderer.** A pure `buildStatement(profile, contact, entries,
  currency, range, locale) → StatementDocument` produces a library-agnostic value
  object (`creditorName`, `contactName`, `contactPhone`, `currency`, `dateRange?`,
  `isRtl`, `openingBalance`, `rows[]`, `totalOwedToMe`, `totalOwedByMe`,
  `closingBalance`). The renderer only reads that object into `pw.*` widgets, so the
  model is unit-tested with zero `pdf`/`printing` involvement (satisfies #10's AC).
- **Reuse the [[Running summary]] seam.** Rows come from the existing pure
  `runningSummary(entries)` — the same series behind the on-screen preview and the
  [[Analysis graph]] (#8) — so the three surfaces never disagree about what a
  [[Balance]] is. Columns are `date | description | owed-to-me | owed-by-me |
  running Balance`, oldest→newest, with the two gross column totals and the net
  closing Balance in a footer, mirroring the running-summary sheet.
- **Windowing — carry in the opening balance (per ADR 0004).** Under a bounded
  range the rows are **clipped in view** but the balance is **never recomputed**:
  the statement shows an **opening balance** (the true running position just before
  the range), the running/closing Balance stay all-time, and only the two gross
  totals cover the in-range activity — so *opening + period activity = closing*.
  At all-time (the default) the opening balance is zero and the statement spans the
  full history. This is the same rule the analysis line already follows.
- **Delivery — `Printing.sharePdf`.** The finished bytes go straight to the OS share
  sheet (WhatsApp, email, Drive, Save to Files), which is the statement's actual
  purpose. No in-app print/preview screen this slice. The shared file uses an
  ASCII-safe, stable name so an Arabic contact name never trips the filesystem; the
  document content stays fully localized/RTL.
- **Profile — k/v in the existing `settings` table, name asked lazily.** The single
  [[Profile]] is stored as `profile_name` / `profile_phone` keys in the `settings`
  table (no migration; rides Backup like accent/theme, per ADR 0001) behind a typed
  domain `Profile` and a `ProfileController` mirroring `ThemeController`. **Absence
  of the name key is the "not set yet" signal.** A reusable
  `ensureProfileName(context)` seam prompts once — a modal dialog collecting the name
  only (trimmed; blank re-prompts), Cancel aborts the export — and never fires again
  once the key exists. #10's export calls this seam; #9 owns it and its
  prompt-once test, so neither slice's tests depend on the other's UI.

## Consequences

- **Positive:** Offline, idiomatic, and RTL-with-shaping out of the box, reusing the
  bundled Arabic font and the existing `runningSummary` seam — no new balance math.
- **Positive:** The statement model is a pure function, unit-testable without
  rendering (satisfies #10's AC directly), and carry-in keeps the PDF honest with
  the all-time-balance rule the graph and preview already obey.
- **Positive:** The Profile costs no schema migration and travels with the Backup;
  the lazy name prompt keeps first run frictionless (empty ledger, no setup gate).
- **Negative / cost:** The renderer is coupled to the `pdf`/`printing` API; swapping
  toolchains later means rewriting it. Accepted — the alternatives were heavier
  (`syncfusion`, license strings), weaker at RTL (HTML-to-PDF), or produced
  non-selectable rasterized text (widget-to-image).
- **Negative:** The Arabic TTF must be maintained as a loadable asset in addition to
  its `fonts:` declaration; forgetting it renders Arabic as tofu. Covered by an
  export smoke path during implementation.
