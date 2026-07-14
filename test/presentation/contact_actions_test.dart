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

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late EntryRepository entries;
  late ContactRepository contacts;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    entries = EntryRepository(appDb);
    contacts = ContactRepository(appDb);
  });

  tearDown(() => appDb.close());

  Uri? launched;

  Widget host(Contact contact, Locale locale, {Currency currency = Currency.sar}) {
    launched = null;
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ContactScreen(
        contact: contact,
        repository: entries,
        currency: currency,
        onLaunchUrl: (uri) async => launched = uri,
      ),
    );
  }

  Entry seed(int contactId, Direction direction, double amount) => Entry(
        contactId: contactId,
        amount: amount,
        direction: direction,
        currency: Currency.sar,
        createdAt: DateTime(2026, 7, 13, 12),
      );

  testWidgets('no action strip when the contact has no phone', (tester) async {
    final c = await contacts.add(const Contact(name: 'Khaled'));
    await tester.pumpWidget(host(c, const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contact-whatsapp')), findsNothing);
    expect(find.byKey(const Key('contact-call')), findsNothing);
  });

  testWidgets('tapping the number launches tel: with the raw stored number', (
    tester,
  ) async {
    final c = await contacts.add(const Contact(name: 'Khaled', phone: '055 123 4567'));
    await tester.pumpWidget(host(c, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-call')));
    await tester.pumpAndSettle();

    expect(launched, Uri(scheme: 'tel', path: '055 123 4567'));
  });

  testWidgets('WhatsApp launches wa.me with normalized number + owed-to-me text',
      (tester) async {
    final c = await contacts.add(const Contact(name: 'Khaled', phone: '+966 50 111'));
    await entries.add(seed(c.id!, Direction.owedToMe, 150));
    await tester.pumpWidget(host(c, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-whatsapp')));
    await tester.pumpAndSettle();

    expect(launched?.host, 'wa.me');
    expect(launched?.path, '/96650111');
    expect(launched?.queryParameters['text'],
        'Hi Khaled, your balance with me: you owe me 150.00 ر.س');
  });

  testWidgets('WhatsApp text is owed-by-me when the user owes', (tester) async {
    final c = await contacts.add(const Contact(name: 'Khaled', phone: '966501'));
    await entries.add(seed(c.id!, Direction.owedByMe, 75));
    await tester.pumpWidget(host(c, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-whatsapp')));
    await tester.pumpAndSettle();

    expect(launched?.queryParameters['text'],
        'Hi Khaled, your balance with me: I owe you 75.00 ر.س');
  });

  testWidgets('a settled balance sends the friendly no-amount note', (tester) async {
    final c = await contacts.add(const Contact(name: 'Khaled', phone: '966501'));
    await entries.add(seed(c.id!, Direction.owedToMe, 50));
    await entries.add(seed(c.id!, Direction.owedByMe, 50)); // nets to 0
    await tester.pumpWidget(host(c, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-whatsapp')));
    await tester.pumpAndSettle();

    expect(launched?.queryParameters['text'], "Hi Khaled, we're all settled — thanks!");
  });

  testWidgets('Arabic app → Arabic WhatsApp message', (tester) async {
    final c = await contacts.add(const Contact(name: 'خالد', phone: '966501'));
    await entries.add(seed(c.id!, Direction.owedToMe, 150));
    await tester.pumpWidget(host(c, const Locale('ar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contact-whatsapp')));
    await tester.pumpAndSettle();

    expect(launched?.queryParameters['text'], 'مرحباً خالد، رصيدك معي: عليك 150.00 ر.س');
  });
}
