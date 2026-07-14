import 'package:debt_ledger/domain/balance.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/presentation/contact_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhoneForWa', () {
    test('strips spaces, dashes, parens and a leading plus, keeping digits', () {
      expect(normalizePhoneForWa('+966 50-123 (4567)'), '966501234567');
    });

    test('leaves a local number as digits only', () {
      expect(normalizePhoneForWa('055 123 4567'), '0551234567');
    });

    test('an empty or symbol-only string yields empty', () {
      expect(normalizePhoneForWa('  '), '');
      expect(normalizePhoneForWa('+-()'), '');
    });
  });

  group('buildWhatsAppMessage', () {
    String en(Balance b) => buildWhatsAppMessage(
          contactName: 'Khaled',
          balance: b,
          currency: Currency.sar,
          languageCode: 'en',
        );
    String ar(Balance b) => buildWhatsAppMessage(
          contactName: 'خالد',
          balance: b,
          currency: Currency.sar,
          languageCode: 'ar',
        );

    test('owed-to-me reads "you owe me" (EN, active-lens amount)', () {
      expect(en(const Balance(150)),
          'Hi Khaled, your balance with me: you owe me 150.00 ر.س');
    });

    test('owed-by-me reads "I owe you" (EN)', () {
      expect(en(const Balance(-75)),
          'Hi Khaled, your balance with me: I owe you 75.00 ر.س');
    });

    test('settled is a friendly no-amount note (EN)', () {
      expect(en(const Balance(0)), "Hi Khaled, we're all settled — thanks!");
    });

    test('owed-to-me in Arabic mirrors the balance perspective', () {
      expect(ar(const Balance(150)),
          'مرحباً خالد، رصيدك معي: عليك 150.00 ر.س');
    });

    test('owed-by-me in Arabic', () {
      expect(ar(const Balance(-75)), 'مرحباً خالد، رصيدك معي: لك 75.00 ر.س');
    });

    test('settled in Arabic', () {
      expect(ar(const Balance(0)), 'مرحباً خالد، رصيدنا صفر — شكراً لك!');
    });

    test('a non-ar language code falls back to the English template', () {
      expect(
        buildWhatsAppMessage(
          contactName: 'Khaled',
          balance: const Balance(150),
          currency: Currency.sar,
          languageCode: 'fr',
        ),
        'Hi Khaled, your balance with me: you owe me 150.00 ر.س',
      );
    });
  });
}
