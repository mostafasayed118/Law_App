import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/theme_mode_store.dart';

/// App-scoped controller for the user-selected theme mode.
///
/// Mirrors [LocaleCubit]: state is the plain [ThemeMode] (light / dark /
/// system), persisted via [ThemeModeStore] so the choice survives app
/// restarts. `load()` runs at bootstrap before the first frame (the
/// LocaleCubit pattern); `setThemeMode()` persists then emits, so the
/// MaterialApp's `themeMode` flips live without a restart.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._store) : super(ThemeMode.system);

  final ThemeModeStore _store;

  Future<void> load() async {
    final ThemeMode? saved = await _store.read();
    if (saved != null && !isClosed) {
      emit(saved);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _store.write(mode);
    if (!isClosed) {
      emit(mode);
    }
  }
}
