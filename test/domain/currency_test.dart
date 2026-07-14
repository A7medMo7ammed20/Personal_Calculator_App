import 'package:debt_ledger/domain/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Currency', () {
    test('codes and symbols are the SAR/YER pair from CONTEXT.md', () {
      expect(Currency.sar.code, 'SAR');
      expect(Currency.sar.symbol, 'ر.س');
      expect(Currency.yer.code, 'YER');
      expect(Currency.yer.symbol, 'ر.ي');
    });

    test('fromCode round-trips every value', () {
      for (final currency in Currency.values) {
        expect(Currency.fromCode(currency.code), currency);
      }
    });

    test('fromCode rejects an unknown code', () {
      expect(() => Currency.fromCode('USD'), throwsArgumentError);
    });
  });

  group('safe default parse', () {
    test('defaultCurrency is SAR', () {
      expect(Currency.defaultCurrency, Currency.sar);
    });

    test('fromCodeOrDefault round-trips known codes', () {
      expect(Currency.fromCodeOrDefault('SAR'), Currency.sar);
      expect(Currency.fromCodeOrDefault('YER'), Currency.yer);
    });

    test('fromCodeOrDefault degrades to SAR on unknown or null', () {
      expect(Currency.fromCodeOrDefault('USD'), Currency.sar);
      expect(Currency.fromCodeOrDefault(null), Currency.sar);
    });

    test('fromCode still throws on unknown (unchanged)', () {
      expect(() => Currency.fromCode('USD'), throwsArgumentError);
    });
  });
}
