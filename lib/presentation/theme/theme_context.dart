import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';

/// Terse reads for the design-system tokens: `context.spacing.lg`,
/// `context.radius.md`, `context.semanticColors.owedToMe`. Each token set is a
/// [ThemeExtension] registered by `buildAppTheme`; the getters fall back to the
/// standard scale (and brightness-appropriate semantics) if a bare theme forgot
/// to register them, so a token read never crashes.
extension DesignTokens on BuildContext {
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? AppSpacing.standard;

  AppRadius get radius =>
      Theme.of(this).extension<AppRadius>() ?? AppRadius.standard;

  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      AppSemanticColors.of(Theme.of(this).brightness);
}
