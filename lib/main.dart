import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/contact_repository.dart';
import 'data/entry_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase();
  final contactRepository = ContactRepository(appDatabase);
  final entryRepository = EntryRepository(appDatabase);
  runApp(DebtLedgerApp(
    contactRepository: contactRepository,
    entryRepository: entryRepository,
  ));
}
