# Daftar (دفتر) — Personal Debt Ledger

A people-first debt/IOU ledger for Android. Track what's owed **to you** and **by you**, per person, in Saudi Riyal (SAR) and Yemeni Riyal (YER) — then export a per-person PDF statement.

Fully bilingual (Arabic / English, RTL-aware), local-only storage, light & dark themes.

> Not a category-based expense tracker. The primary object is a **person**, and every line is a debt in one direction.

## Features

- **Per-person ledgers** — each contact is a ledger; entries can run in both directions
- **Dual currency as a global lens** — SAR / YER tabs refilter the entire app; each currency keeps its own independent balance and totals are never summed across them
- **PDF statements** — dated table with opening balance, gross directional totals, running balance and closing balance; date-range filtering clips rows without falsifying the balance
- **Analysis graph** — running balance over time, from the same pure series that drives the statement
- **Built-in amount calculator** — `+ − × ÷` with operator precedence on any amount field; result-only, so nothing extra touches the schema
- **Backup & restore** — manual, file-based, portable
- **WhatsApp deep links** — pre-filled balance message for informal nudges
- **Switchable accent themes** with light/dark support

## Tech

`Flutter` · `Dart` · `SQLite (sqflite)` · `pdf` + `printing` · `intl` + `flutter_localizations` · `share_plus` · `file_picker`

## Architecture

Clean layering under `lib/`:

```
domain/        pure model & rules — balance, running_summary, statement,
               currency, entry, contact, calculator, analysis_graph …
data/          SQLite persistence and backup format
presentation/  screens, widgets, state
branding/      design system & accent themes
l10n/          Arabic / English localisation
```

The domain layer is pure and dependency-free, so on-screen balances, the analysis graph and the exported PDF are computed from one shared series and can never disagree.

## Documentation

This project is documented as it was designed, not after the fact:

- [`docs/PRD.md`](docs/PRD.md) — product requirements
- [`docs/adr/`](docs/adr/) — 11 architecture decision records covering storage, the currency lens, statement rendering, backup format, data lifecycle and more
- [`docs/design-system.md`](docs/design-system.md) · [`docs/brand-concept.md`](docs/brand-concept.md)
- [`CONTEXT.md`](CONTEXT.md) — domain glossary / ubiquitous language (EN + AR)

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter with Dart SDK `^3.12.2`.

```bash
flutter build apk --release    # Android release build
```

## Status

Active personal project. Local-only by design — no account, no server, no telemetry.
