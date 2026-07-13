/// The brightness preference, an axis independent of the [AccentTheme]
/// (ADR 0002). Maps to a Material `ThemeMode` in the presentation layer.
///
/// Pure Dart so it round-trips without the UI.
enum ThemeChoice {
  system('system'),
  light('light'),
  dark('dark');

  const ThemeChoice(this.code);

  /// Stable string persisted in the settings table (e.g. `system`).
  final String code;

  /// The shipped default — follow the OS.
  static const ThemeChoice defaultChoice = ThemeChoice.system;

  /// Parses a persisted [code]. An unknown or missing value degrades to
  /// [defaultChoice] rather than throwing.
  static ThemeChoice fromCode(String? code) {
    for (final choice in values) {
      if (choice.code == code) return choice;
    }
    return defaultChoice;
  }
}
