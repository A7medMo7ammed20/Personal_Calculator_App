import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The application title shown on the home screen and task switcher.
  ///
  /// In en, this message translates to:
  /// **'Debt Ledger'**
  String get appTitle;

  /// Placeholder shown on the home screen when there are no contacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get homeEmpty;

  /// Title/label for the add-contact action and screen.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// Label for the contact name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactName;

  /// Label for the optional contact phone field.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get contactPhone;

  /// Validation message shown when the name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// Label for the save button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Title/label for the add-entry action and screen.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get addEntry;

  /// Label for the entry amount field.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get entryAmount;

  /// Validation message when the amount field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get amountRequired;

  /// Validation message when the amount is not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero'**
  String get amountInvalid;

  /// Direction toggle option: the contact owes the user (green).
  ///
  /// In en, this message translates to:
  /// **'Owed to me'**
  String get directionOwedToMe;

  /// Direction toggle option: the user owes the contact (red).
  ///
  /// In en, this message translates to:
  /// **'Owed by me'**
  String get directionOwedByMe;

  /// Label for the optional entry description field.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get entryDescription;

  /// Label for the entry date/time picker.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get entryDateTime;

  /// Placeholder on the contact page when it has no entries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get contactEntriesEmpty;

  /// Balance label when the contact owes the user (green).
  ///
  /// In en, this message translates to:
  /// **'owes you {amount}'**
  String balanceOwedToMe(String amount);

  /// Balance label when the user owes the contact (red).
  ///
  /// In en, this message translates to:
  /// **'you owe {amount}'**
  String balanceOwedByMe(String amount);

  /// Balance label when nothing is outstanding in either direction.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get balanceSettled;

  /// Home header label for the per-currency total owed to the user.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get homeTotalOwedToMe;

  /// Home header label for the per-currency total the user owes.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get homeTotalOwedByMe;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
