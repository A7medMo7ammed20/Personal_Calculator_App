import 'package:debt_ledger/app.dart';
import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/entry_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The slice-2 seam: pump the app root with an injected [SettingsRepository] and
/// assert the whole app re-tints when the accent changes, and that the choice
/// persists (ADR 0002).
void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository settings;
  late ThemeController controller;

  setUp(() async {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    settings = SettingsRepository(appDb);
    controller = ThemeController(settings);
    await controller.load();
  });

  tearDown(() => appDb.close());

  Color rootPrimary(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.colorScheme.primary;

  testWidgets('picking a new accent in Settings re-tints the app and persists', (
    tester,
  ) async {
    await tester.pumpWidget(DebtLedgerApp(
      contactRepository: ContactRepository(appDb),
      entryRepository: EntryRepository(appDb),
      themeController: controller,
    ));
    // The animated DaftarSplash plays first (monogram draw-on + wordmark), then
    // routes to the home screen after a short hold timer. pumpAndSettle won't
    // fire that lone trailing timer on its own, so advance the clock past the
    // animation and the hold before driving the home UI.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // finish the draw animation
    await tester.pump(const Duration(seconds: 1)); // fire the hold timer → navigate
    await tester.pumpAndSettle();

    // Starts on the default Teal chrome.
    expect(
      rootPrimary(tester),
      buildAppTheme(brightness: Brightness.light, seed: const Color(0xFF14746F))
          .colorScheme
          .primary,
    );

    // Open the ⋮ overflow menu → Settings.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Pick Plum.
    await tester.tap(find.byKey(const Key('accent-plum')));
    await tester.pumpAndSettle();

    // The root theme re-tinted to the Plum-derived primary...
    expect(
      rootPrimary(tester),
      buildAppTheme(brightness: Brightness.light, seed: const Color(0xFF6D28D9))
          .colorScheme
          .primary,
    );
    // ...and the choice was persisted.
    expect(await settings.accent(), AccentTheme.plum);
  });
}
