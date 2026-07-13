import 'package:flutter/material.dart';

import '../../data/settings_repository.dart';
import '../../domain/accent_theme.dart';
import '../../domain/theme_choice.dart';

/// Holds the live accent + brightness choices and drives the root `MaterialApp`.
///
/// A [ChangeNotifier] so the app rebuilds when either changes. Reads the stored
/// choices via [SettingsRepository.load] at startup and writes them back on every
/// change, so a switch survives a restart (and the Backup, ADR 0002).
class ThemeController extends ChangeNotifier {
  ThemeController(this._repo);

  final SettingsRepository _repo;

  AccentTheme _accent = AccentTheme.defaultAccent;
  ThemeChoice _themeChoice = ThemeChoice.defaultChoice;

  AccentTheme get accent => _accent;
  ThemeChoice get themeChoice => _themeChoice;

  /// The accent seed as a `Color`, ready for `ColorScheme.fromSeed`.
  Color get seed => Color(_accent.seedValue);

  /// The brightness choice as a Material [ThemeMode].
  ThemeMode get themeMode => switch (_themeChoice) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      };

  /// Loads the persisted choices. Call once before the first frame.
  Future<void> load() async {
    _accent = await _repo.accent();
    _themeChoice = await _repo.themeChoice();
    notifyListeners();
  }

  Future<void> setAccent(AccentTheme accent) async {
    if (accent == _accent) return;
    _accent = accent;
    notifyListeners();
    await _repo.setAccent(accent);
  }

  Future<void> setThemeChoice(ThemeChoice choice) async {
    if (choice == _themeChoice) return;
    _themeChoice = choice;
    notifyListeners();
    await _repo.setThemeChoice(choice);
  }
}
