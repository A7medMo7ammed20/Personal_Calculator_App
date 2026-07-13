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
}
