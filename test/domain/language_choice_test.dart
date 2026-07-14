import 'package:debt_ledger/domain/language_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguageChoice', () {
    test('codes round-trip through fromCode', () {
      for (final choice in LanguageChoice.values) {
        expect(LanguageChoice.fromCode(choice.code), choice);
      }
    });

    test('system is the default', () {
      expect(LanguageChoice.defaultChoice, LanguageChoice.system);
    });

    test('fromCode falls back to the default for an unknown or null code', () {
      expect(LanguageChoice.fromCode('fr'), LanguageChoice.system);
      expect(LanguageChoice.fromCode(null), LanguageChoice.system);
    });

    test('the arabic/english codes are the locale language codes', () {
      expect(LanguageChoice.arabic.code, 'ar');
      expect(LanguageChoice.english.code, 'en');
    });
  });
}
