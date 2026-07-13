# Daftar — Brand Concept & Logo Brief

*A concept package for the logo designer. It states what Daftar is, the name, the
colour and type system already in the product, and — the main ask — an improved,
directed idea for the logomark to design against.*

For the concrete engineering tokens (exact spacing, radii, generated assets), see
[design-system.md](design-system.md). This document is the **why and the creative
direction**; that one is the lookup table.

> **Status — delivered.** This brief was answered by the **dāl-forward monogram
> (concept 2a):** one continuous stroke that reads as the Arabic **د** and an open
> Latin **D**. The final mark now lives as a vector path in
> `lib/branding/daftar_mark.dart` (and the SVG masters + kit in
> `assets/daftar_brand_assets/`), with raster exports in `assets/branding/`. The
> sections below are kept as the original creative direction. The earlier
> `tool/make_logo.py` first-pass generator has been removed.

---

## 1. The product in one breath

**Daftar** (Arabic: دفتر — "ledger / notebook") is a **personal debt ledger** for
Android. You track money owed **to you** and **by you**, organised **per person**,
in Saudi Riyal (SAR) and Yemeni Riyal (YER), and export per-person PDF statements.

Key truths that should shape the brand:

- **People-first, not category-first.** The hero object is a *person*, and every
  line is a debt in one direction. This is emphatically **not** a colourful
  expense-tracker with pie charts. It is closer to a **trusted paper notebook**
  made digital.
- **Bilingual, Arabic-first in spirit.** One wordmark serves both scripts. Arabic
  and English are equal citizens; the app runs right-to-left in Arabic.
- **Local-only and private.** No cloud, no login, no ads. Your ledger lives on
  your device. The brand should feel **calm, discreet, and trustworthy**, not
  fintech-loud.
- **Money is serious but personal.** The users are individuals settling debts with
  family, friends, shopkeepers — not corporate accountants. Warm, not sterile.

**Brand personality:** *calm · trustworthy · precise · warm · unshowy.*
Think "a well-kept personal ledger" — orderly and quietly confident. Avoid
crypto/neon fintech, avoid playful cartoon money, avoid corporate-bank coldness.

**Descriptor line (for stores / context):** *Personal Debt Ledger · دفتر الديون.*

---

## 2. The name

- **Wordmark:** **Daftar · دفتر** — one name, presented in both scripts. "Daftar"
  is the Latin transliteration of the Arabic دفتر.
- **Meaning:** "ledger / notebook" — it *is* the product, in one word, in the
  users' own language. It carries the paper-notebook heritage we want to evoke.
- **Usage:** Latin "Daftar" and Arabic "دفتر" are peers. In Arabic contexts lead
  with دفتر; in English contexts lead with Daftar. Never translate the name to
  "Ledger" — Daftar *is* the name.
- **Tone of the wordmark:** set in the brand type (IBM Plex, below), SemiBold.
  The wordmark should feel like a **confident label on the cover of a notebook**,
  not a tech logotype.

---

## 3. Colour system (already shipped — please design within it)

> **Golden rule the brand must respect:** the **accent** themes the app chrome;
> the **semantic money colours** (green/red/grey) are **fixed** and mean
> *direction of debt*. Never colour an amount with the accent; never use
> green/red as brand chrome. The logo lives in the **accent/Teal** world, never
> the money-colour world.

### Primary brand colour — Teal

| Token | Hex | Role |
|---|---|---|
| **Teal (brand)** | `#14746F` | The brand colour. **Baked into the app icon & splash.** The logomark is **white on this Teal.** |

Teal was chosen to feel **trustworthy and calm** (not bank-blue, not money-green).
It is the default of four user-switchable *accents* — but the **logo, icon and
splash are always Teal**, regardless of the accent a user picks in-app.

### Other accents (user-switchable app chrome only — not for the logo)

| Accent | Hex |
|---|---|
| Indigo | `#3538CD` |
| Plum | `#6D28D9` |
| Ocean Blue | `#0369A1` |

The designer only needs Teal + white for the mark. The accents are listed so it's
clear the mark must **not** depend on any specific accent and must read as
"Daftar" even when the rest of the UI is Indigo/Plum/Ocean.

### Semantic money colours (context only — do not use in the logo)

| Role | Light | Dark |
|---|---|---|
| Owed to me (positive) | `#2E7D5B` | `#43D9A3` |
| Owed by me (negative) | `#C0392B` | `#F87171` |
| Settled (zero) | `#6B7280` | `#9CA3AF` |

### Logo colour rules

- **On-brand primary:** white (`#FFFFFF`) mark on the Teal `#14746F` tile.
- **Must also work as:** solid one-colour (Teal on white, white on Teal, and
  pure black / pure white monochrome) for stamps, invoices, and low-ink contexts.
- **No gradients, no drop shadows.** The product is flat Material-3 tonal design.
  The mark should be a **clean solid silhouette**.

---

## 4. Typography (fixed — for the wordmark)

- **Latin:** **IBM Plex Sans**
- **Arabic:** **IBM Plex Sans Arabic**

Both are bundled in the app (`assets/fonts/`, OFL licence). IBM Plex is
**geometric but humanist** — engineered and precise, yet warm. The custom
logomark should feel like it **belongs to the same family**: geometric spine,
subtle warmth, single even stroke weight, no ornament. Wordmark weight: **SemiBold
(600)**. If the mark uses letterforms, they should rhyme with Plex's proportions
(open counters, slightly squared curves) without being literally the font.

---

## 5. The logomark — the main ask

### The idea in one line

> **A single, dual-script monogram that a Latin reader sees as "D" and an Arabic
> reader sees as "د" (dāl) — one continuous mark, white on Teal, that also nods to
> a bound ledger/notebook.**

