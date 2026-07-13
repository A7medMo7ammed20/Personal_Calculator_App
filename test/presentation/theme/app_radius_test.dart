import 'package:flutter_test/flutter_test.dart';
import 'package:debt_ledger/presentation/theme/app_radius.dart';

void main() {
  group('AppRadius', () {
    test('soft-rounded values', () {
      const r = AppRadius.standard;
      expect(r.sm, 8);
      expect(r.md, 12);
      expect(r.lg, 20);
      expect(r.pill, 999);
    });

    test('lerp interpolates each token', () {
      const a = AppRadius.standard;
      final b = a.copyWith(md: 24);
      final mid = a.lerp(b, 0.5);
      expect(mid.md, 18); // (12 + 24) / 2
      expect(mid.sm, a.sm);
    });

    test('lerp at t=0 returns this', () {
      const a = AppRadius.standard;
      final b = a.copyWith(md: 99);
      expect(a.lerp(b, 0).md, a.md);
    });
  });
}
