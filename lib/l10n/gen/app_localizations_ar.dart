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

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get undo => 'تراجع';

  @override
  String get editEntry => 'تعديل الحركة';

  @override
  String get editContact => 'تعديل جهة الاتصال';

  @override
  String get deleteEntryTitle => 'حذف الحركة؟';

  @override
  String get deleteEntryMessage => 'ستُحذف هذه الحركة وسيُعاد حساب الرصيد.';

  @override
  String get entryDeleted => 'تم حذف الحركة';

  @override
  String get deleteContactTitle => 'حذف جهة الاتصال؟';

  @override
  String deleteContactMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ستُحذف $count حركة أيضًا.',
      many: 'ستُحذف $count حركة أيضًا.',
      few: 'ستُحذف $count حركات أيضًا.',
      two: 'ستُحذف حركتان أيضًا.',
      one: 'ستُحذف حركة واحدة أيضًا.',
      zero: 'لا توجد حركات لهذه الجهة.',
    );
    return '$_temp0';
  }

  @override
  String get contactDeleted => 'تم حذف جهة الاتصال';

  @override
  String get searchEntriesHint => 'ابحث في الوصف';

  @override
  String get sortLabel => 'ترتيب';

  @override
  String get sortByDate => 'التاريخ';

  @override
  String get sortByValue => 'القيمة';

  @override
  String get sortByDescription => 'الوصف';

  @override
  String get searchContactsHint => 'ابحث بالاسم أو الهاتف';

  @override
  String get homeNoMatches => 'لا نتائج مطابقة';

  @override
  String get sortByActivity => 'الأحدث';

  @override
  String get sortByName => 'الاسم';

  @override
  String get sortByBalanceSize => 'الرصيد';

  @override
  String summaryTitle(String date) {
    return 'الملخّص حتى $date';
  }
}
