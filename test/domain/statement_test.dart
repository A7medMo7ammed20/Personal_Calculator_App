import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/period.dart';
import 'package:debt_ledger/domain/profile.dart';
import 'package:debt_ledger/domain/statement.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(
  double amount,
  Direction direction,
  DateTime when, {
  int id = 0,
  String? description,
}) =>
    Entry(
      id: id,
      contactId: 1,
      amount: amount,
      direction: direction,
      currency: Currency.sar,
      createdAt: when,
      description: description,
    );

const _profile = Profile(name: 'Ahmed', phone: '0555');
const _contact = Contact(id: 1, name: 'Khaled', phone: '0999');

StatementDocument _build(
  List<Entry> entries, {
  DateRange? range,
  bool isRtl = false,
}) =>
    buildStatement(
      profile: _profile,
      contact: _contact,
      entries: entries,
      currency: Currency.sar,
      range: range,
      isRtl: isRtl,
    );

void main() {
  test('carries the header fields from the profile and contact', () {
    final doc = _build([_entry(100, Direction.owedToMe, DateTime(2026, 1, 1))]);

    expect(doc.creditorName, 'Ahmed');
    expect(doc.contactName, 'Khaled');
    expect(doc.contactPhone, '0999');
    expect(doc.currency, Currency.sar);
  });

  test('sets the RTL flag from the argument', () {
    expect(_build(const [], isRtl: true).isRtl, isTrue);
    expect(_build(const [], isRtl: false).isRtl, isFalse);
  });

  test('builds one row per entry, oldest to newest, with a running balance', () {
    // Deliberately out of order to prove the builder sorts ascending.
    final doc = _build([
      _entry(50, Direction.owedByMe, DateTime(2026, 1, 3), id: 2),
      _entry(100, Direction.owedToMe, DateTime(2026, 1, 1), id: 1),
      _entry(20, Direction.owedToMe, DateTime(2026, 1, 5), id: 3),
    ]);

    expect(doc.rows.map((r) => r.date), [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 5),
    ]);
    // Running net balance after each row: +100, +50, +70.
    expect(doc.rows.map((r) => r.balance.signed), [100, 50, 70]);
  });

  test('each row carries its amount on its direction\'s column only', () {
    final doc = _build([
      _entry(100, Direction.owedToMe, DateTime(2026, 1, 1), id: 1),
      _entry(30, Direction.owedByMe, DateTime(2026, 1, 2), id: 2),
    ]);

    expect(doc.rows[0].owedToMe, 100);
    expect(doc.rows[0].owedByMe, isNull);
    expect(doc.rows[1].owedToMe, isNull);
    expect(doc.rows[1].owedByMe, 30);
  });

  test('closing balance is the net all-time position; totals are gross', () {
    final doc = _build([
      _entry(100, Direction.owedToMe, DateTime(2026, 1, 1), id: 1),
      _entry(30, Direction.owedByMe, DateTime(2026, 1, 2), id: 2),
      _entry(50, Direction.owedToMe, DateTime(2026, 1, 3), id: 3),
    ]);

    expect(doc.closingBalance.signed, 120); // 100 - 30 + 50
    expect(doc.totalOwedToMe, 150); // 100 + 50 gross
    expect(doc.totalOwedByMe, 30);
    expect(doc.openingBalance.signed, 0); // all time
  });

  test('an empty ledger yields no rows and a settled zero balance', () {
    final doc = _build(const []);

    expect(doc.rows, isEmpty);
    expect(doc.openingBalance.signed, 0);
    expect(doc.closingBalance.signed, 0);
    expect(doc.closingBalance.isSettled, isTrue);
    expect(doc.totalOwedToMe, 0);
    expect(doc.totalOwedByMe, 0);
  });

  group('date range', () {
    // Jun 1 +100 -> 100 | Jun 15 -30 -> 70 | Jul 5 +50 -> 120 | Jul 20 -20 -> 100
    final entries = [
      _entry(100, Direction.owedToMe, DateTime(2026, 6, 1), id: 1),
      _entry(30, Direction.owedByMe, DateTime(2026, 6, 15), id: 2),
      _entry(50, Direction.owedToMe, DateTime(2026, 7, 5), id: 3),
      _entry(20, Direction.owedByMe, DateTime(2026, 7, 20), id: 4),
    ];
    final july = DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1));

    test('clips rows to the range but carries in the opening balance', () {
      final doc = _build(entries, range: july);

      // Only July rows are shown...
      expect(doc.rows.map((r) => r.date), [
        DateTime(2026, 7, 5),
        DateTime(2026, 7, 20),
      ]);
      // ...opening carries June's closing position (70), never recomputed to 0.
      expect(doc.openingBalance.signed, 70);
      // The running balance continues the true all-time series.
      expect(doc.rows.map((r) => r.balance.signed), [120, 100]);
      expect(doc.closingBalance.signed, 100);
    });

    test('totals cover only the in-range activity', () {
      final doc = _build(entries, range: july);

      expect(doc.totalOwedToMe, 50); // only Jul 5
      expect(doc.totalOwedByMe, 20); // only Jul 20
      // opening + period activity == closing
      expect(
        doc.openingBalance.signed + (doc.totalOwedToMe - doc.totalOwedByMe),
        doc.closingBalance.signed,
      );
    });

    test('a range with no in-range entries has opening == closing, no rows', () {
      final august = DateRange(DateTime(2026, 8, 1), DateTime(2026, 9, 1));
      final doc = _build(entries, range: august);

      expect(doc.rows, isEmpty);
      expect(doc.openingBalance.signed, 100); // all four entries precede August
      expect(doc.closingBalance.signed, 100);
      expect(doc.totalOwedToMe, 0);
      expect(doc.totalOwedByMe, 0);
    });

    test('records the range on the document', () {
      final doc = _build(entries, range: july);
      expect(doc.dateRange, july);
    });
  });
}
