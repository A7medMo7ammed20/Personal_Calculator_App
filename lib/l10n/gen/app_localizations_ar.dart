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
  String get addEntry => 'إضافة معاملة';

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
  String get contactEntriesEmpty => 'لا توجد معاملات بعد';

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
  String get editEntry => 'تعديل المعاملة';

  @override
  String get editContact => 'تعديل جهة الاتصال';

  @override
  String get deleteEntryTitle => 'حذف المعاملة؟';

  @override
  String get deleteEntryMessage => 'ستُحذف هذه المعاملة وسيُعاد حساب الرصيد.';

  @override
  String get entryDeleted => 'تم حذف المعاملة';

  @override
  String get deleteContactTitle => 'حذف جهة الاتصال؟';

  @override
  String deleteContactMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ستُحذف $count معاملة أيضًا.',
      many: 'ستُحذف $count معاملة أيضًا.',
      few: 'ستُحذف $count معاملات أيضًا.',
      two: 'ستُحذف معاملتان أيضًا.',
      one: 'ستُحذف معاملة واحدة أيضًا.',
      zero: 'لا توجد معاملات لهذه الجهة.',
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
  String get periodLabel => 'الفترة';

  @override
  String get periodAllTime => 'كل الوقت';

  @override
  String get periodThisMonth => 'هذا الشهر';

  @override
  String get periodLastMonth => 'الشهر الماضي';

  @override
  String get periodThisYear => 'هذه السنة';

  @override
  String get periodCustom => 'مخصص';

  @override
  String get flowLent => 'المدفوع';

  @override
  String get flowReceived => 'المقبوض';

  @override
  String get homeNoActivityInPeriod => 'لا نشاط في هذه الفترة';

  @override
  String summaryTitle(String date) {
    return 'الملخّص حتى $date';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAccent => 'لون التمييز';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get accentTeal => 'أزرق مخضر';

  @override
  String get accentIndigo => 'نيلي';

  @override
  String get accentPlum => 'برقوقي';

  @override
  String get accentOcean => 'أزرق محيطي';

  @override
  String get analysisTitle => 'التحليل';

  @override
  String analysisEmpty(String currency) {
    return 'لا يوجد نشاط بعملة $currency بعد';
  }

  @override
  String breakdownTitle(String interval) {
    return 'التغيّرات · $interval';
  }

  @override
  String get breakdownEmpty => 'لا معاملات في هذه الفترة';

  @override
  String get chartOverTime => 'على مدى الوقت';

  @override
  String get chartByContact => 'حسب جهة الاتصال';

  @override
  String get settingsProfile => 'ملفك';

  @override
  String get profileName => 'اسمك';

  @override
  String get profilePhone => 'هاتفك (اختياري)';

  @override
  String get profileNamePromptTitle => 'أضف اسمك';

  @override
  String get profileNamePromptMessage => 'يظهر اسمك كمُصدِر على الكشف.';

  @override
  String get exportStatement => 'تصدير كشف حساب';

  @override
  String get statementTitle => 'كشف حساب';

  @override
  String get statementFrom => 'من';

  @override
  String get statementTo => 'إلى';

  @override
  String get statementDateColumn => 'التاريخ';

  @override
  String get statementDescriptionColumn => 'الوصف';

  @override
  String get statementBalanceColumn => 'الرصيد';

  @override
  String get statementOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get statementClosingBalance => 'الرصيد الختامي';

  @override
  String get statementTotal => 'الإجمالي';

  @override
  String get settingsPreferences => 'التفضيلات';

  @override
  String get settingsDefaultCurrency => 'العملة الافتراضية';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get languageSystem => 'حسب النظام';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get whatsappShare => 'واتساب';

  @override
  String get callContact => 'اتصال';
}
