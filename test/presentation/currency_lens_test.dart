import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/home/home_screen.dart';
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
  late ContactRepository contacts;
  late EntryRepository entries;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    contacts = ContactRepository(appDb);
    entries = EntryRepository(appDb);
  });

  tearDown(() => appDb.close());

  Entry entry(int contactId, Currency currency, double amount) => Entry(
    contactId: contactId,
    amount: amount,
    direction: Direction.owedToMe,
    currency: currency,
    createdAt: DateTime(2026, 7, 13, 12),
  );

  HomeScreen home() =>
      HomeScreen(repository: contacts, entryRepository: entries);

  testWidgets('home shows the currency lens with SAR and YER', (tester) async {
    await tester.pumpWidget(_wrap(const Locale('en'), home()));
    await tester.pumpAndSettle();

    // The lens is now a tap-only pill bar (ADR 0005), still labelled SAR / YER.
    expect(find.text('SAR'), findsOneWidget);
    expect(find.text('YER'), findsOneWidget);
  });

  testWidgets('body swipe no longer changes the currency lens (ADR 0005)', (
    tester,
  ) async {
    final khaled = await contacts.add(const Contact(name: 'Khaled'));
    await entries.add(entry(khaled.id!, Currency.sar, 100));
    await entries.add(entry(khaled.id!, Currency.yer, 300));

    await tester.pumpWidget(_wrap(const Locale('en'), home()));
    await tester.pumpAndSettle();

    // Default SAR lens.
    expect(find.textContaining('100.00'), findsWidgets);
    expect(find.textContaining('300.00'), findsNothing);

    // Horizontal drag on a row is a swipe-to-reveal gesture now, not a lens
    // switch — the currency must stay on SAR.
    await tester.drag(
      find.textContaining('100.00').first,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('100.00'), findsWidgets);
    expect(find.textContaining('300.00'), findsNothing);
  });

  testWidgets('switching the lens refilters totals and per-contact balances', (
    tester,
  ) async {
    final khaled = await contacts.add(const Contact(name: 'Khaled'));
    await entries.add(entry(khaled.id!, Currency.sar, 100));
    await entries.add(entry(khaled.id!, Currency.yer, 300));

    await tester.pumpWidget(_wrap(const Locale('en'), home()));
    await tester.pumpAndSettle();

    // Default lens is SAR: only the SAR figures show.
    expect(find.textContaining('100.00'), findsWidgets);
    expect(find.textContaining('300.00'), findsNothing);

    await tester.tap(find.text('YER'));
    await tester.pumpAndSettle();

    // Now only the independent YER figures show — never a combined 400.
    expect(find.textContaining('300.00'), findsWidgets);
    expect(find.textContaining('100.00'), findsNothing);
    expect(find.textContaining('400'), findsNothing);
  });

  testWidgets('a contact with no entries in the lens reads as settled', (
    tester,
  ) async {
    final yerOnly = await contacts.add(const Contact(name: 'YerOnly'));
    await entries.add(entry(yerOnly.id!, Currency.yer, 300));

    await tester.pumpWidget(_wrap(const Locale('en'), home()));
    await tester.pumpAndSettle();

    // SAR lens active by default: this YER-only contact shows settled.
    expect(find.text('YerOnly'), findsOneWidget);
    expect(find.text('Settled'), findsWidgets);
  });

  testWidgets('a new entry inherits the active lens currency (no picker)', (
    tester,
  ) async {
    final c = await contacts.add(const Contact(name: 'Nora'));

    await tester.pumpWidget(_wrap(const Locale('en'), home()));
    await tester.pumpAndSettle();

    // Switch the lens to YER, then add an entry through the contact page.
    await tester.tap(find.text('YER'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nora'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // The add-entry form offers no currency choice.
    expect(find.text('SAR'), findsNothing);
    expect(find.text('YER'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '150');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final yer = await entries.listByContact(c.id!, currency: Currency.yer);
    final sar = await entries.listByContact(c.id!, currency: Currency.sar);
    expect(yer, hasLength(1));
    expect(yer.single.amount, 150);
    expect(sar, isEmpty);
  });
}
