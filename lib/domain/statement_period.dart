import 'package:intl/intl.dart';

import 'period.dart';

/// The formatted `start` and `end` dates of a statement's period (ADR 0009), or
/// null for an all-time [range]. `end` is the last *included* day
/// (`endExclusive − 1 day`). Pure — no PDF, unit-testable.
///
/// Each date is returned as a standalone string so the renderer can place it in
/// its own text run. That keeps the mix of Latin digits and Arabic month names
/// ordered under RTL without the bidi-isolate characters (FSI/PDI) the earlier
/// combined label used: the PDF fonts have no glyph for those isolates, so they
/// printed as tofu boxes around every date.
({String start, String end})? statementPeriodDates({
  required DateRange? range,
  required DateFormat dateFormat,
}) {
  if (range == null) return null;
  return (
    start: dateFormat.format(range.start),
    end: dateFormat.format(
      range.endExclusive.subtract(const Duration(days: 1)),
    ),
  );
}
