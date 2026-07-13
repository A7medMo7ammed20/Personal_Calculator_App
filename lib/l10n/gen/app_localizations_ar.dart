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
}
