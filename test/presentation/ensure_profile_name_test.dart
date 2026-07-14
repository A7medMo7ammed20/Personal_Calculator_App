import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/domain/profile.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/profile/ensure_profile_name.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ProfileRepository repo;
  late ProfileController controller;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    repo = ProfileRepository(appDb);
    controller = ProfileController(repo);
  });

  tearDown(() => appDb.close());

  // Captures what ensureProfileName returns so tests can assert it.
  Profile? captured;
  var calls = 0;

  Widget host() {
    captured = null;
    calls = 0;
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              calls++;
              captured = await ensureProfileName(context, controller);
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
  }

  final field = find.byKey(const Key('profile-name-prompt-field'));
  final saveButton = find.byKey(const Key('profile-name-prompt-save'));

  testWidgets('returns the existing profile without prompting', (tester) async {
    await repo.setName('Ahmed');
    await controller.load();
    await tester.pumpWidget(host());

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(field, findsNothing); // no dialog
    expect(captured, const Profile(name: 'Ahmed'));
  });

  testWidgets('prompts when unset, then returns and persists the name', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Add your name'), findsOneWidget);
    await tester.enterText(field, 'Ahmed');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(field, findsNothing); // dialog dismissed
    expect(captured, const Profile(name: 'Ahmed'));
    expect(controller.profile, const Profile(name: 'Ahmed'));
    expect(await repo.profile(), const Profile(name: 'Ahmed'));
  });

  testWidgets('cancelling returns null and leaves the profile unset', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
    expect(controller.profile, isNull);
  });

  testWidgets('a blank name is rejected rather than saved', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(field, '   ');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(field, findsOneWidget); // still open
    expect(controller.profile, isNull);
  });

  testWidgets('does not prompt again once the name is set', (tester) async {
    await tester.pumpWidget(host());

    // First call prompts and sets the name.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Ahmed');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Second call must not show a dialog.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(field, findsNothing);
    expect(captured, const Profile(name: 'Ahmed'));
  });
}
