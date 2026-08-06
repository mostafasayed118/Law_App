import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/shared_preferences_org_selection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('SharedPreferencesOrgSelectionStore', () {
    test('read returns null when no org selection is stored', () async {
      final SharedPreferencesOrgSelectionStore store =
          SharedPreferencesOrgSelectionStore(prefs);

      expect(await store.read(), isNull);
    });

    test('write then read round-trips the selected org id', () async {
      final SharedPreferencesOrgSelectionStore store =
          SharedPreferencesOrgSelectionStore(prefs);

      await store.write('org-42');

      expect(await store.read(), 'org-42');
    });

    test('a later write overwrites the previous selection', () async {
      final SharedPreferencesOrgSelectionStore store =
          SharedPreferencesOrgSelectionStore(prefs);

      await store.write('org-1');
      await store.write('org-2');

      expect(await store.read(), 'org-2');
    });

    test('read returns a value stored externally under the same key', () async {
      // Simulate a selection persisted by an earlier launch: the store must
      // restore it (the id is re-derived against the session before any use,
      // so an unknown id is simply not rendered — no allow-list needed).
      await prefs.setString('legalhub.activeOrgId', 'org-7');
      final SharedPreferencesOrgSelectionStore store =
          SharedPreferencesOrgSelectionStore(prefs);

      expect(await store.read(), 'org-7');
    });
  });
}
