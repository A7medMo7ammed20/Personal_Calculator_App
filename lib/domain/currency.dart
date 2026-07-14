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

  /// The shipped default lens/seed. The settings path degrades to this rather
  /// than throwing (ADR 0007).
  static const Currency defaultCurrency = Currency.sar;

  /// Parses a persisted [code], degrading to [defaultCurrency] on an unknown or
  /// missing value. Use this for the `default_currency` setting; [fromCode]
  /// (which throws) stays reserved for trusted entry-row codes.
  static Currency fromCodeOrDefault(String? code) {
    for (final currency in values) {
      if (currency.code == code) return currency;
    }
    return defaultCurrency;
  }
}
