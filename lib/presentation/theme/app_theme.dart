import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';

/// The default brand accent — Teal. Baked into the launcher icon/splash and used
/// as the seed until the user picks another accent (ADR 0002). Slice 2 replaces
/// the literal call sites with the persisted `AccentTheme` choice.
const Color kDefaultAccentSeed = Color(0xFF14746F);

/// Bundled type families. The Arabic face renders for `ar` via the fallback.
const String _fontFamily = 'IBM Plex Sans';
const List<String> _fontFallback = ['IBM Plex Sans Arabic'];

/// Tabular figures keep money columns aligned across rows, the summary card and
/// the PDF — see [docs/design-system.md](../../../docs/design-system.md).
const List<FontFeature> _tabularFigures = [FontFeature.tabularFigures()];

/// Builds the app [ThemeData] for one [brightness] and accent [seed].
///
/// The [seed] drives the Material 3 chrome (`ColorScheme.fromSeed`) only; the
/// money semantics live in the fixed [AppSemanticColors] extension, so brand and
/// money signal never collide. Spacing/radius/semantic tokens are registered as
/// [ThemeExtension]s so widgets read them from the theme and they animate on a
/// theme switch.
ThemeData buildAppTheme({
  required Brightness brightness,
  Color seed = kDefaultAccentSeed,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
  );
  return base.copyWith(
    textTheme: _buildTextTheme(base.textTheme),
    extensions: [
      AppSpacing.standard,
      AppRadius.standard,
      AppSemanticColors.of(brightness),
    ],
  );
}

/// Applies the IBM Plex type scale (sizes + weights) and tabular figures on top
/// of the Material 3 defaults.
TextTheme _buildTextTheme(TextTheme base) {
  TextStyle role(TextStyle? s, double size, FontWeight weight) =>
      (s ?? const TextStyle()).copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontSize: size,
        fontWeight: weight,
        fontFeatures: _tabularFigures,
      );
  return base.copyWith(
    displaySmall: role(base.displaySmall, 36, FontWeight.w600),
    headlineSmall: role(base.headlineSmall, 24, FontWeight.w600),
    titleMedium: role(base.titleMedium, 16, FontWeight.w600),
    bodyMedium: role(base.bodyMedium, 14, FontWeight.w400),
    labelLarge: role(base.labelLarge, 14, FontWeight.w600),
    labelMedium: role(base.labelMedium, 12, FontWeight.w500),
  );
}
