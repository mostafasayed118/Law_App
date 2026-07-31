import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';

void main() {
  group('LocaleCubit initial state', () {
    test('starts at the default English locale', () {
      final LocaleCubit cubit = LocaleCubit(InMemoryLocaleStore());
      addTearDown(cubit.close);

      expect(cubit.state.locale, const Locale('en'));
    });
  });

  group('LocaleCubit load', () {
    blocTest<LocaleCubit, LocaleState>(
      'emits nothing when no locale is saved',
      build: () => LocaleCubit(InMemoryLocaleStore()),
      act: (LocaleCubit cubit) => cubit.load(),
      expect: () => <LocaleState>[],
    );

    blocTest<LocaleCubit, LocaleState>(
      'emits the saved locale when one is present',
      setUp: () => _seededStore = _SeededLocaleStore(const Locale('ar')),
      build: () => LocaleCubit(_seededStore),
      act: (LocaleCubit cubit) => cubit.load(),
      expect: () => <LocaleState>[const LocaleState(Locale('ar'))],
    );
  });

  group('LocaleCubit setLocale', () {
    blocTest<LocaleCubit, LocaleState>(
      'emits the new locale when it is supported',
      build: () => LocaleCubit(InMemoryLocaleStore()),
      act: (LocaleCubit cubit) => cubit.setLocale(const Locale('ar')),
      expect: () => <LocaleState>[const LocaleState(Locale('ar'))],
    );

    blocTest<LocaleCubit, LocaleState>(
      'emits nothing when the locale is unsupported and stays at the current '
      'locale',
      build: () => LocaleCubit(InMemoryLocaleStore()),
      act: (LocaleCubit cubit) => cubit.setLocale(const Locale('fr')),
      // An empty emission stream proves the guard returned early. The
      // current state is unchanged at 'en' (the initial state); the stream
      // assertion is the load-bearing check, the state read is the
      // belt-and-braces check.
      expect: () => <LocaleState>[],
      verify: (LocaleCubit cubit) {
        expect(cubit.state.locale, const Locale('en'));
      },
    );
  });
}

// Holds the seeded store across the blocTest build/verify boundary.
late _SeededLocaleStore _seededStore;

/// An InMemoryLocaleStore variant seeded with a locale so load() has something
/// to return, exercising the emit path rather than the no-emit path.
class _SeededLocaleStore extends InMemoryLocaleStore {
  _SeededLocaleStore(this._initial);

  final Locale _initial;

  @override
  Future<Locale?> read() async => _initial;
}
