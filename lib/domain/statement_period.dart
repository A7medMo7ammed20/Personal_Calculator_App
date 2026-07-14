import 'package:intl/intl.dart';

import 'period.dart';

const String _fsi = '\u2068'; // First Strong Isolate
const String _pdi = '\u2069'; // Pop Directional Isolate

/// Formats a statement's period value (ADR 0009). Each date is wrapped in bidi
/// isolates so the mix of Latin digits, Arabic month names and the neutral dash
/// never reorders under RTL, and the pair always reads start-then-end. Returns
/// [allTimeLabel] for a null (all-time) [range]. Pure — no PDF, unit-testable.
String statementPeriodLabel({
  required DateRange? range,
  required DateFormat dateFormat,
  required String allTimeLabel,
}) {
  if (range == null) return allTimeLabel;
  final start = dateFormat.format(range.start);
  final end = dateFormat.format(
    range.endExclusive.subtract(const Duration(days: 1)),
  );
  return '$_fsi$start$_pdi – $_fsi$end$_pdi';
}
