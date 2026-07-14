/// The app-language preference (ADR 0007), mirroring [ThemeChoice]. `system`
/// follows the device; `arabic`/`english` force a locale. Pure Dart so it
/// round-trips without the UI. The `arabic`/`english` codes double as the
/// `MaterialApp` locale language codes; the mapping to `Locale?` lives in
/// `LocaleController` to keep this Flutter-free.
enum LanguageChoice {
  system('system'),
  arabic('ar'),
  english('en');

  const LanguageChoice(this.code);

  /// Stable string persisted in the settings table (e.g. `system`).
  final String code;

  /// The shipped default — follow the OS.
  static const LanguageChoice defaultChoice = LanguageChoice.system;

  /// Parses a persisted [code]. An unknown or missing value degrades to
  /// [defaultChoice] rather than throwing.
  static LanguageChoice fromCode(String? code) {
    for (final choice in values) {
      if (choice.code == code) return choice;
    }
    return defaultChoice;
  }
}
