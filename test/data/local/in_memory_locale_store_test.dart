import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';

// InMemoryLocaleStore is the non-persistent fallback used by tests and
// preference-less environments (see the class doc). These tests pin its
// read/write contract in isolation; the persistent sibling is covered by
// shared_preferences_locale_store_test.dart.
void main() {
  group('InMemoryLocaleStore', () {
    test('read returns null before any write', () async {
      final InMemoryLocaleStore store = InMemoryLocaleStore();

      expect(await store.read(), isNull);
    });

    test('write then read round-trips the locale', () async {
      final InMemoryLocaleStore store = InMemoryLocaleStore();

      await store.write(const Locale('ar'));

      expect(await store.read(), const Locale('ar'));
    });

    test('a later write overwrites the previous locale', () async {
      final InMemoryLocaleStore store = InMemoryLocaleStore();

      await store.write(const Locale('en'));
      await store.write(const Locale('tr'));

      expect(await store.read(), const Locale('tr'));
    });
  });
}
