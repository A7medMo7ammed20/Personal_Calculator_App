# 8. WhatsApp/dialer deep links via `url_launcher`, compatible with local-only; minimal phone handling

Date: 2026-07-14

## Status

Accepted. Reconciles slice #11 with the local-only / offline constraint of
[ADR 0001](0001-local-only-storage-with-manual-backup.md).

## Context

Slice #11 adds quick informal [[Contact]] actions: a **WhatsApp** balance nudge
(a `wa.me` deep link with a pre-filled, editable message) and **tap-to-call**
(`tel:`). This needs a new dependency, `url_launcher` — the app had kept an
austere, fully-offline dependency set (ADR 0001: local-only, no accounts, no
network calls, no cloud).

Two decisions had genuine alternatives:

1. **Does opening WhatsApp / the dialer violate "local-only, no network"?** A strict
   reading of ADR 0001 could reject any feature that reaches another network app.
2. **Phone format.** `wa.me` needs international-format digits, but contacts are
   often stored as local `05…` numbers. Normalise (guess a country code) or not?

## Decision

- **Add `url_launcher`; launch `wa.me` (https) and `tel:` through the OS.** Handing
  off to another app via an OS intent is **not Daftar making a network call** — the
  app itself opens no sockets and stores nothing remotely; connectivity is
  WhatsApp's concern. So this is **compatible with** ADR 0001, not a reversal of it.
  Using `wa.me` over https also **degrades gracefully to a browser** when WhatsApp
  isn't installed.
- **Pure helpers + injectable launch.** The message text and the phone
  normalisation live in pure, unit-tested functions; the actual launch sits behind
  an injectable callback (mirroring #10's `onSharePdf`) so tests never touch a
  platform channel. The message is written **from the owner to the Contact**, so
  its perspective mirrors the on-screen [[Balance]] labels (see CONTEXT.md —
  WhatsApp share); a settled lens produces a friendly no-amount note.
- **Minimal phone handling — no country-code inference.** Strip formatting and a
  leading `+`, pass the digits to `wa.me` as-is. Inferring a code from the lens
  currency (SAR→966, YER→967) was **rejected**: it silently guesses wrong for a
  contact whose country differs from the lens, and a wrong number is worse than a
  clearly-absent one. `tel:` uses the raw stored number and is unaffected. A
  local-only number may therefore not resolve on `wa.me` — mitigated later by an
  "enter international format" hint on the contact form.
- **Graceful absence.** The whole action strip is **hidden when the Contact has no
  phone.** The WhatsApp nudge needs **no Profile name** (the message says "me/I",
  not the creditor's name), so — unlike the PDF [[Statement]] — it triggers no
  name prompt.

## Consequences

- **Positive:** the marquee sharing feature ships without breaking the
  offline/local-only promise or adding a network stack, and its logic is pure and
  testable.
- **Negative:** `url_launcher` couples us to platform intents, and a contact stored
  with a local-format number gets a `wa.me` link that may fail (accepted,
  documented; the dialer still works).
- **Negative:** a future contributor might "helpfully" add country-code inference —
  this ADR records that the omission is **deliberate**.