Both "Daftar" and "دفتر" begin with the same sound and the same conceptual letter
(D / د). A mark that *is both letters at once* is the perfect emblem for a
**bilingual, one-wordmark** product.

### What we tried, and what we learned (start above this bar)

We built a **first-pass** placeholder (see `assets/branding/logo_icon.png`) by
literally overlapping the Plex "D" glyph and the Plex Arabic "د" glyph so their
white silhouettes merge:

- ✅ It reads, it's on-brand in colour, and it proves the D/د concept has legs.
- ⚠️ **But it's an *overlap*, not a *fusion*.** The Latin "D" dominates and the
  "د" reads as a small tail hanging off it — two glyphs side by side, not one
  unified idea. It's a functional placeholder, not a crafted mark.

**Your job is to make it a true, single, intentional mark** — better than a
glyph overlap. Please treat the first pass only as proof-of-concept.

### Creative routes (pick/blend — we're open)

1. **Dual-script ambigram monogram (preferred).** Design one continuous stroke
   where the **bowl of the D and the curve of the dāl (د) are the same arc**. A
   Latin reader resolves it to "D"; an Arabic reader resolves it to "د". This is
   the most distinctive, most "Daftar" route.
2. **Ledger / notebook abstraction.** Evoke the object: a bound notebook spine, a
   folded page corner, a stitched ledger, or two facing pages (which also echoes
   the app's two directions — *owed to me* / *owed by me*, and two currencies).
   Optionally form the D/د *out of* this motif.
3. **Combine 1 + 2.** A D/د whose stroke doubles as a notebook spine or a folded
   page — meaning *and* letter in one shape. Ideal if it stays simple.

### Non-negotiable constraints (this is an app icon first)

- **Single flat colour** (white on Teal). Must survive as a one-colour silhouette.
- **Legible at 24 px** (it appears as a small in-app / status mark) *and* strong at
  512 px.
- **Fits the Android adaptive-icon safe zone:** the meaningful mark must sit
  within the **centre ~66%** of the icon square — corners get masked to
  circle/squircle/rounded-square by the OS. Give it breathing room; don't run it
  to the edges.
- **Balanced optical weight**, roughly centred, comfortable on a square Teal tile
  with generous padding.
- **Works in RTL and LTR contexts** without looking "backwards" to either
  audience. (An Arabic user should not read the mark as a broken/mirrored letter.)
- **No fine detail, no thin hairlines, no gradients/shadows** — they die at small
  sizes and clash with the flat UI.
- **Distinct from generic "D" app icons** (Docs, Dropbox, Disney+, etc.). The
  Arabic-letter reading is our differentiation — lean into it.

### Do / Don't

| Do | Don't |
|---|---|
| One unified, continuous mark | Two glyphs merely overlapped |
| Even, confident single stroke weight | Thin/variable strokes that vanish small |
| Warm, geometric, Plex-adjacent | Ornate calligraphic flourishes |
| Solid white on Teal | Gradients, bevels, drop shadows |
| Meaningful (letter and/or ledger) | Generic abstract swoosh |
| Safe-zone aware, padded | Edge-to-edge, corner-crowding |

---

## 6. Deliverables we need from you

**Formats**

- **Master:** vector **SVG** (and layered source — AI/Figma) of the final mark.
- **Colourways:** white-on-Teal, Teal-on-white, solid black, solid white.
- **Wordmark lockups:** (a) mark + "Daftar" (Latin), (b) mark + "دفتر" (Arabic),
  (c) stacked mark-over-wordmark for the splash. Provide horizontal and stacked.

**App-specific exports** (we generate density variants from these — just need the
masters at 1024×1024 unless noted):

1. **`logo_icon`** — mark centred on the Teal `#14746F` rounded-square tile
   (full-bleed icon, for iOS/web/legacy Android).
2. **`logo_foreground`** — mark on **transparent** background, sized for the
   **adaptive-icon foreground** (mark ~mid of canvas; the build adds its own
   inset — we can tune sizing, just keep it centred with padding).
3. **`splash_logo`** — mark **above** the *Daftar · دفتر* wordmark, white on
   transparent, for the native splash (rendered over a Teal field).
4. **Monochrome glyph** — the bare mark, single colour, for PDF statement
   headers and the WhatsApp share.

**Also nice:** a one-page usage sheet (clear space, min size, colourways,
misuse examples).

**Final mark files** live in `assets/branding/` (raster exports) and
`assets/daftar_brand_assets/` (SVG masters + the delivered kit); the in-app vector
source is `lib/branding/daftar_mark.dart`.

---

## 7. Where the mark shows up (so you design for real contexts)

- **Launcher icon** — adaptive, masked to the device's shape. Most important
  surface; must be instantly recognisable at home-screen size.
- **Splash screen** — mark + wordmark on a full Teal field, on cold launch.
- **In-app** — small brand presence; app chrome may be Teal *or* another accent,
  so the mark itself stays Teal/white and must not clash.
- **PDF statement header & WhatsApp share** — often monochrome / low-ink.
- **Store listing** — next to competitors; the D/د distinctiveness earns its keep.

---

## 8. Quick reference card (hand this line to the designer)

> **Daftar (دفتر)** — a calm, private, people-first personal *debt ledger*.
> Design a **single dual-script monogram** that reads **D** to Latin eyes and
> **د** to Arabic eyes (optionally evoking a bound ledger/notebook), as a **flat
> white silhouette on Teal `#14746F`**, in the spirit of **IBM Plex** —
> geometric, warm, unornamented. Must work as an Android adaptive icon (centre
> ~66% safe zone), legible at 24 px, and in solid monochrome. Personality: calm,
> trustworthy, precise, warm, unshowy. Not fintech-neon, not cartoon-money, not a
> generic "D".
