import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:debt_ledger/presentation/theme/app_radius.dart';
import 'package:debt_ledger/presentation/theme/app_semantic_colors.dart';
import 'package:debt_ledger/presentation/theme/app_spacing.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';

void main() {
  group('buildAppTheme', () {
    test('registers the three token extensions', () {
      final theme = buildAppTheme(brightness: Brightness.light);
      expect(theme.extension<AppSpacing>(), AppSpacing.standard);
      expect(theme.extension<AppRadius>(), AppRadius.standard);
      expect(theme.extension<AppSemanticColors>(), AppSemanticColors.light);
    });

    test('dark theme carries the dark semantics and brightness', () {
      final theme = buildAppTheme(brightness: Brightness.dark);
      expect(theme.extension<AppSemanticColors>(), AppSemanticColors.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('chrome is seeded by the accent, not the money green', () {
      final theme = buildAppTheme(brightness: Brightness.light);
      // The primary must derive from the teal accent, never equal the fixed
      // owed-to-me green — brand and money signal stay separate (ADR 0002).
      expect(theme.colorScheme.primary, isNot(AppSemanticColors.light.owedToMe));
    });

    test('accent overrides the seed', () {
      final teal = buildAppTheme(brightness: Brightness.light);
      final plum = buildAppTheme(
        brightness: Brightness.light,
        seed: const Color(0xFF6D28D9),
      );
      expect(plum.colorScheme.primary, isNot(teal.colorScheme.primary));
    });

    test('money figures are tabular so columns align', () {
      final theme = buildAppTheme(brightness: Brightness.light);
      final style = theme.textTheme.titleMedium!;
      expect(
        style.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('type scale sizes and weights follow the design system', () {
      final t = buildAppTheme(brightness: Brightness.light).textTheme;
      expect(t.displaySmall!.fontSize, 36);
      expect(t.displaySmall!.fontWeight, FontWeight.w600);
      expect(t.headlineSmall!.fontSize, 24);
      expect(t.titleMedium!.fontSize, 16);
      expect(t.bodyMedium!.fontSize, 14);
      expect(t.bodyMedium!.fontWeight, FontWeight.w400);
      expect(t.labelLarge!.fontSize, 14);
      expect(t.labelLarge!.fontWeight, FontWeight.w600);
      expect(t.labelMedium!.fontSize, 12);
      expect(t.labelMedium!.fontWeight, FontWeight.w500);
    });
  });
}
