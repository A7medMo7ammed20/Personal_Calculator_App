import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/contact_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late EntryRepository entries;
  late Contact contact;

  setUp(() async {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    entries = EntryRepository(appDb);
    contact = await ContactRepository(appDb).add(const Contact(name: 'Khaled'));
  });

  tearDown(() => appDb.close());

  Entry seed(
    int contactId,
    Direction direction,
    double amount,
  ) => Entry(
    contactId: contactId,
    amount: amount,
    direction: direction,
    currency: Currency.sar,
    createdAt: DateTime(2026, 7, 13, 12),
  );

  testWidgets('shows the empty state when the contact has no entries',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Khaled'), findsWidgets);
    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
  });

  testWidgets('shows a green owes-you balance for an owed-to-me entry',
      (tester) async {
    await entries.add(seed(contact.id!, Direction.owedToMe, 150));

    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('owes you'), findsOneWidget);
    expect(find.textContaining('150'), findsWidgets);
  });

  testWidgets('a repayment nets the balance down', (tester) async {
    await entries.add(seed(contact.id!, Direction.owedToMe, 100));
    await entries.add(seed(contact.id!, Direction.owedByMe, 40));

    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    // Net is 60 owed-to-me, not 100.
    expect(find.textContaining('owes you'), findsOneWidget);
    expect(find.textContaining('60'), findsWidgets);
  });

  testWidgets('renders the Arabic owed-by-me balance (RTL)', (tester) async {
    await entries.add(seed(contact.id!, Direction.owedByMe, 80));

    await tester.pumpWidget(_wrap(
      const Locale('ar'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    // The balance header carries the amount; "عليك" alone also appears as the
    // no-description entry's fallback title, so match the header specifically.
    expect(find.textContaining('عليك 80'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
  });

  testWidgets('adding an entry through the form updates the balance',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Back on the contact page with the new balance.
    expect(find.textContaining('owes you'), findsOneWidget);
    expect(find.textContaining('250'), findsWidgets);
    expect(find.text('No entries yet'), findsNothing);
  });

  testWidgets('saving with an empty amount is blocked', (tester) async {
    await tester.pumpWidget(_wrap(
      const Locale('en'),
      ContactScreen(contact: contact, repository: entries, currency: Currency.sar),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });
}
