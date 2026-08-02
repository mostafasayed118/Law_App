import '../domain/notification_prefs.dart';
import '../domain/notification_prefs_store.dart';

/// Non-persistent fallback used by tests and environments without
/// preferences. Mirrors `InMemoryLocaleStore`.
class InMemoryNotificationPrefsStore implements NotificationPrefsStore {
  NotificationPrefs? _prefs;

  @override
  Future<NotificationPrefs?> read() async => _prefs;

  @override
  Future<void> write(NotificationPrefs prefs) async => _prefs = prefs;
}
