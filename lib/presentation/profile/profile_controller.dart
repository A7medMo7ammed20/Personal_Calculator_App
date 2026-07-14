import 'package:flutter/foundation.dart';

import '../../data/profile_repository.dart';
import '../../domain/profile.dart';

/// Holds the live [Profile] and drives everything that reads it (the Settings
/// editor and the first-export name prompt). A [ChangeNotifier] mirroring
/// `ThemeController`: reads the persisted profile via [load] before the first
/// frame and writes back on every change, so edits survive a restart (and the
/// Backup, ADR 0001).
///
/// After every write it re-reads the canonical [Profile] from the repository, so
/// the "blank name → no profile / blank phone → null" rules live in one place
/// (the repository) rather than being duplicated here.
class ProfileController extends ChangeNotifier {
  ProfileController(this._repo);

  final ProfileRepository _repo;

  Profile? _profile;

  /// The current profile, or `null` when no name has been set yet.
  Profile? get profile => _profile;

  /// Whether a usable creditor name exists — the signal the export prompt reads.
  bool get hasName => _profile != null;

  /// Loads the persisted profile. Call once before the first frame.
  Future<void> load() async {
    _profile = await _repo.profile();
    notifyListeners();
  }

  /// Sets just the name (used by the first-export prompt), keeping any phone.
  Future<void> setName(String name) async {
    await _repo.setName(name);
    _profile = await _repo.profile();
    notifyListeners();
  }

  /// Sets the name and phone together (used by the Settings editor).
  Future<void> save({required String name, String? phone}) async {
    await _repo.setName(name);
    await _repo.setPhone(phone);
    _profile = await _repo.profile();
    notifyListeners();
  }
}
