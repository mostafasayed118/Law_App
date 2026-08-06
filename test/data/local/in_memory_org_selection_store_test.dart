import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/local/in_memory_org_selection_store.dart';

// InMemoryOrgSelectionStore is the non-persistent fallback used by tests and
// preference-less environments (see the class doc). These tests pin its
// read/write contract in isolation; the persistent sibling is covered by
// shared_preferences_org_selection_store_test.dart.
void main() {
  group('InMemoryOrgSelectionStore', () {
    test('read returns null before any write', () async {
      final InMemoryOrgSelectionStore store = InMemoryOrgSelectionStore();

      expect(await store.read(), isNull);
    });

    test('write then read round-trips the org id', () async {
      final InMemoryOrgSelectionStore store = InMemoryOrgSelectionStore();

      await store.write('org-1');

      expect(await store.read(), 'org-1');
    });

    test('a later write overwrites the previous selection', () async {
      final InMemoryOrgSelectionStore store = InMemoryOrgSelectionStore();

      await store.write('org-1');
      await store.write('org-2');

      expect(await store.read(), 'org-2');
    });
  });
}
