import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:debt_ledger/presentation/theme/app_radius.dart';
import 'package:debt_ledger/presentation/theme/app_semantic_colors.dart';
import 'package:debt_ledger/presentation/theme/app_spacing.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_context.dart';

void main() {
  testWidgets('context getters read the registered token extensions', (
    tester,
  ) async {
    late AppSpacing spacing;
    late AppRadius radius;
    late AppSemanticColors semantics;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            spacing = context.spacing;
            radius = context.radius;
            semantics = context.semanticColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(spacing, AppSpacing.standard);
    expect(radius, AppRadius.standard);
    expect(semantics, AppSemanticColors.dark);
  });
}
