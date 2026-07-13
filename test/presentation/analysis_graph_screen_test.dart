import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/period.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/analysis/analysis_graph_screen.dart';
import 'package:flutter/material.dart';
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

  AnalysisGraphScreen screen() => AnalysisGraphScreen(
    entryRepository: entries,
    contactRepository: contacts,
    currency: Currency.sar,
    period: PeriodOption.allTime,
  );

  testWidgets('shows the per-lens empty state when the currency has no entries',
      (tester) async {
    await tester.pumpWidget(_wrap(screen()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.analysisEmpty('SAR')), findsOneWidget);
  });

  testWidgets('renders the chart (not the empty state) when the lens has entries',
      (tester) async {
    final a = await contacts.add(const Contact(name: 'Ahmed'));
    await entries.add(Entry(
      contactId: a.id!, amount: 1000, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 5, 10),
    ));
    await entries.add(Entry(
      contactId: a.id!, amount: 400, direction: Direction.owedByMe,
      currency: Currency.sar, createdAt: DateTime(2026, 5, 12),
    ));

    await tester.pumpWidget(_wrap(screen()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // The line is painted; the empty state is gone.
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text(l10n.analysisEmpty('SAR')), findsNothing);
  });

  testWidgets('switching the lens redraws for the other currency',
      (tester) async {
    final a = await contacts.add(const Contact(name: 'Ahmed'));
    // SAR has an entry; YER has none.
    await entries.add(Entry(
      contactId: a.id!, amount: 1000, direction: Direction.owedToMe,
      currency: Currency.sar, createdAt: DateTime(2026, 5, 10),
    ));

    await tester.pumpWidget(_wrap(screen()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Starts on SAR: a chart, no empty state.
    expect(find.text(l10n.analysisEmpty('SAR')), findsNothing);

    // Switch the lens to YER → empty state for the other currency.
    await tester.tap(find.text('YER'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.analysisEmpty('YER')), findsOneWidget);
  });
}
