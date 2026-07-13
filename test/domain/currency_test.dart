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
}
