import 'org_selection_store.dart';

/// Non-persistent fallback used by tests and environments without
/// preferences. Mirrors `InMemoryLocaleStore`.
class InMemoryOrgSelectionStore implements OrgSelectionStore {
  String? _organizationId;

  @override
  Future<String?> read() async => _organizationId;

  @override
  Future<void> write(String organizationId) async =>
      _organizationId = organizationId;
}
