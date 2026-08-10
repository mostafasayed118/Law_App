import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/shared_preferences_theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('SharedPreferencesThemeModeStore', () {
    test('read returns null when no mode is stored', () async {
      final SharedPreferencesThemeModeStore store =
          SharedPreferencesThemeModeStore(prefs);
      expect(await store.read(), isNull);
    });

    test('write then read round-trips a supported mode', () async {
      final SharedPreferencesThemeModeStore store =
          SharedPreferencesThemeModeStore(prefs);
      await store.write(ThemeMode.dark);
      expect(await store.read(), ThemeMode.dark);
    });

    test('read rejects a stale unsupported name stored externally', () async {
      // Simulate a previously-stored mode that is no longer offered (e.g. a
      // removed value). read() must treat it as a miss, keeping the caller's
      // default (system) instead of surfacing an unknown mode.
      await prefs.setString('legalhub.theme_mode', 'sepia');
      final SharedPreferencesThemeModeStore store =
          SharedPreferencesThemeModeStore(prefs);
      expect(await store.read(), isNull);
    });

    test('read accepts all three supported modes', () async {
      for (final ThemeMode mode in <ThemeMode>[
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      ]) {
        await prefs.setString('legalhub.theme_mode', mode.name);
        final SharedPreferencesThemeModeStore store =
            SharedPreferencesThemeModeStore(prefs);
        expect(await store.read(), mode, reason: 'mode ${mode.name}');
      }
    });
  });
}
