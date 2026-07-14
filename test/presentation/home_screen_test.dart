import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:debt_ledger/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

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

  // A HomeScreen wired with a never-loaded controller → defaults to the SAR
  // lens, preserving the existing assertions. Tab taps still switch via
  // setActive. The AC test below supplies its own loaded controller.
  HomeScreen homeScreen() => HomeScreen(
        repository: contacts,
        entryRepository: entries,
        currencyController: CurrencyController(SettingsRepository(appDb)),
      );

  testWidgets('swipe-to-reveal delete warns a contact with the entry count', (
    tester,
  ) async {
    final contact = await contacts.add(const Contact(name: 'Sami'));
    await entries.add(
      Entry(
        contactId: contact.id!,
        amount: 10,
        direction: Direction.owedToMe,
        currency: Currency.sar,
        createdAt: DateTime(2026, 7, 13),
      ),
    );
    await entries.add(
      Entry(
        contactId: contact.id!,
        amount: 20,
        direction: Direction.owedToMe,
        currency: Currency.sar,
        createdAt: DateTime(2026, 7, 14),
      ),
    );

    await tester.pumpWidget(
      _wrap(homeScreen()),
    );
    await tester.pumpAndSettle();

    // Swipe the contact row (LTR: toward the start) → Edit/Delete appear beside
    // it (ADR 0005). Contact delete keeps its cascade-count confirm.
    await tester.drag(find.byType(Slidable).first, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Delete contact?'), findsOneWidget);
    expect(find.textContaining('2 entries'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sami'), findsNothing);
    expect(await contacts.list(), isEmpty);
  });

  testWidgets('search filters the contact list by name in real time', (
    tester,
  ) async {
    await contacts.add(const Contact(name: 'Ali'));
    await contacts.add(const Contact(name: 'Sara'));

    await tester.pumpWidget(
      _wrap(homeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsNothing);
  });

  testWidgets('search by digits matches a contact phone', (tester) async {
    await contacts.add(const Contact(name: 'Ali', phone: '055 512 3456'));
    await contacts.add(const Contact(name: 'Sara', phone: '050 999 0000'));

    await tester.pumpWidget(
      _wrap(homeScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0555123');
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsNothing);
  });

  testWidgets('contact rows are phone-less: the number is not shown in-app', (
    tester,
  ) async {
    await contacts.add(const Contact(name: 'Ali', phone: '055 512 3456'));

    await tester.pumpWidget(
      _wrap(homeScreen()),
    );
    await tester.pumpAndSettle();

    // The name shows; the phone stays for PDF/WhatsApp only (design-system.md).
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('055 512 3456'), findsNothing);
  });

  testWidgets('home shows one summary card with both all-time totals', (
    tester,
  ) async {
    final ali = await contacts.add(const Contact(name: 'Ali'));
    await entries.add(
      Entry(
        contactId: ali.id!,
        amount: 100,
        direction: Direction.owedToMe,
        currency: Currency.sar,
        createdAt: DateTime(2026, 7, 13),
      ),
    );

    await tester.pumpWidget(
      _wrap(homeScreen()),
    );
    await tester.pumpAndSettle();

    // The unified card carries both directional totals at all time.
    expect(find.text('Owed to you'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
  });

  Future<void> addEntry(
    int contactId, {
    required double amount,
    Direction direction = Direction.owedToMe,
    required DateTime when,
  }) => entries.add(
    Entry(
      contactId: contactId,
      amount: amount,
      direction: direction,
      currency: Currency.sar,
      createdAt: when,
    ),
  );

  testWidgets(
    'This month hides out-of-range contacts, keeps all-time balance, shows flow',
    (tester) async {
      final ali = await contacts.add(const Contact(name: 'Ali'));
      final sara = await contacts.add(const Contact(name: 'Sara'));
      // Ali: an old debt plus recent activity -> all-time balance 1250.
      await addEntry(ali.id!, amount: 1000, when: DateTime(2020, 1, 1));
      await addEntry(ali.id!, amount: 250, when: DateTime.now());
      // Sara: only an old debt, so no activity this month.
      await addEntry(sara.id!, amount: 500, when: DateTime(2020, 1, 1));

      await tester.pumpWidget(
        _wrap(homeScreen()),
      );
      await tester.pumpAndSettle();

      // All time: both contacts, net-position header.
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);

      // Switch the period to This month.
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This month').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Sara drops out (no activity this month); Ali stays.
      expect(find.text('Sara'), findsNothing);
      expect(find.text('Ali'), findsOneWidget);
      // Ali's row still shows the TRUE all-time balance (1250), not the window.
      expect(find.text('owes you 1,250.00 ر.س'), findsOneWidget);
      // Header is now flow (Lent/Received), not the net-position totals.
      expect(find.text('Lent'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Owed to you'), findsNothing);
      expect(find.text('250.00 ر.س'), findsOneWidget); // lent this month
    },
  );

  testWidgets('a period with no activity shows the empty-period state', (
    tester,
  ) async {
    final ali = await contacts.add(const Contact(name: 'Ali'));
    await addEntry(ali.id!, amount: 100, when: DateTime(2020, 1, 1));

    await tester.pumpWidget(
      _wrap(homeScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This month').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsNothing);
    expect(find.text('No activity in this period'), findsOneWidget);
  });

  testWidgets('opens on the currency controller\'s active lens (default seed)',
      (tester) async {
    final khaled = await contacts.add(const Contact(name: 'Khaled'));
    await entries.add(Entry(
      contactId: khaled.id!,
      amount: 100,
      direction: Direction.owedToMe,
      currency: Currency.sar,
      createdAt: DateTime(2026, 7, 13, 12),
    ));
    await entries.add(Entry(
      contactId: khaled.id!,
      amount: 300,
      direction: Direction.owedToMe,
      currency: Currency.yer,
      createdAt: DateTime(2026, 7, 13, 12),
    ));

    // Seed the persisted default to YER, then load the controller.
    final settings = SettingsRepository(appDb);
    await settings.setDefaultCurrency(Currency.yer);
    final currency = CurrencyController(settings);
    await currency.load();

    await tester.pumpWidget(_wrap(
      HomeScreen(
        repository: contacts,
        entryRepository: entries,
        currencyController: currency,
      ),
    ));
    await tester.pumpAndSettle();

    // Home opens on the YER lens, not the hardcoded SAR.
    expect(find.textContaining('300.00'), findsWidgets);
    expect(find.textContaining('100.00'), findsNothing);
  });
}
