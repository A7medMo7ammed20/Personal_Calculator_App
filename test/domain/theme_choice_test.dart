import 'package:debt_ledger/domain/theme_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeChoice', () {
    test('codes round-trip through fromCode', () {
      for (final choice in ThemeChoice.values) {
        expect(ThemeChoice.fromCode(choice.code), choice);
      }
    });

    test('system is the default', () {
      expect(ThemeChoice.defaultChoice, ThemeChoice.system);
    });

    test('fromCode falls back to the default for an unknown or null code', () {
      expect(ThemeChoice.fromCode('sepia'), ThemeChoice.system);
      expect(ThemeChoice.fromCode(null), ThemeChoice.system);
    });
  });
}
