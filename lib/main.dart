import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/contact_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase();
  final contactRepository = ContactRepository(appDatabase);
  runApp(DebtLedgerApp(contactRepository: contactRepository));
}
