import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/profile_repository.dart';
import 'package:debt_ledger/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late ProfileRepository repo;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = ProfileRepository(appDb);
  });

  tearDown(() => appDb.close());

  test('a fresh database has no profile', () async {
    expect(await repo.profile(), isNull);
  });

  test('setting the name yields a profile with no phone', () async {
    await repo.setName('Ahmed');
    expect(await repo.profile(), const Profile(name: 'Ahmed'));
  });

  test('name and phone round-trip together', () async {
    await repo.setName('Ahmed');
    await repo.setPhone('0555');
    expect(await repo.profile(), const Profile(name: 'Ahmed', phone: '0555'));
  });

  test('a phone without a name is still no profile', () async {
    // The name is the anchor; an orphan phone never produces a Profile.
    await repo.setPhone('0555');
    expect(await repo.profile(), isNull);
  });

  test('a blank/whitespace name counts as unset', () async {
    await repo.setName('   ');
    expect(await repo.profile(), isNull);
  });

  test('the name is trimmed on the way in', () async {
    await repo.setName('  Ahmed  ');
    expect(await repo.profile(), const Profile(name: 'Ahmed'));
  });

  test('clearing the phone drops it back to null', () async {
    await repo.setName('Ahmed');
    await repo.setPhone('0555');
    await repo.setPhone(null);
    expect(await repo.profile(), const Profile(name: 'Ahmed'));
  });

  test('setting the name twice overwrites rather than duplicating', () async {
    await repo.setName('Ahmed');
    await repo.setName('Sara');
    expect(await repo.profile(), const Profile(name: 'Sara'));
  });

  test('a separate repository on the same db reads persisted values', () async {
    // Profile lives in the shared settings table, so it travels with the
    // Backup (ADR 0001) — a fresh repository sees what an earlier one wrote.
    await repo.setName('Ahmed');
    await repo.setPhone('0555');

    final other = ProfileRepository(appDb);
    expect(await other.profile(), const Profile(name: 'Ahmed', phone: '0555'));
  });
}
