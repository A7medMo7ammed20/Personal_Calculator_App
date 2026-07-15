import 'package:debt_ledger/domain/period.dart';
import 'package:debt_ledger/domain/statement_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('returns start and last-included end, free of bidi isolates', () {
    final fmt = DateFormat.yMMMd('ar');
    final dates = statementPeriodDates(
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      dateFormat: fmt,
    );
    expect(dates, isNotNull);
    expect(dates!.start, fmt.format(DateTime(2026, 7, 1)));
    expect(dates.end, fmt.format(DateTime(2026, 7, 31))); // exclusive end − 1 day

    // No bidi isolates leak into the strings — the PDF font has no glyph for
    // them, so they printed as tofu boxes around each date.
    const fsi = '\u2068', pdi = '\u2069';
    expect(dates.start, isNot(anyOf(contains(fsi), contains(pdi))));
    expect(dates.end, isNot(anyOf(contains(fsi), contains(pdi))));
  });

  test('all-time range returns null (caller shows the all-time label)', () {
    expect(
      statementPeriodDates(range: null, dateFormat: DateFormat.yMMMd('en')),
      isNull,
    );
  });

  test('printed end is the last included day, not the exclusive end', () {
    final fmt = DateFormat.yMMMd('en');
    final dates = statementPeriodDates(
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      dateFormat: fmt,
    );
    expect(dates!.end, fmt.format(DateTime(2026, 7, 31)));
    expect(dates.end, isNot(fmt.format(DateTime(2026, 8, 1))));
  });
}
