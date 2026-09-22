import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs_store.dart';
import 'package:legalhub/features/notifications/domain/visible_notifications.dart';

/// Counts reads, so the D-PF2 contract is pinned rather than merely commented:
/// the store is read **once per load**. The inlined rule this use case
/// replaced read it once per toggle — three reads per load — while its own
/// comment claimed a single read.
class _CountingPrefsStore implements NotificationPrefsStore {
  _CountingPrefsStore(this._prefs);

  final NotificationPrefs? _prefs;
  int reads = 0;

  @override
  Future<NotificationPrefs?> read() async {
    reads++;
    return _prefs;
  }

  @override
  Future<void> write(NotificationPrefs prefs) async {}
}

Notification _row(String id, NotificationCategory category) => Notification(
  id: id,
  category: category,
  type: 'matter_updated',
  summary: 'Synthetic summary',
  serverTimestamp: DateTime.utc(2026, 1, 1),
  isRead: false,
);

void main() {
  group('LoadVisibleNotifications (D-N5/D-PF2/D-PF3, OI-D5.1)', () {
    test('reads the prefs store exactly once per call (D-PF2)', () async {
      final _CountingPrefsStore store = _CountingPrefsStore(
        const NotificationPrefs.defaults(),
      );
      final LoadVisibleNotifications useCase = LoadVisibleNotifications(store);

      await useCase(<Notification>[
        _row('n-1', NotificationCategory.appointment),
        _row('n-2', NotificationCategory.activity),
      ]);

      // Three toggles, one read — the contract the inlined version broke.
      expect(store.reads, 1);
    });

    test('hides the categories whose toggle is off', () async {
      final _CountingPrefsStore store = _CountingPrefsStore(
        const NotificationPrefs(
          appointmentReminders: false,
          activityUpdates: true,
          systemAlerts: true,
        ),
      );
      final LoadVisibleNotifications useCase = LoadVisibleNotifications(store);

      final Result<NotificationVisibility> result =
          await useCase(<Notification>[
            _row('n-1', NotificationCategory.appointment),
            _row('n-2', NotificationCategory.activity),
          ]);

      final NotificationVisibility visibility = result.valueOrNull!;
      expect(visibility.visible.map((Notification n) => n.id), <String>['n-2']);
      expect(visibility.allMuted, isFalse);
    });

    test('reports allMuted when the toggles hide every existing row', () async {
      // The honest-empty distinction (D-PF3): rows existed, every category was
      // muted — which must read differently from "there are no notifications".
      final _CountingPrefsStore store = _CountingPrefsStore(
        const NotificationPrefs(
          appointmentReminders: false,
          activityUpdates: false,
          systemAlerts: false,
        ),
      );
      final LoadVisibleNotifications useCase = LoadVisibleNotifications(store);

      final NotificationVisibility visibility = (await useCase(<Notification>[
        _row('n-1', NotificationCategory.appointment),
      ])).valueOrNull!;

      expect(visibility.visible, isEmpty);
      expect(visibility.allMuted, isTrue);
    });

    test('an empty fetch is NOT allMuted', () async {
      // Nothing exists at all: the plain empty copy, never the muted note.
      final _CountingPrefsStore store = _CountingPrefsStore(
        const NotificationPrefs(
          appointmentReminders: false,
          activityUpdates: false,
          systemAlerts: false,
        ),
      );
      final LoadVisibleNotifications useCase = LoadVisibleNotifications(store);

      final NotificationVisibility visibility = (await useCase(
        const <Notification>[],
      )).valueOrNull!;

      expect(visibility.visible, isEmpty);
      expect(visibility.allMuted, isFalse);
    });

    test(
      'a null store means defaults: every category enabled (AC-4)',
      () async {
        const LoadVisibleNotifications useCase = LoadVisibleNotifications(null);

        final NotificationVisibility visibility = (await useCase(<Notification>[
          _row('n-1', NotificationCategory.appointment),
          _row('n-2', NotificationCategory.system),
        ])).valueOrNull!;

        expect(visibility.visible, hasLength(2));
        expect(visibility.allMuted, isFalse);
      },
    );
  });

  group('NotificationPrefs.isEnabled', () {
    test('maps every category onto its own toggle', () {
      const NotificationPrefs prefs = NotificationPrefs(
        appointmentReminders: true,
        activityUpdates: false,
        systemAlerts: true,
      );

      expect(prefs.isEnabled(NotificationCategory.appointment), isTrue);
      expect(prefs.isEnabled(NotificationCategory.activity), isFalse);
      expect(prefs.isEnabled(NotificationCategory.system), isTrue);
    });
  });
}
