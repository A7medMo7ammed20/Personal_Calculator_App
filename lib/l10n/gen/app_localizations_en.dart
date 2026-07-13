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
  String summaryTitle(String date) {
    return 'Summary up to $date';
  }
}
