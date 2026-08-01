import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/notifications/data/in_memory_notification_prefs_store.dart';
import 'package:legalhub/features/notifications/data/shared_preferences_notification_prefs_store.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryNotificationPrefsStore', () {
    test('read returns null before any write', () async {
      final InMemoryNotificationPrefsStore store =
          InMemoryNotificationPrefsStore();
      expect(await store.read(), isNull);
    });

    test('write then read round-trips the preference set', () async {
      final InMemoryNotificationPrefsStore store =
          InMemoryNotificationPrefsStore();
      const NotificationPrefs prefs = NotificationPrefs(
        appointmentReminders: false,
        activityUpdates: true,
        systemAlerts: false,
      );
      await store.write(prefs);
      expect(await store.read(), prefs);
    });
  });

  group('SharedPreferencesNotificationPrefsStore', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    test('read returns null when nothing is stored', () async {
      final SharedPreferencesNotificationPrefsStore store =
          SharedPreferencesNotificationPrefsStore(prefs);
      expect(await store.read(), isNull);
    });

    test('write then read round-trips the preference set', () async {
      final SharedPreferencesNotificationPrefsStore store =
          SharedPreferencesNotificationPrefsStore(prefs);
      const NotificationPrefs value = NotificationPrefs(
        appointmentReminders: false,
        activityUpdates: false,
        systemAlerts: true,
      );
      await store.write(value);
      expect(await store.read(), value);
    });

    test('read rejects a malformed payload stored externally', () async {
      await prefs.setString('legalhub.notification_prefs', 'not-json{');
      final SharedPreferencesNotificationPrefsStore store =
          SharedPreferencesNotificationPrefsStore(prefs);
      expect(await store.read(), isNull);
    });

    test('read rejects a payload that is not a JSON object', () async {
      await prefs.setString('legalhub.notification_prefs', '[1, 2, 3]');
      final SharedPreferencesNotificationPrefsStore store =
          SharedPreferencesNotificationPrefsStore(prefs);
      expect(await store.read(), isNull);
    });

    test('a partial payload falls back to enabled for missing keys', () async {
      await prefs.setString(
        'legalhub.notification_prefs',
        '{"appointmentReminders":false}',
      );
      final SharedPreferencesNotificationPrefsStore store =
          SharedPreferencesNotificationPrefsStore(prefs);
      final NotificationPrefs? read = await store.read();
      expect(read, isNotNull);
      expect(read!.appointmentReminders, isFalse);
      expect(read.activityUpdates, isTrue);
      expect(read.systemAlerts, isTrue);
    });
  });
}
