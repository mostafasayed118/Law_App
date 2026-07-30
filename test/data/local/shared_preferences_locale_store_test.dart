import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/shared_preferences_locale_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('SharedPreferencesLocaleStore', () {
    test('read returns null when no locale is stored', () async {
      final SharedPreferencesLocaleStore store = SharedPreferencesLocaleStore(
        prefs,
      );
      expect(await store.read(), isNull);
    });

    test('write then read round-trips a supported locale code', () async {
      final SharedPreferencesLocaleStore store = SharedPreferencesLocaleStore(
        prefs,
      );
      await store.write(const Locale('ar'));
      expect(await store.read(), const Locale('ar'));
    });

    test('read rejects a stale unsupported code stored externally', () async {
      // Simulate a previously-stored code that is no longer in
      // supportedLocaleCodes (e.g. 'fr'). read() must treat it as a miss
      // rather than returning an unsupported Locale.
      await prefs.setString('legalhub.locale', 'fr');
      final SharedPreferencesLocaleStore store = SharedPreferencesLocaleStore(
        prefs,
      );
      expect(await store.read(), isNull);
    });

    test('read accepts all three supported codes', () async {
      for (final String code in <String>['en', 'ar', 'tr']) {
        await prefs.setString('legalhub.locale', code);
        final SharedPreferencesLocaleStore store = SharedPreferencesLocaleStore(
          prefs,
        );
        expect(await store.read(), Locale(code), reason: 'code $code');
      }
    });
  });
}
