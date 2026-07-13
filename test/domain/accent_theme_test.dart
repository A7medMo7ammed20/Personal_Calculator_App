import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccentTheme', () {
    test('codes round-trip through fromCode', () {
      for (final accent in AccentTheme.values) {
        expect(AccentTheme.fromCode(accent.code), accent);
      }
    });

    test('seed values match the design system', () {
      expect(AccentTheme.teal.seedValue, 0xFF14746F);
      expect(AccentTheme.indigo.seedValue, 0xFF3538CD);
      expect(AccentTheme.plum.seedValue, 0xFF6D28D9);
      expect(AccentTheme.ocean.seedValue, 0xFF0369A1);
    });

    test('teal is the default', () {
      expect(AccentTheme.defaultAccent, AccentTheme.teal);
    });

    test('fromCode falls back to the default for an unknown code', () {
      expect(AccentTheme.fromCode('chartreuse'), AccentTheme.teal);
      expect(AccentTheme.fromCode(null), AccentTheme.teal);
    });
  });
}
