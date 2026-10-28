import 'package:flutter/material.dart';

import 'locale_store.dart';

/// Non-persistent fallback used by tests and environments without preferences.
class InMemoryLocaleStore implements LocaleStore {
  Locale? _locale;

  @override
  Future<Locale?> read() async => _locale;

  @override
  Future<void> write(Locale locale) async => _locale = locale;
}
