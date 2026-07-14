import 'package:debt_ledger/data/app_database.dart';
import 'package:debt_ledger/data/settings_repository.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/presentation/currency/currency_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDb;
  late SettingsRepository repo;
  late CurrencyController controller;

  setUp(() {
    appDb = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = SettingsRepository(appDb);
    controller = CurrencyController(repo);
  });

  tearDown(() => appDb.close());

  test('defaults active and default to SAR before load', () {
    expect(controller.active, Currency.sar);
    expect(controller.defaultCurrency, Currency.sar);
  });

  test('load seeds both active and default from the persisted default', () async {
    await repo.setDefaultCurrency(Currency.yer);
    await controller.load();
    expect(controller.defaultCurrency, Currency.yer);
    expect(controller.active, Currency.yer);
  });

  test('setActive moves the active lens only, never the default or the store',
      () async {
    await controller.load(); // default SAR
    controller.setActive(Currency.yer);
    expect(controller.active, Currency.yer);
    expect(controller.defaultCurrency, Currency.sar);
    expect(await repo.defaultCurrency(), Currency.sar); // not persisted
  });

  test('setDefault live-switches the active lens and persists', () async {
    await controller.load();
    await controller.setDefault(Currency.yer);
    expect(controller.defaultCurrency, Currency.yer);
    expect(controller.active, Currency.yer);
    expect(await repo.defaultCurrency(), Currency.yer);
  });

  test('notifies on setActive and setDefault', () async {
    await controller.load();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.setActive(Currency.yer);
    await controller.setDefault(Currency.sar);
    expect(notifications, greaterThanOrEqualTo(2));
  });
}
