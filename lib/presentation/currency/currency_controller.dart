import 'package:flutter/foundation.dart';

import '../../data/settings_repository.dart';
import '../../domain/currency.dart';

/// Holds the live currency lens (ADR 0007), mirroring `ThemeController`.
///
/// [active] is the lens the app is currently showing; [defaultCurrency] is the
/// persisted launch default. Both are seeded from the persisted default at
/// startup ([load]). The bottom tabs call [setActive] — a transient view change
/// that never rewrites the default; Settings calls [setDefault] — which
/// live-switches the active lens *and* persists it. So the two can diverge
/// within a session and re-converge on the next launch.
class CurrencyController extends ChangeNotifier {
  CurrencyController(this._repo);

  final SettingsRepository _repo;

  Currency _active = Currency.defaultCurrency;
  Currency _default = Currency.defaultCurrency;

  Currency get active => _active;
  Currency get defaultCurrency => _default;

  /// Loads the persisted default and opens the active lens on it. Call once
  /// before the first frame.
  Future<void> load() async {
    _default = await _repo.defaultCurrency();
    _active = _default;
    notifyListeners();
  }

  /// Moves the active lens for this session only (bottom tabs). Never persists.
  void setActive(Currency currency) {
    if (currency == _active) return;
    _active = currency;
    notifyListeners();
  }

  /// Sets the launch default *and* live-switches the active lens (Settings).
  Future<void> setDefault(Currency currency) async {
    if (currency == _default && currency == _active) return;
    _default = currency;
    _active = currency;
    notifyListeners();
    await _repo.setDefaultCurrency(currency);
  }
}
