import 'package:flutter_test/flutter_test.dart';
import 'package:debt_ledger/presentation/theme/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('standard 8pt rhythm values', () {
      const s = AppSpacing.standard;
      expect(s.xs, 4);
      expect(s.sm, 8);
      expect(s.md, 12);
      expect(s.lg, 16);
      expect(s.xl, 24);
      expect(s.xxl, 32);
      expect(s.xxxl, 48);
    });

    test('lerp interpolates each token', () {
      const a = AppSpacing.standard;
      final b = a.copyWith(lg: 32);
      final mid = a.lerp(b, 0.5);
      expect(mid.lg, 24); // (16 + 32) / 2
      expect(mid.xs, a.xs); // unchanged token stays put
    });

    test('lerp at t=0 returns this', () {
      const a = AppSpacing.standard;
      final b = a.copyWith(lg: 99);
      expect(a.lerp(b, 0).lg, a.lg);
    });
  });
}
