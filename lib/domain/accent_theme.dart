/// The user-switchable brand accents. The accent themes the app *chrome* only
/// (via `ColorScheme.fromSeed`); the money semantics are fixed and live in
/// `AppSemanticColors`. See
/// [ADR 0002](../../docs/adr/0002-design-system-and-switchable-accent-themes.md)
/// and [docs/design-system.md](../../docs/design-system.md).
///
/// Pure Dart with no Flutter dependency (like [Currency]) so the choice stays
/// testable without the UI. [seedValue] is a 32-bit ARGB int; the theme layer
/// wraps it in a `Color`.
enum AccentTheme {
  teal('teal', 0xFF14746F),
  indigo('indigo', 0xFF3538CD),
  plum('plum', 0xFF6D28D9),
  ocean('ocean', 0xFF0369A1);

  const AccentTheme(this.code, this.seedValue);

  /// Stable string persisted in the settings table (e.g. `teal`).
  final String code;

  /// The seed colour as a 32-bit ARGB int (e.g. `0xFF14746F`).
  final int seedValue;

  /// The shipped default — baked into the launcher icon and splash.
  static const AccentTheme defaultAccent = AccentTheme.teal;

  /// Parses a persisted [code] back into an [AccentTheme]. Unlike [Currency],
  /// an unknown or missing value degrades to [defaultAccent] rather than
  /// throwing — a corrupt preference must never crash startup.
  static AccentTheme fromCode(String? code) {
    for (final accent in values) {
      if (accent.code == code) return accent;
    }
    return defaultAccent;
  }
}
