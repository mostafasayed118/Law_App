import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';

// InMemoryThemeModeStore is the non-persistent fallback used by tests and
// preference-less environments (the InMemoryLocaleStore pattern). These
// tests pin its read/write contract in isolation; the persistent sibling is
// covered by shared_preferences_theme_mode_store_test.dart.
void main() {
  group('InMemoryThemeModeStore', () {
    test('read returns null before any write', () async {
      final InMemoryThemeModeStore store = InMemoryThemeModeStore();

      expect(await store.read(), isNull);
    });

    test('write then read round-trips the mode', () async {
      final InMemoryThemeModeStore store = InMemoryThemeModeStore();

      await store.write(ThemeMode.dark);

      expect(await store.read(), ThemeMode.dark);
    });

    test('a later write overwrites the previous mode', () async {
      final InMemoryThemeModeStore store = InMemoryThemeModeStore();

      await store.write(ThemeMode.system);
      await store.write(ThemeMode.light);

      expect(await store.read(), ThemeMode.light);
    });
  });
}
