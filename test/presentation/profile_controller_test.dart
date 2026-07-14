import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/domain/profile.dart';
import 'package:debt_ledger/presentation/profile/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ProfileRepository repo;
  late ProfileController controller;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = ProfileRepository(appDb);
    controller = ProfileController(repo);
  });

  tearDown(() => appDb.close());

  test('starts with no profile before load', () {
    expect(controller.profile, isNull);
    expect(controller.hasName, isFalse);
  });

  test('load pulls the persisted profile and notifies once', () async {
    await repo.setName('Ahmed');
    await repo.setPhone('0555');
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.load();

    expect(controller.profile, const Profile(name: 'Ahmed', phone: '0555'));
    expect(controller.hasName, isTrue);
    expect(notified, 1);
  });

  test('setName from unset creates a profile, persists, and notifies once',
      () async {
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setName('Ahmed');

    expect(controller.profile, const Profile(name: 'Ahmed'));
    expect(controller.hasName, isTrue);
    expect(notified, 1);
    expect(await repo.profile(), const Profile(name: 'Ahmed'));
  });

  test('setName keeps the existing phone', () async {
    await controller.save(name: 'Ahmed', phone: '0555');

    await controller.setName('Sara');

    expect(controller.profile, const Profile(name: 'Sara', phone: '0555'));
  });

  test('save sets name and phone, persists, and notifies once', () async {
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.save(name: 'Ahmed', phone: '0555');

    expect(controller.profile, const Profile(name: 'Ahmed', phone: '0555'));
    expect(notified, 1);
    expect(await repo.profile(), const Profile(name: 'Ahmed', phone: '0555'));
  });

  test('save with a null phone stores a phoneless profile', () async {
    await controller.save(name: 'Ahmed', phone: null);
    expect(controller.profile, const Profile(name: 'Ahmed'));
  });
}
