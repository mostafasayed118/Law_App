import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';

void main() {
  group('ThemeCubit initial state', () {
    test('starts at the system default', () {
      final ThemeCubit cubit = ThemeCubit(InMemoryThemeModeStore());
      addTearDown(cubit.close);

      expect(cubit.state, ThemeMode.system);
    });
  });

  group('ThemeCubit load', () {
    blocTest<ThemeCubit, ThemeMode>(
      'emits nothing when no mode is saved',
      build: () => ThemeCubit(InMemoryThemeModeStore()),
      act: (ThemeCubit cubit) => cubit.load(),
      expect: () => <ThemeMode>[],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'emits the saved mode when one is present',
      setUp: () => _seededStore = _SeededThemeModeStore(ThemeMode.dark),
      build: () => ThemeCubit(_seededStore),
      act: (ThemeCubit cubit) => cubit.load(),
      expect: () => <ThemeMode>[ThemeMode.dark],
    );
  });

  group('ThemeCubit setThemeMode', () {
    blocTest<ThemeCubit, ThemeMode>(
      'persists and emits the new mode',
      build: () => ThemeCubit(InMemoryThemeModeStore()),
      act: (ThemeCubit cubit) => cubit.setThemeMode(ThemeMode.light),
      expect: () => <ThemeMode>[ThemeMode.light],
    );

    test(
      'the chosen mode is written to the store (survives restart)',
      () async {
        final InMemoryThemeModeStore store = InMemoryThemeModeStore();
        final ThemeCubit cubit = ThemeCubit(store);
        addTearDown(cubit.close);

        await cubit.setThemeMode(ThemeMode.dark);
        await cubit.close();

        // A fresh cubit over the same store (the app-restart equivalent)
        // restores the persisted choice on load.
        final ThemeCubit restarted = ThemeCubit(store);
        addTearDown(restarted.close);
        await restarted.load();

        expect(restarted.state, ThemeMode.dark);
      },
    );
  });
}

late _SeededThemeModeStore _seededStore;

/// An InMemoryThemeModeStore variant seeded with a mode so load() has
/// something to return, exercising the emit path rather than the no-emit
/// path (the _SeededLocaleStore pattern).
class _SeededThemeModeStore extends InMemoryThemeModeStore {
  _SeededThemeModeStore(this._initial);

  final ThemeMode _initial;

  @override
  Future<ThemeMode?> read() async => _initial;
}
