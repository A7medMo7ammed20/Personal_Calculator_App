import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:debt_ledger/presentation/theme/app_semantic_colors.dart';

void main() {
  group('AppSemanticColors', () {
    test('light values match the design system', () {
      const c = AppSemanticColors.light;
      expect(c.owedToMe, const Color(0xFF2E7D5B));
      expect(c.owedByMe, const Color(0xFFC0392B));
      expect(c.settled, const Color(0xFF6B7280));
    });

    test('dark values match the design system', () {
      const c = AppSemanticColors.dark;
      expect(c.owedToMe, const Color(0xFF43D9A3));
      expect(c.owedByMe, const Color(0xFFF87171));
      expect(c.settled, const Color(0xFF9CA3AF));
    });

    test('lerp at t=0 returns this, at t=1 returns other', () {
      final a = AppSemanticColors.light;
      final b = AppSemanticColors.dark;
      expect(a.lerp(b, 0).owedToMe, a.owedToMe);
      expect(a.lerp(b, 0).owedByMe, a.owedByMe);
      expect(a.lerp(b, 1).owedToMe, b.owedToMe);
      expect(a.lerp(b, 1).settled, b.settled);
    });

    test('lerp interpolates between the two ends', () {
      final mid = AppSemanticColors.light.lerp(AppSemanticColors.dark, 0.5);
      expect(mid.owedToMe, Color.lerp(const Color(0xFF2E7D5B), const Color(0xFF43D9A3), 0.5));
    });

    test('copyWith overrides only the named field', () {
      final c = AppSemanticColors.light.copyWith(settled: const Color(0xFF000000));
      expect(c.settled, const Color(0xFF000000));
      expect(c.owedToMe, AppSemanticColors.light.owedToMe);
    });
  });
}
