// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'دفتر الديون';

  @override
  String get homeEmpty => 'لا توجد جهات اتصال بعد';

  @override
  String get addContact => 'إضافة جهة اتصال';

  @override
  String get contactName => 'الاسم';

  @override
  String get contactPhone => 'الهاتف (اختياري)';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get save => 'حفظ';

  @override
  String get addEntry => 'إضافة حركة';

  @override
  String get entryAmount => 'المبلغ';

  @override
  String get amountRequired => 'أدخل المبلغ';

  @override
  String get amountInvalid => 'أدخل مبلغًا أكبر من صفر';

  @override
  String get directionOwedToMe => 'لك';

  @override
  String get directionOwedByMe => 'عليك';

  @override
  String get entryDescription => 'الوصف (اختياري)';

  @override
  String get entryDateTime => 'التاريخ والوقت';

  @override
  String get contactEntriesEmpty => 'لا توجد حركات بعد';

  @override
  String balanceOwedToMe(String amount) {
    return 'لك $amount';
  }

  @override
  String balanceOwedByMe(String amount) {
    return 'عليك $amount';
  }

  @override
  String get balanceSettled => 'مسدَّد';

  @override
  String get homeTotalOwedToMe => 'لك';

  @override
  String get homeTotalOwedByMe => 'عليك';
}
