import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/backup_dirty_flag.dart';
import 'package:debt_ledger/data/contact_repository.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/accent_theme.dart';
import 'package:debt_ledger/domain/contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late BackupDirtyFlag dirty;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    dirty = BackupDirtyFlag();
  });
  tearDown(() => appDb.close());

  test('starts clean and mark/reset flip the flag', () {
    expect(dirty.isDirty, isFalse);
    dirty.mark();
    expect(dirty.isDirty, isTrue);
    dirty.reset();
    expect(dirty.isDirty, isFalse);
  });

  test('a contact write marks the flag dirty', () async {
    final repo = ContactRepository(appDb, dirty: dirty);
    await repo.add(const Contact(name: 'Ali'));
    expect(dirty.isDirty, isTrue);
  });

  test('a settings write marks the flag dirty', () async {
    final repo = SettingsRepository(appDb, dirty: dirty);
    await repo.setAccent(AccentTheme.plum);
    expect(dirty.isDirty, isTrue);
  });
}
