/// The two currencies the ledger supports. See CONTEXT.md — currency is a
/// global *lens*; the two are never summed together.
///
/// This is pure Dart with no Flutter dependency so money logic stays testable
/// without the UI.
enum Currency {
  /// Saudi Riyal.
  sar('SAR', 'ر.س'),

  /// Yemeni Riyal.
  yer('YER', 'ر.ي');

  const Currency(this.code, this.symbol);

  /// ISO-style code persisted in the database (e.g. `SAR`).
  final String code;

  /// Short symbol shown in the UI (e.g. `ر.س`).
  final String symbol;

  /// Parses a persisted [code] back into a [Currency].
  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => throw ArgumentError.value(code, 'code', 'Unknown currency'),
    );
  }
}
