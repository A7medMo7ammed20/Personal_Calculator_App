import '../domain/balance.dart';
import '../domain/currency.dart';
import 'money_format.dart';

/// Builds the pre-filled WhatsApp balance nudge (ADR 0008 · CONTEXT.md —
/// WhatsApp share). Authored **owner → Contact**, so the perspective mirrors
/// the on-screen balance labels: here "you" is the Contact.
///
/// - owed-to-me  → "you owe me {amount}"
/// - owed-by-me  → "I owe you {amount}"
/// - settled     → a friendly no-amount note
///
/// [amount] uses the active currency lens via [formatMoney]. Arabic is used
/// only for `languageCode == 'ar'`; every other code falls back to English.
/// Pure — no `BuildContext`, no launch.
String buildWhatsAppMessage({
  required String contactName,
  required Balance balance,
  required Currency currency,
  required String languageCode,
}) {
  final isArabic = languageCode == 'ar';
  if (balance.isSettled) {
    return isArabic
        ? 'مرحباً $contactName، رصيدنا صفر — شكراً لك!'
        : "Hi $contactName, we're all settled — thanks!";
  }
  final amount = formatMoney(balance.magnitude, currency);
  if (balance.isOwedToMe) {
    return isArabic
        ? 'مرحباً $contactName، رصيدك معي: عليك $amount'
        : 'Hi $contactName, your balance with me: you owe me $amount';
  }
  return isArabic
      ? 'مرحباً $contactName، رصيدك معي: لك $amount'
      : 'Hi $contactName, your balance with me: I owe you $amount';
}

/// Reduces a stored phone [raw] to the digits `wa.me` accepts: strips spaces,
/// dashes, parentheses and a leading `+`. **No country-code inference**
/// (ADR 0008) — a local-format number stays local and may not resolve on
/// WhatsApp; `tel:` uses the raw number instead.
String normalizePhoneForWa(String raw) => raw.replaceAll(RegExp(r'[^\d]'), '');
