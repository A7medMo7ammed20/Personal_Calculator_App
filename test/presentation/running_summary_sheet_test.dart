import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/contacts/running_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e({
  required int id,
  Direction direction = Direction.owedToMe,
  required double amount,
  required DateTime when,
}) => Entry(
  id: id, contactId: 1, amount: amount, direction: direction,
  currency: Currency.sar, createdAt: when,
);

void main() {
  testWidgets('sheet shows gross totals and net up to the tapped entry',
      (tester) async {
    final entries = [
      e(id: 1, amount: 200, when: DateTime(2026, 3, 1)),
      e(id: 2, direction: Direction.owedByMe, amount: 50, when: DateTime(2026, 3, 2)),
      e(id: 3, amount: 190, when: DateTime(2026, 3, 3)),
    ];

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showRunningSummarySheet(
                context,
                entries: entries,
                tapped: entries[1], // up to Mar 2
                currency: Currency.sar,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Up to Mar 2: gross owed-to-me 200, gross owed-by-me 50, net 150 owed-to-me.
    expect(find.textContaining('Owed to you'), findsWidgets);
    expect(find.textContaining('You owe'), findsWidgets);
    expect(find.textContaining('200'), findsWidgets);
    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('150'), findsWidgets); // net closing balance
    // The later entry (id 3, Mar 3) is NOT included.
    expect(find.textContaining('190'), findsNothing);
  });
}
