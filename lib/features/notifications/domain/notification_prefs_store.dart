import 'notification_prefs.dart';

/// Persistence seam for device-local notification preferences.
///
/// Mirrors the locale-store pattern (`lib/data/local/locale_store.dart`):
/// the production implementation writes to SharedPreferences, the in-memory
/// implementation backs tests and env-less runs.
abstract interface class NotificationPrefsStore {
  Future<NotificationPrefs?> read();
  Future<void> write(NotificationPrefs prefs);
}
