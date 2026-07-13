# Daftar — Design System Tokens

Concrete values to implement against. The *reasoning* behind this system lives in
[ADR 0002](adr/0002-design-system-and-switchable-accent-themes.md); the home-screen IA in
[ADR 0003](adr/0003-bottom-tab-currency-lens.md). This file is a lookup, not a rationale.

> **Golden rule:** the **accent** themes the chrome; the **semantic** money colours are
> fixed. Never style an amount with the accent, and never chrome the app with green/red.

## Brand

- **Name / wordmark:** Daftar · دفتر (one wordmark, both scripts)
- **Logomark:** fused **D / د** monogram, white on the default-accent tile
- **App icon & splash:** solid **Teal** rounded square, white mark; splash adds the
  wordmark below. Baked at build time — does **not** follow the user's chosen accent.

## Colour

### Accent seeds (user-switchable; drive `ColorScheme.fromSeed` chrome only)

| Accent | Seed | Notes |
|---|---|---|
| **Teal** (default) | `#14746F` | Baked into the launcher icon & splash |
| Indigo | `#3538CD` | |
| Plum | `#6D28D9` | |
| Ocean Blue | `#0369A1` | |

Each accent × brightness = `ColorScheme.fromSeed(seedColor: <seed>, brightness: <b>)`.
Do not hand-pick primary/secondary/surface — let Material 3 derive the tonal palette.

### Semantic money colours (FIXED across every accent; `AppSemanticColors` extension)

| Role | Light | Dark | Use |
|---|---|---|---|
| Owed to me | `#2E7D5B` | `#43D9A3` | positive amounts, ↑ |
| Owed by me | `#C0392B` | `#F87171` | negative amounts, ↓ |
| Settled | `#6B7280` | `#9CA3AF` | zero balance, neutral |

Dark variants are brightened so text stays legible on dark surfaces. Verify red/green
remain distinguishable for colour-blind users (pair colour with the ↑/↓ icon and sign,
never colour alone).

## Spacing — 8pt rhythm (`AppSpacing` extension)

| Token | px |
|---|---|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |
| `xxl` | 32 |
| `xxxl` | 48 |

## Radius (`AppRadius` extension) — "soft rounded"

| Token | px | Applied to |
|---|---|---|
| `sm` | 8 | small controls |
| `md` | 12 | cards, buttons, inputs |
| `lg` | 20 | summary card, bottom sheets |
| `pill` | 999 | chips, segmented/tab indicator |
| avatar | — | full circle |

## Elevation

Flat, Material 3 tonal surfaces. `0` = page, `1` = summary card / rows-on-scroll,
`2` = menus / bottom sheets. Prefer surface tint over drop shadows.

## Iconography & targets

- Inline icon `18` · default icon `24`
- Minimum touch target `48 × 48`

## Typography — IBM Plex Sans + IBM Plex Sans Arabic

Bundle both families; the Arabic face renders for `ar`. Enable **tabular figures**
(`fontFeatures: [FontFeature.tabularFigures()]`) everywhere money is shown so columns
align (rows, summary card, running summary, PDF).

| Role (Material 3) | Size / weight | Use |
|---|---|---|
| `displaySmall` | 36 / SemiBold | hero amounts in the summary card |
| `headlineSmall` | 24 / SemiBold | screen & section titles |
| `titleMedium` | 16 / SemiBold | contact name (row primary) |
| `bodyMedium` | 14 / Regular | secondary text, descriptions |
| `labelLarge` | 14 / SemiBold | buttons, tab labels |
| `labelMedium` | 12 / Medium | chips, captions, period label |

Weights: Regular 400 · Medium 500 · SemiBold 600 · Bold 700.

## Density

**Comfortable.** Contact rows ~64px, single line: circular avatar · name · colored
signed balance. **Phone number is not shown in-app** — it is used only in PDF statements
and WhatsApp share.

## Home layout (see ADR 0003)

```
app bar:  Daftar                              ⋮   (Settings, Backup)
          ╭── summary card ──────────────────────╮
          │ ↑ Owed to you 2,000  ↓ You owe 750  │  (or Flow when period bounded)
          ╰──────────────────────────────────────╯
toolbar:  [All ▾]   🔍 Search…              ⇅
list:     ●  Ahmed          +500 ر.س   (comfortable, single line)
                                          [＋] FAB
bottom:   ●━━━━━━  ر.س SAR      ر.ي YER  ○   (swipeable, animated indicator)
```
