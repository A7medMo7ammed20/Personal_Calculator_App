import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/profile.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:debt_ledger/presentation/settings/settings_screen.dart';
import 'package:debt_ledger/presentation/theme/app_theme.dart';
import 'package:debt_ledger/presentation/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ThemeController themeController;
  late ProfileRepository profileRepo;
  late ProfileController profileController;

  setUp(() {
    appDb = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    themeController = ThemeController(SettingsRepository(appDb));
    profileRepo = ProfileRepository(appDb);
    profileController = ProfileController(profileRepo);
  });

  tearDown(() => appDb.close());

  Widget host() => MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          controller: themeController,
          profileController: profileController,
        ),
      );

  testWidgets('shows a Profile section with name and phone fields', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.text('Profile'), findsOneWidget);
    expect(find.byKey(const Key('profile-name-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-phone-field')), findsOneWidget);
  });

  testWidgets('prefills the fields from the stored profile', (tester) async {
    await profileRepo.setName('Ahmed');
    await profileRepo.setPhone('0555');
    await profileController.load();

    await tester.pumpWidget(host());

    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('0555'), findsOneWidget);
  });

  testWidgets('editing and saving persists the profile', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(
        find.byKey(const Key('profile-name-field')), 'Ahmed');
    await tester.enterText(
        find.byKey(const Key('profile-phone-field')), '0555');
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(profileController.profile, const Profile(name: 'Ahmed', phone: '0555'));
    expect(await profileRepo.profile(),
        const Profile(name: 'Ahmed', phone: '0555'));
  });

  testWidgets('requires a name before saving', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(profileController.profile, isNull);
  });
}
