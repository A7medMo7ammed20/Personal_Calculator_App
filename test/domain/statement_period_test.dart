import 'package:debt_ledger/domain/period.dart';
import 'package:debt_ledger/domain/statement_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  const fsi = '\u2068', pdi = '\u2069';

  test('wraps each date in bidi isolates, start before end', () {
    final fmt = DateFormat.yMMMd('ar');
    final label = statementPeriodLabel(
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      dateFormat: fmt,
      allTimeLabel: 'كل الوقت',
    );
    expect(fsi.allMatches(label).length, 2);
    expect(pdi.allMatches(label).length, 2);
    final start = fmt.format(DateTime(2026, 7, 1));
    final end = fmt.format(DateTime(2026, 7, 31)); // exclusive end − 1 day
    expect(label, contains('$fsi$start$pdi'));
    expect(label, contains('$fsi$end$pdi'));
    expect(label.indexOf(start), lessThan(label.indexOf(end)));
  });

  test('all-time range renders the plain all-time label', () {
    expect(
      statementPeriodLabel(
        range: null,
        dateFormat: DateFormat.yMMMd('en'),
        allTimeLabel: 'All time',
      ),
      'All time',
    );
  });

  test('printed end is the last included day, not the exclusive end', () {
    final fmt = DateFormat.yMMMd('en');
    final label = statementPeriodLabel(
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      dateFormat: fmt,
      allTimeLabel: 'All time',
    );
    expect(label, contains(fmt.format(DateTime(2026, 7, 31))));
    expect(label, isNot(contains(fmt.format(DateTime(2026, 8, 1)))));
  });
}
