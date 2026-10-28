import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_store.dart';

class SharedPreferencesLocaleStore implements LocaleStore {
  const SharedPreferencesLocaleStore(this._preferences);

  static const String _localeKey = 'legalhub.locale';
  final SharedPreferences _preferences;

  @override
  Future<Locale?> read() async {
    final String? code = _preferences.getString(_localeKey);
    if (code == null || !supportedLocaleCodes.contains(code)) {
      return null;
    }
    return Locale(code);
  }

  @override
  Future<void> write(Locale locale) async {
    await _preferences.setString(_localeKey, locale.languageCode);
  }
}
