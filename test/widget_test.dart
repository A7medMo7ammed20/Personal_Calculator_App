import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomeScreen(),
  );
}

void main() {
  testWidgets('home renders the English empty state (LTR)', (tester) async {
    await tester.pumpWidget(_wrap(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Debt Ledger'), findsOneWidget);
    expect(find.text('No contacts yet'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr);
  });

  testWidgets('home renders the Arabic empty state (RTL)', (tester) async {
    await tester.pumpWidget(_wrap(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('دفتر الديون'), findsOneWidget);
    expect(find.text('لا توجد جهات اتصال بعد'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);
  });
}
