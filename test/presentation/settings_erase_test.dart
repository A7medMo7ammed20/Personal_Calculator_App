import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/settings/settings_screen.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ThemeController controller;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    controller = ThemeController(SettingsRepository(appDb));
  });

  tearDown(() => appDb.close());

  Widget hostWithErase(Future<void> Function() onErase) => MaterialApp(
    theme: buildAppTheme(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SettingsScreen(controller: controller, onEraseAllData: onErase),
  );

  testWidgets('erase confirm stays disabled until the confirmation word typed', (
    tester,
  ) async {
    var erased = 0;
    await tester.pumpWidget(hostWithErase(() async => erased++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erase all data'));
    await tester.pumpAndSettle();

    TextButton btn() =>
        tester.widget<TextButton>(find.byKey(const Key('erase-confirm')));
    expect(btn().enabled, isFalse);

    await tester.enterText(
      find.byKey(const Key('erase-confirm-field')),
      'ERASE',
    );
    await tester.pumpAndSettle();
    expect(btn().enabled, isTrue);

    await tester.tap(find.byKey(const Key('erase-confirm')));
    await tester.pumpAndSettle();
    expect(erased, 1);
  });

  testWidgets('the Data section is hidden when onEraseAllData is not wired', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Erase all data'), findsNothing);
  });
}
