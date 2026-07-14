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

  /// Generic edit action label (swipe reveal, form title prefix).
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Generic delete action label (swipe reveal).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Dismiss a dialog without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// SnackBar action that reverses a delete.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Title of the entry form when editing an existing entry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntry;

  /// Title of the contact form when editing an existing contact.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get editContact;

  /// Confirmation dialog title before deleting an entry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get deleteEntryTitle;

  /// Confirmation dialog body before deleting an entry.
  ///
  /// In en, this message translates to:
  /// **'This entry will be removed and the balance recomputed.'**
  String get deleteEntryMessage;

  /// SnackBar shown after an entry is deleted, alongside Undo.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted'**
  String get entryDeleted;

  /// Confirmation dialog title before deleting a contact.
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get deleteContactTitle;

  /// Confirmation body stating how many entries cascade-delete with the contact.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This contact has no entries.} =1{1 entry will also be deleted.} other{{count} entries will also be deleted.}}'**
  String deleteContactMessage(int count);

  /// SnackBar shown after a contact is deleted, alongside Undo.
  ///
  /// In en, this message translates to:
  /// **'Contact deleted'**
  String get contactDeleted;

  /// Hint text in the per-contact entry search field.
  ///
  /// In en, this message translates to:
  /// **'Search description'**
  String get searchEntriesHint;

  /// Label for the entry sort control.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// Sort entries by date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sortByDate;

  /// Sort entries by signed value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get sortByValue;

  /// Sort entries by description text.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get sortByDescription;

  /// Hint text in the home contact search field (#6).
  ///
  /// In en, this message translates to:
  /// **'Search name or phone'**
  String get searchContactsHint;

  /// Shown on home when the search matches no contacts.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get homeNoMatches;

  /// Sort contacts by most recent activity (default).
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get sortByActivity;

  /// Sort contacts by name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// Sort contacts by balance magnitude.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get sortByBalanceSize;

  /// Label/tooltip for the home period filter (#7).
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodLabel;

  /// Period option: no time filter (default).
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get periodAllTime;

  /// Period option: the current calendar month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get periodThisMonth;

  /// Period option: the previous calendar month.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get periodLastMonth;

  /// Period option: the current calendar year.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get periodThisYear;

  /// Period option: a user-picked date range.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// Home flow-header label: total lent in the window (owed-to-me).
  ///
  /// In en, this message translates to:
  /// **'Lent'**
  String get flowLent;

  /// Home flow-header label: total received in the window (owed-by-me).
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get flowReceived;

  /// Shown on home when no contact has activity in the selected period.
  ///
  /// In en, this message translates to:
  /// **'No activity in this period'**
  String get homeNoActivityInPeriod;

  /// Title of the running-summary bottom sheet, showing the tapped entry's date.
  ///
  /// In en, this message translates to:
  /// **'Summary up to {date}'**
  String summaryTitle(String date);

  /// Title of the Settings screen (reached from the home overflow menu).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section header for the brand accent picker.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccent;

  /// Settings section header for the light/dark brightness picker.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Brightness option: follow the OS setting (default).
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Brightness option: always light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Brightness option: always dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Name of the Teal accent (default).
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// Name of the Indigo accent.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// Name of the Plum accent.
  ///
  /// In en, this message translates to:
  /// **'Plum'**
  String get accentPlum;

  /// Name of the Ocean Blue accent.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get accentOcean;

  /// Title of the Analysis graph screen (reached from the home overflow menu) (#8).
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysisTitle;

  /// Shown on the Analysis graph when the active currency lens has no entries at all.
  ///
  /// In en, this message translates to:
  /// **'No {currency} activity yet'**
  String analysisEmpty(String currency);

  /// Header of the drill-down sheet: which interval's per-contact changes are shown (#8).
  ///
  /// In en, this message translates to:
  /// **'Changes · {interval}'**
  String breakdownTitle(String interval);

  /// Shown in the drill-down sheet when the tapped interval is a flat, carried-forward gap with no entries.
  ///
  /// In en, this message translates to:
  /// **'No entries in this interval'**
  String get breakdownEmpty;

  /// Analysis chart-type toggle: the cumulative net-balance line over time (#8).
  ///
  /// In en, this message translates to:
  /// **'Over time'**
  String get chartOverTime;

  /// Analysis chart-type toggle: the all-time net balance per contact as diverging bars (#8).
  ///
  /// In en, this message translates to:
  /// **'By contact'**
  String get chartByContact;

  /// Settings section header for the owner's profile — name + phone (#9).
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// Label for the profile name field — the creditor printed on statements (#9).
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileName;

  /// Label for the optional profile phone field (#9).
  ///
  /// In en, this message translates to:
  /// **'Your phone (optional)'**
  String get profilePhone;

  /// Title of the dialog shown on the first PDF export when no profile name is set (#9).
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileNamePromptTitle;

  /// Body of the first-export name prompt, explaining why the name is needed (#9).
  ///
  /// In en, this message translates to:
  /// **'Your name appears as the sender on the statement.'**
  String get profileNamePromptMessage;

  /// Label/tooltip for the PDF statement export action on the Contact screen (#10).
  ///
  /// In en, this message translates to:
  /// **'Export statement'**
  String get exportStatement;

  /// Heading printed at the top of the PDF statement (#10).
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get statementTitle;

  /// PDF header label preceding the creditor (profile) name (#10).
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get statementFrom;

  /// PDF header label preceding the contact name/phone (#10).
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get statementTo;

  /// PDF table column header for the entry date (#10).
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get statementDateColumn;

  /// PDF table column header for the entry description (#10).
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get statementDescriptionColumn;

  /// PDF table column header for the running balance (#10).
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get statementBalanceColumn;

  /// PDF label for the balance carried in from before the date range (#10).
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get statementOpeningBalance;

  /// PDF label for the final all-time balance of the statement (#10).
  ///
  /// In en, this message translates to:
  /// **'Closing balance'**
  String get statementClosingBalance;

  /// PDF label for the gross directional totals row (#10).
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statementTotal;

  /// Settings section header for app-wide behavioral defaults — default currency + language (#12).
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// Label for the default-currency segmented control — which lens the app opens on (#12).
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get settingsDefaultCurrency;

  /// Label for the app-language segmented control (#12).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language option: follow the device language (default) (#12).
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Language option shown as an endonym — Arabic in its own script (#12).
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// Language option shown as an endonym — English in its own script (#12).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Label/tooltip for the WhatsApp balance-nudge action on the Contact screen (#11).
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappShare;

  /// Accessibility label/tooltip for tapping a Contact's phone number to open the dialer (#11).
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callContact;

  /// PDF header label preceding the statement's period value (#25).
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get statementPeriod;

  /// Label for the Reset account action in the Contact overflow menu (#25).
  ///
  /// In en, this message translates to:
  /// **'Reset account'**
  String get resetAccount;

  /// Confirm button label for the Reset account dialog (#25).
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Confirmation dialog title before resetting (settling) a contact's account (#25).
  ///
  /// In en, this message translates to:
  /// **'Reset account?'**
  String get resetAccountTitle;

  /// Confirmation dialog body naming the settling entry amount that will be added to reset the account (#25).
  ///
  /// In en, this message translates to:
  /// **'A settling entry of {amount} will be added so the balance reads settled. Your history is kept.'**
  String resetAccountMessage(String amount);

  /// Description text stamped on the balancing entry created by Reset account (#25).
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get settleEntryDescription;

  /// Label for the Archive contact action (#25).
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Label for the Unarchive contact action (#25).
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// Title of the Archived contacts screen (#25).
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedTitle;

  /// Confirmation dialog title before archiving a contact (#25).
  ///
  /// In en, this message translates to:
  /// **'Archive contact?'**
  String get archiveContactTitle;

  /// Confirmation dialog body explaining that archiving removes the contact from lists, totals and analysis (#25).
  ///
  /// In en, this message translates to:
  /// **'{name} will be set aside and leave your list, totals and analysis.'**
  String archiveContactMessage(String name);

  /// Soft-gate warning shown before archiving a contact who still owes the user money (#25).
  ///
  /// In en, this message translates to:
  /// **'{name} still owes you {amount}. Archive anyway?'**
  String archiveOutstandingOwedToMe(String name, String amount);

  /// Soft-gate warning shown before archiving a contact the user still owes money to (#25).
  ///
  /// In en, this message translates to:
  /// **'You still owe {name} {amount}. Archive anyway?'**
  String archiveOutstandingOwedByMe(String name, String amount);

  /// Placeholder shown on the Archived screen when there are no archived contacts (#25).
  ///
  /// In en, this message translates to:
  /// **'No archived contacts'**
  String get archivedEmpty;

  /// SnackBar shown after a contact is archived (#25).
  ///
  /// In en, this message translates to:
  /// **'Contact archived'**
  String get contactArchived;

  /// SnackBar shown after a contact is restored from Archived (#25).
  ///
  /// In en, this message translates to:
  /// **'Contact restored'**
  String get contactUnarchived;

  /// Hint text in the Add معاملة inline contact search field (#25).
  ///
  /// In en, this message translates to:
  /// **'Search or add a contact'**
  String get quickAddSearchHint;

  /// Tile label offering to create a new contact from the Add معاملة search query when no contact matches (#25).
  ///
  /// In en, this message translates to:
  /// **'Add “{name}” as a new contact'**
  String quickAddCreateContact(String name);

  /// Validation message shown when saving Add معاملة without choosing a contact (#25).
  ///
  /// In en, this message translates to:
  /// **'Choose or add a contact'**
  String get contactRequired;

  /// Section header for the optional opening entry on the Add contact screen (#25).
  ///
  /// In en, this message translates to:
  /// **'First entry (optional)'**
  String get firstEntrySection;

  /// Settings section header for data-lifecycle actions — erase all data (#25).
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// Label for the Erase all data action in Settings (#25).
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get eraseAllData;

  /// Subtitle under Erase all data describing the effect (#25).
  ///
  /// In en, this message translates to:
  /// **'Delete everything and start fresh'**
  String get eraseAllDataSubtitle;

  /// Confirmation dialog title before erasing all data (#25).
  ///
  /// In en, this message translates to:
  /// **'Erase all data?'**
  String get eraseAllDataTitle;

  /// Confirmation dialog body for Erase all data, naming the type-to-confirm word (#25).
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all contacts, entries, your profile and settings. Type {word} to confirm — this cannot be undone.'**
  String eraseAllDataMessage(String word);

  /// The exact word the user must type to confirm Erase all data (#25).
  ///
  /// In en, this message translates to:
  /// **'ERASE'**
  String get eraseConfirmWord;

  /// Confirm button label for the Erase all data dialog (#25).
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// Settings section header for backup/restore/auto-backup (#26).
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get settingsBackup;

  /// Action that exports the whole database to a shareable file (#26).
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExport;

  /// Export-time reminder the backup file is plaintext (#26, story 17).
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t encrypted — store it somewhere private.'**
  String get backupExportHint;

  /// Action that restores from a picked backup file (#26).
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get backupRestoreFromFile;

  /// Action that opens the dated on-device auto-backup list (#26).
  ///
  /// In en, this message translates to:
  /// **'Restore from auto-backup'**
  String get backupRestoreFromAuto;

  /// Confirm dialog title before a full-replace restore (#26).
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get backupRestoreTitle;

  /// Confirm dialog body warning restore is a full replace (#26, story 8/9).
  ///
  /// In en, this message translates to:
  /// **'This replaces all current data with the backup. Your current data is saved to an auto-backup first, so you can undo this.'**
  String get backupRestoreMessage;

  /// Confirm button label for the restore dialog (#26).
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreConfirm;

  /// Shown when the auto-backup ring is empty (#26).
  ///
  /// In en, this message translates to:
  /// **'No auto-backups yet'**
  String get backupNoAutoBackups;

  /// Title of the dated auto-backup picker (#26, story 12).
  ///
  /// In en, this message translates to:
  /// **'Restore from auto-backup'**
  String get backupAutoBackupsTitle;

  /// Success message after a restore (#26, story 20).
  ///
  /// In en, this message translates to:
  /// **'Data restored'**
  String get restoreSuccess;

  /// Refused: the picked file is foreign/corrupt (#26, story 13).
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a Daftar backup'**
  String get restoreNotABackup;

  /// Refused: the backup is from a newer app version (#26, story 14).
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of Daftar'**
  String get restoreNewerVersion;

  /// Generic restore failure message (#26, story 20).
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get restoreFailed;

  /// Success message after an export/share (#26, story 20).
  ///
  /// In en, this message translates to:
  /// **'Backup exported'**
  String get exportSuccess;

  /// Failure message when export could not produce/share a file (#26).
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;
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
