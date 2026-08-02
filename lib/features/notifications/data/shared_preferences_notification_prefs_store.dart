import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_prefs.dart';
import '../domain/notification_prefs_store.dart';

/// SharedPreferences-backed implementation of [NotificationPrefsStore].
///
/// The whole preference set is persisted as one JSON object under a single
/// key, so a read/write is atomic per save. A stored payload that is not
/// valid JSON — or not a JSON object — is treated as a miss (returns null),
/// mirroring the locale store's stale-data rejection.
class SharedPreferencesNotificationPrefsStore
    implements NotificationPrefsStore {
  const SharedPreferencesNotificationPrefsStore(this._preferences);

  static const String _prefsKey = 'legalhub.notification_prefs';

  final SharedPreferences _preferences;

  @override
  Future<NotificationPrefs?> read() async {
    final String? raw = _preferences.getString(_prefsKey);
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return NotificationPrefs.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(NotificationPrefs prefs) async {
    await _preferences.setString(_prefsKey, jsonEncode(prefs.toJson()));
  }
}
