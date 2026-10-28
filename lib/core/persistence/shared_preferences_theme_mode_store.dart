import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_mode_store.dart';

/// SharedPreferences-backed implementation of [ThemeModeStore].
///
/// Persists the [ThemeMode.name] under a single key, mirroring
/// `SharedPreferencesLocaleStore`. An unknown stored value (a mode removed
/// in a future release) is treated as a miss — the caller keeps the
/// default (system) instead of erroring.
class SharedPreferencesThemeModeStore implements ThemeModeStore {
  const SharedPreferencesThemeModeStore(this._preferences);

  static const String _themeModeKey = 'legalhub.theme_mode';
  final SharedPreferences _preferences;

  @override
  Future<ThemeMode?> read() async {
    final String? name = _preferences.getString(_themeModeKey);
    if (name == null || !supportedThemeModes.contains(name)) {
      return null;
    }
    return ThemeMode.values.firstWhere(
      (ThemeMode mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> write(ThemeMode mode) async {
    await _preferences.setString(_themeModeKey, mode.name);
  }
}
