import 'package:flutter/material.dart';

import 'theme_mode_store.dart';

/// Non-persistent fallback used by tests and environments without
/// preferences (the InMemoryLocaleStore pattern).
class InMemoryThemeModeStore implements ThemeModeStore {
  ThemeMode? _mode;

  @override
  Future<ThemeMode?> read() async => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}
