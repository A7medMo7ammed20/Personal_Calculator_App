// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Debt Ledger';

  @override
  String get homeEmpty => 'No contacts yet';

  @override
  String get addContact => 'Add contact';

  @override
  String get contactName => 'Name';

  @override
  String get contactPhone => 'Phone (optional)';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get save => 'Save';

  @override
  String get addEntry => 'Add entry';

  @override
  String get entryAmount => 'Amount';

  @override
  String get amountRequired => 'Enter an amount';

  @override
  String get amountInvalid => 'Enter an amount greater than zero';

  @override
  String get directionOwedToMe => 'Owed to me';

  @override
  String get directionOwedByMe => 'Owed by me';

  @override
  String get entryDescription => 'Description (optional)';

  @override
  String get entryDateTime => 'Date & time';

  @override
  String get contactEntriesEmpty => 'No entries yet';

  @override
  String balanceOwedToMe(String amount) {
    return 'owes you $amount';
  }

  @override
  String balanceOwedByMe(String amount) {
    return 'you owe $amount';
  }

  @override
  String get balanceSettled => 'Settled';

  @override
  String get homeTotalOwedToMe => 'Owed to you';

  @override
  String get homeTotalOwedByMe => 'You owe';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get undo => 'Undo';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get editContact => 'Edit contact';

  @override
  String get deleteEntryTitle => 'Delete entry?';

  @override
  String get deleteEntryMessage =>
      'This entry will be removed and the balance recomputed.';

  @override
  String get entryDeleted => 'Entry deleted';

  @override
  String get deleteContactTitle => 'Delete contact?';

  @override
  String deleteContactMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries will also be deleted.',
      one: '1 entry will also be deleted.',
      zero: 'This contact has no entries.',
    );
    return '$_temp0';
  }

  @override
  String get contactDeleted => 'Contact deleted';

  @override
  String get searchEntriesHint => 'Search description';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortByDate => 'Date';

  @override
  String get sortByValue => 'Value';

  @override
  String get sortByDescription => 'Description';

  @override
  String get searchContactsHint => 'Search name or phone';

  @override
  String get homeNoMatches => 'No matches';

  @override
  String get sortByActivity => 'Recent';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByBalanceSize => 'Balance';

  @override
  String get periodLabel => 'Period';

  @override
  String get periodAllTime => 'All time';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodLastMonth => 'Last month';

  @override
  String get periodThisYear => 'This year';

  @override
  String get periodCustom => 'Custom';

  @override
  String get flowLent => 'Lent';

  @override
  String get flowReceived => 'Received';

  @override
  String get homeNoActivityInPeriod => 'No activity in this period';

  @override
  String summaryTitle(String date) {
    return 'Summary up to $date';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccent => 'Accent color';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentPlum => 'Plum';

  @override
  String get accentOcean => 'Ocean';

  @override
  String get analysisTitle => 'Analysis';

  @override
  String analysisEmpty(String currency) {
    return 'No $currency activity yet';
  }

  @override
  String breakdownTitle(String interval) {
    return 'Changes · $interval';
  }

  @override
  String get breakdownEmpty => 'No entries in this interval';

  @override
  String get chartOverTime => 'Over time';

  @override
  String get chartByContact => 'By contact';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get profileName => 'Your name';

  @override
  String get profilePhone => 'Your phone (optional)';

  @override
  String get profileNamePromptTitle => 'Add your name';

  @override
  String get profileNamePromptMessage =>
      'Your name appears as the sender on the statement.';

  @override
  String get exportStatement => 'Export statement';

  @override
  String get statementTitle => 'Statement';

  @override
  String get statementFrom => 'From';

  @override
  String get statementTo => 'To';

  @override
  String get statementDateColumn => 'Date';

  @override
  String get statementDescriptionColumn => 'Description';

  @override
  String get statementBalanceColumn => 'Balance';

  @override
  String get statementOpeningBalance => 'Opening balance';

  @override
  String get statementClosingBalance => 'Closing balance';

  @override
  String get statementTotal => 'Total';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsDefaultCurrency => 'Default currency';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get whatsappShare => 'WhatsApp';

  @override
  String get callContact => 'Call';

  @override
  String get statementPeriod => 'Period';

  @override
  String get resetAccount => 'Reset account';

  @override
  String get reset => 'Reset';

  @override
  String get resetAccountTitle => 'Reset account?';

  @override
  String resetAccountMessage(String amount) {
    return 'A settling entry of $amount will be added so the balance reads settled. Your history is kept.';
  }

  @override
  String get settleEntryDescription => 'Settlement';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get archivedTitle => 'Archived';

  @override
  String get archiveContactTitle => 'Archive contact?';

  @override
  String archiveContactMessage(String name) {
    return '$name will be set aside and leave your list, totals and analysis.';
  }

  @override
  String archiveOutstandingOwedToMe(String name, String amount) {
    return '$name still owes you $amount. Archive anyway?';
  }

  @override
  String archiveOutstandingOwedByMe(String name, String amount) {
    return 'You still owe $name $amount. Archive anyway?';
  }

  @override
  String get archivedEmpty => 'No archived contacts';

  @override
  String get contactArchived => 'Contact archived';

  @override
  String get contactUnarchived => 'Contact restored';

  @override
  String get quickAddSearchHint => 'Search or add a contact';

  @override
  String quickAddCreateContact(String name) {
    return 'Add “$name” as a new contact';
  }

  @override
  String get contactRequired => 'Choose or add a contact';

  @override
  String get firstEntrySection => 'First entry (optional)';

  @override
  String get settingsData => 'Data';

  @override
  String get eraseAllData => 'Erase all data';

  @override
  String get eraseAllDataSubtitle => 'Delete everything and start fresh';

  @override
  String get eraseAllDataTitle => 'Erase all data?';

  @override
  String eraseAllDataMessage(String word) {
    return 'This permanently deletes all contacts, entries, your profile and settings. Type $word to confirm — this cannot be undone.';
  }

  @override
  String get eraseConfirmWord => 'ERASE';

  @override
  String get erase => 'Erase';
}
