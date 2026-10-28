import 'package:flutter/material.dart';

/// Persistence contract for the user-selected theme mode.
///
/// Mirrors [LocaleStore]: the store owns persistence only; the theme cubit
/// owns the in-memory state and the app restart `load()`.
abstract interface class ThemeModeStore {
  Future<ThemeMode?> read();
  Future<void> write(ThemeMode mode);
}

/// The theme modes the app offers the user. Persisted by name; unknown
/// stored names are rejected on read (stale-data discipline, LocaleStore
/// pattern).
const Set<String> supportedThemeModes = <String>{'light', 'dark', 'system'};
