import 'dart:typed_data';

import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/contact_screen.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late EntryRepository entries;
  late ProfileRepository profileRepo;
  late ProfileController profileController;
  late Contact contact;

  setUp(() async {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    entries = EntryRepository(appDb);
    profileRepo = ProfileRepository(appDb);
    profileController = ProfileController(profileRepo);
    contact = await ContactRepository(appDb).add(const Contact(name: 'Khaled'));
  });

  tearDown(() => appDb.close());

  Uint8List? sharedBytes;
  String? sharedName;

  Widget host(Locale locale) {
    sharedBytes = null;
    sharedName = null;
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ContactScreen(
        contact: contact,
        repository: entries,
        currency: Currency.sar,
        profileController: profileController,
        onSharePdf: (bytes, name) async {
          sharedBytes = bytes;
          sharedName = name;
        },
      ),
    );
  }

  Entry seed(Direction direction, double amount) => Entry(
        contactId: contact.id!,
        amount: amount,
        direction: direction,
        currency: Currency.sar,
        createdAt: DateTime(2026, 7, 13, 12),
      );

  bool isPdf(List<int>? bytes) =>
      bytes != null &&
      bytes.length > 5 &&
      String.fromCharCodes(bytes.take(5)) == '%PDF-';

  final exportAction = find.byKey(const Key('export-statement'));
  final shareButton = find.byKey(const Key('export-share'));

  testWidgets('no export action when the contact has no entries', (
    tester,
  ) async {
    await profileController.setName('Ahmed');
    await tester.pumpWidget(host(const Locale('en')));
    await tester.pumpAndSettle();

    expect(exportAction, findsNothing);
  });

  testWidgets('exports a PDF when a name is already set', (tester) async {
    await profileController.setName('Ahmed');
    await entries.add(seed(Direction.owedToMe, 150));
    await tester.pumpWidget(host(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(exportAction);
    await tester.pumpAndSettle();
    await tester.tap(shareButton); // default period: All time
    await tester.pumpAndSettle();

    expect(isPdf(sharedBytes), isTrue);
    expect(sharedName, endsWith('.pdf'));
  });

  testWidgets('prompts for the name on first export, then exports', (
    tester,
  ) async {
    await entries.add(seed(Direction.owedToMe, 150));
    await tester.pumpWidget(host(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(exportAction);
    await tester.pumpAndSettle();
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    // The name prompt intercepts before any PDF is produced.
    expect(find.text('Add your name'), findsOneWidget);
    expect(sharedBytes, isNull);

    await tester.enterText(
        find.byKey(const Key('profile-name-prompt-field')), 'Ahmed');
    await tester.tap(find.byKey(const Key('profile-name-prompt-save')));
    await tester.pumpAndSettle();

    expect(isPdf(sharedBytes), isTrue);
    expect(profileController.profile?.name, 'Ahmed');
  });

  testWidgets('cancelling the name prompt aborts the export', (tester) async {
    await entries.add(seed(Direction.owedToMe, 150));
    await tester.pumpWidget(host(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(exportAction);
    await tester.pumpAndSettle();
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(sharedBytes, isNull);
    expect(profileController.profile, isNull);
  });
}
