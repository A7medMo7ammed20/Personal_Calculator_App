import 'package:flutter/widgets.dart';

import '../../data/settings_repository.dart';
import '../../domain/language_choice.dart';

/// Drives `MaterialApp.locale` from the persisted [LanguageChoice] (ADR 0007),
/// mirroring `ThemeController`. `system` yields a `null` locale (follow the
/// device); `arabic`/`english` force a locale, re-localizing and flipping
/// RTL/LTR live. The non-ar/en → English fallback for the `system` case is
/// handled by the root `localeListResolutionCallback`, not here.
class LocaleController extends ChangeNotifier {
  LocaleController(this._repo);

  final SettingsRepository _repo;

  LanguageChoice _choice = LanguageChoice.defaultChoice;

  LanguageChoice get languageChoice => _choice;

  /// The `MaterialApp.locale` value: `null` for system, else a forced locale.
  Locale? get locale => switch (_choice) {
        LanguageChoice.system => null,
        LanguageChoice.arabic => const Locale('ar'),
        LanguageChoice.english => const Locale('en'),
      };

  /// Loads the persisted choice. Call once before the first frame.
  Future<void> load() async {
    _choice = await _repo.language();
    notifyListeners();
  }

  Future<void> setLanguageChoice(LanguageChoice choice) async {
    if (choice == _choice) return;
    _choice = choice;
    notifyListeners();
    await _repo.setLanguage(choice);
  }
}
