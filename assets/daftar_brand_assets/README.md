# Daftar — Brand & Splash assets (Flutter drop-in)

Refined **dāl-forward** monogram (concept 2a): the mark *is* the Arabic **د** and
reads as an open Latin **D**. Flat white silhouette on Teal \`#14746F\`. No
gradients, no shadows — a single even stroke.

## What's here

    svg/                         Vector masters (edit these; regen PNGs from them)
      daftar_mark_white/teal/black.svg   the bare mark, transparent bg
      logo_icon.svg                       mark on the Teal rounded tile (full-bleed)
      logo_foreground.svg                 mark, transparent, adaptive safe-zone
      splash_logo.svg                     mark + دفتر / Daftar wordmark, white
      lockup_horizontal_latin/arabic.svg  wordmark lockups
    android/
      logo_icon.png            1024²  full-bleed teal tile (launcher / store)
      logo_foreground.png      1024²  transparent, Android adaptive foreground
      splash_mark_on_teal.png  1024²  static splash fallback
    monochrome/
      daftar_glyph_black/white/teal.png   1024²  single-colour, transparent
    flutter/
      daftar_mark.dart         reusable DaftarMark / DaftarIconTile + painter
      daftar_splash.dart       animated DaftarSplash (draw-on + دفتر reveal)
    flutter_launcher_icons.yaml
    flutter_native_splash.yaml
    pubspec_snippet.yaml

## Install (5 steps)

1. Copy \`android/*.png\`, \`monochrome/*.png\` and \`svg/splash_logo.svg\`→PNG into
   your app under \`assets/branding/\`. Copy \`flutter/*.dart\` into \`lib/branding/\`.
2. Add the IBM Plex Sans + IBM Plex Sans Arabic \`.ttf\` files to \`assets/fonts/\`
   (they're already bundled in your app under an OFL licence).
3. Merge \`pubspec_snippet.yaml\` into your \`pubspec.yaml\`, then \`flutter pub get\`.
4. Generate icons + native splash:
       dart run flutter_launcher_icons
       dart run flutter_native_splash:create
5. Show the animated splash on launch:

       import 'branding/daftar_splash.dart';
       // ...
       home: DaftarSplash(
         onDone: () => Navigator.of(context).pushReplacement(
           MaterialPageRoute(builder: (_) => const HomePage()),
         ),
       ),

## Colour rules (from the brief — keep these true)

- The **logo / icon / splash are always Teal \`#14746F\`**, even when the user
  picks another in-app accent (Indigo/Plum/Ocean). Don't theme the mark.
- Never colour the mark with a money colour (green/red/grey) — those mean
  *direction of debt*, not brand.
- Solid one-colour only. Use the monochrome glyphs for PDF headers & WhatsApp
  share where ink is limited.

## The mark, in code

Both Dart and SVG share one path (240×240 box):

    M66 74 H150 C192 74 204 132 170 155 C146 171 106 173 84 165 C70 160 71 145 87 143

stroke-width **28**, round cap + join. Scale by \`size/240\`.
