import 'package:intl/intl.dart';

import '../domain/currency.dart';

/// Formats a positive [magnitude] with its [currency] symbol, e.g. `150.00 ر.س`.
/// Latin digits and two decimals, consistent across locales — direction (sign,
/// colour, label) is carried elsewhere. See CONTEXT.md (Balance display).
String formatMoney(double magnitude, Currency currency) =>
    '${NumberFormat('#,##0.00').format(magnitude)} ${currency.symbol}';
