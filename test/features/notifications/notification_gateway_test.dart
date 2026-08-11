import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/notifications/data/fake_notification_gateway.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';

void main() {
  group('FakeNotificationGateway.fetchNotifications (D-N7)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeNotificationGateway gateway = FakeNotificationGateway();

      final List<Notification>? first =
          (await gateway.fetchNotifications()).valueOrNull;
      final List<Notification>? second =
          (await gateway.fetchNotifications()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeNotificationGateway.syntheticNotifications);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('rows carry only redacted metadata fields (D-N3 shape)', () async {
      final FakeNotificationGateway gateway = FakeNotificationGateway();

      final List<Notification> notifications =
          (await gateway.fetchNotifications()).valueOrNull!;

      // Every synthetic row exposes the D-N3 surface: id / category / type /
      // synthetic summary / server timestamp / read flag. Metadata only —
      // the string forms must never render user-identity or content shapes
      // (no email/phone/address/raw message text).
      for (final Notification notification in notifications) {
        expect(notification.id, isNotEmpty);
        expect(notification.category, isA<NotificationCategory>());
        expect(notification.type, isNotEmpty);
        expect(notification.summary, startsWith('Demo notification — '));
        expect(notification.summary, isNot(contains('@')));
        expect(notification.toString(), isNot(contains('@')));
        expect(notification.isRead, isA<bool>());
      }
    });

    test('rows are newest-first (the feed order contract)', () {
      final List<Notification> notifications =
          FakeNotificationGateway.syntheticNotifications;

      // AC-1: the feed renders newest-first. The fake is pre-sorted, and the
      // Supabase gateway sorts deterministically — this pins the contract at
      // the source.
      for (int i = 1; i < notifications.length; i++) {
        expect(
          notifications[i - 1].serverTimestamp.isAfter(
            notifications[i].serverTimestamp,
          ),
          isTrue,
          reason: 'row ${notifications[i].id} is not newest-first',
        );
      }
    });

    test('every D-N4 category appears and stays within the CHECK set', () {
      final List<Notification> notifications =
          FakeNotificationGateway.syntheticNotifications;

      // appointment / activity / system only — the exact set the
      // notifications.category CHECK admits (D-N4, the prefs bridge).
      const Set<NotificationCategory> allowed = <NotificationCategory>{
        NotificationCategory.appointment,
        NotificationCategory.activity,
        NotificationCategory.system,
      };
      final Set<NotificationCategory> seen = <NotificationCategory>{};
      for (final Notification notification in notifications) {
        expect(allowed, contains(notification.category));
        seen.add(notification.category);
      }
      // All three categories are represented in the synthetic set.
      expect(seen, allowed);
    });

    test(
      'no delivery language and no read-flag mutation (D-N2/D-N6)',
      () async {
        final FakeNotificationGateway gateway = FakeNotificationGateway();

        final List<Notification> notifications =
            (await gateway.fetchNotifications()).valueOrNull!;

        // "No push" copy rule: no row or string form promises delivery/push.
        // And the fake never mutates is_read — the read flag is display
        // metadata only in v1 (D-N6).
        for (final Notification notification in notifications) {
          expect(
            notification.toString().toLowerCase(),
            isNot(contains('push')),
          );
          expect(
            notification.toString().toLowerCase(),
            isNot(contains('deliver')),
          );
        }
        final List<Notification> again =
            (await gateway.fetchNotifications()).valueOrNull!;
        expect(again, notifications);
      },
    );
  });
}
