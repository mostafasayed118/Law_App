import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs.dart';

void main() {
  group('NotificationPrefs', () {
    test('defaults enable every category', () {
      const NotificationPrefs prefs = NotificationPrefs.defaults();
      expect(prefs.appointmentReminders, isTrue);
      expect(prefs.activityUpdates, isTrue);
      expect(prefs.systemAlerts, isTrue);
    });

    test('copyWith changes only the requested fields', () {
      const NotificationPrefs prefs = NotificationPrefs.defaults();
      final NotificationPrefs updated = prefs.copyWith(
        appointmentReminders: false,
      );
      expect(updated.appointmentReminders, isFalse);
      expect(updated.activityUpdates, isTrue);
      expect(updated.systemAlerts, isTrue);
    });

    test('toJson/fromJson round-trips every field', () {
      const NotificationPrefs prefs = NotificationPrefs(
        appointmentReminders: false,
        activityUpdates: true,
        systemAlerts: false,
      );
      final NotificationPrefs restored = NotificationPrefs.fromJson(
        prefs.toJson(),
      );
      expect(restored, prefs);
    });

    test('fromJson falls back to enabled for missing or unknown keys', () {
      final NotificationPrefs restored = NotificationPrefs.fromJson(
        <String, Object?>{'activityUpdates': false},
      );
      expect(restored.appointmentReminders, isTrue);
      expect(restored.activityUpdates, isFalse);
      expect(restored.systemAlerts, isTrue);
    });
  });
}
