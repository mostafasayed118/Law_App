import 'package:shared_preferences/shared_preferences.dart';

import 'org_selection_store.dart';

/// SharedPreferences-backed implementation of [OrgSelectionStore].
///
/// Mirrors `SharedPreferencesLocaleStore`: a single key holding the selected
/// organization id. A stored value is returned as-is; no supported-value
/// allow-list exists here because any organization id the user holds a
/// membership for is valid (the id is re-derived from the session before any
/// use — D-08).
class SharedPreferencesOrgSelectionStore implements OrgSelectionStore {
  const SharedPreferencesOrgSelectionStore(this._preferences);

  static const String _orgKey = 'legalhub.activeOrgId';

  final SharedPreferences _preferences;

  @override
  Future<String?> read() async => _preferences.getString(_orgKey);

  @override
  Future<void> write(String organizationId) async {
    await _preferences.setString(_orgKey, organizationId);
  }
}
