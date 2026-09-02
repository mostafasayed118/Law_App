import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/notifications/supabase_notification_api.dart';
import 'package:legalhub/data/notifications/supabase_notification_gateway.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';

/// Hand-rolled fake of the [SupabaseNotificationApi] seam: records calls and
/// answers with canned rows or a [SupabaseNotificationException], so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabaseNotificationApi implements SupabaseNotificationApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseNotificationException? error;
  SupabaseNotificationException? markError;
  int markResult = 0;
  List<String>? markCallIds;

  @override
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    if (error != null) {
      throw error!;
    }
    return rows;
  }

  @override
  Future<int> markNotificationsRead(List<String> ids) async {
    markCallIds = ids;
    if (markError != null) {
      throw markError!;
    }
    return markResult;
  }
}

Map<String, dynamic> _row({
  String id = 'notification-1',
  String category = 'activity',
  String type = 'matter_updated',
  String summary = 'Demo notification — matter status update',
  DateTime? serverTimestamp,
  bool isRead = false,
}) => <String, dynamic>{
  'id': id,
  'category': category,
  'type': type,
  'summary': summary,
  'server_timestamp': serverTimestamp ?? DateTime.utc(2026, 7, 18, 14, 5),
  'is_read': isRead,
};

void main() {
  late _StubSupabaseNotificationApi api;
  late SupabaseNotificationGateway gateway;

  setUp(() {
    api = _StubSupabaseNotificationApi();
    gateway = SupabaseNotificationGateway(api);
  });

  group('row → Notification mapping (D-N3)', () {
    test('maps a full row to the Notification VO', () async {
      api.rows = <Map<String, dynamic>>[_row()];

      final Result<List<Notification>> result = await gateway
          .fetchNotifications();

      expect(result.isSuccess, isTrue);
      final Notification notification = result.valueOrNull!.single;
      expect(notification.id, 'notification-1');
      expect(notification.category, NotificationCategory.activity);
      expect(notification.type, 'matter_updated');
      expect(notification.summary, 'Demo notification — matter status update');
      expect(notification.serverTimestamp, DateTime.utc(2026, 7, 18, 14, 5));
      expect(notification.isRead, isFalse);
    });

    test('maps every D-N4 category string to its enum', () async {
      api.rows = <Map<String, dynamic>>[
        _row(
          id: 'a',
          category: 'appointment',
          serverTimestamp: DateTime.utc(2026, 7, 1),
        ),
        _row(
          id: 'b',
          category: 'activity',
          serverTimestamp: DateTime.utc(2026, 7, 20),
        ),
        _row(
          id: 'c',
          category: 'system',
          serverTimestamp: DateTime.utc(2026, 7, 10),
        ),
      ];

      final List<Notification> notifications =
          (await gateway.fetchNotifications()).valueOrNull!;

      // Newest-first (the sort contract), and every category mapped.
      expect(notifications.map((Notification n) => n.id), <String>[
        'b',
        'c',
        'a',
      ]);
      expect(
        notifications.map((Notification n) => n.category),
        <NotificationCategory>[
          NotificationCategory.activity,
          NotificationCategory.system,
          NotificationCategory.appointment,
        ],
      );
    });

    test('sorts rows newest-first (the feed order contract)', () async {
      api.rows = <Map<String, dynamic>>[
        _row(id: 'old', serverTimestamp: DateTime.utc(2026, 7, 1)),
        _row(id: 'new', serverTimestamp: DateTime.utc(2026, 7, 20)),
        _row(id: 'mid', serverTimestamp: DateTime.utc(2026, 7, 10)),
      ];

      final List<Notification> notifications =
          (await gateway.fetchNotifications()).valueOrNull!;

      expect(notifications.map((Notification n) => n.id), <String>[
        'new',
        'mid',
        'old',
      ]);
    });

    test('an unmapped category is provider drift → loud failure', () async {
      api.rows = <Map<String, dynamic>>[_row(category: 'reminder')];

      final Result<List<Notification>> result = await gateway
          .fetchNotifications();

      expect(result.isSuccess, isFalse);
      final AppError error = result.errorOrNull!;
      expect(error.code, 'notification_read_failed');
      expect(error.userMessage, contains('Unable to load notifications'));
    });

    test('a missing summary is provider drift → loud failure', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{..._row(), 'summary': ''},
      ];

      final Result<List<Notification>> result = await gateway
          .fetchNotifications();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull!.code, 'notification_read_failed');
    });

    test(
      'a non-DateTime server_timestamp is provider drift → loud failure',
      () async {
        api.rows = <Map<String, dynamic>>[
          <String, dynamic>{..._row(), 'server_timestamp': '2026-07-18'},
        ];

        final Result<List<Notification>> result = await gateway
            .fetchNotifications();

        expect(result.isSuccess, isFalse);
        expect(result.errorOrNull!.code, 'notification_read_failed');
      },
    );
  });

  group('failure mapping (D-N3)', () {
    test('denied maps to notification_read_denied', () async {
      api.error = const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.denied,
        message: 'permission denied for table notifications',
      );

      final AppError error = (await gateway.fetchNotifications()).errorOrNull!;

      expect(error.code, 'notification_read_denied');
      expect(error.userMessage, contains('permission to view'));
    });

    test(
      'provider unavailable maps to notification_read_unavailable',
      () async {
        api.error = const SupabaseNotificationException(
          kind: SupabaseNotificationFailureKind.providerUnavailable,
          message: 'timeout',
        );

        final AppError error =
            (await gateway.fetchNotifications()).errorOrNull!;

        expect(error.code, 'notification_read_unavailable');
        expect(error.userMessage, contains('temporarily unavailable'));
      },
    );

    test('unknown maps to notification_read_failed', () async {
      api.error = const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.unknown,
        message: 'boom',
      );

      final AppError error = (await gateway.fetchNotifications()).errorOrNull!;

      expect(error.code, 'notification_read_failed');
    });
  });

  group('markNotificationsRead (D-N6 write slice, D-F5)', () {
    test('delegates to the api seam and returns the flipped count', () async {
      api.markResult = 2;

      final Result<int> result = await gateway.markNotificationsRead(<String>[
        'notification-1',
        'notification-2',
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 2);
      expect(api.markCallIds, <String>['notification-1', 'notification-2']);
    });

    test(
      'an empty id list short-circuits to an honest 0 (no RPC call)',
      () async {
        final Result<int> result = await gateway.markNotificationsRead(
          const <String>[],
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, 0);
        expect(
          api.markCallIds,
          isNull,
          reason: 'no RPC round-trip for nothing',
        );
      },
    );

    test('a mark denial maps to a typed AppError', () async {
      api.markError = const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.denied,
        message: 'permission denied',
      );

      final Result<int> result = await gateway.markNotificationsRead(<String>[
        'notification-1',
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull!.code, 'notification_read_denied');
    });

    test('a mark provider failure maps to the unavailable AppError', () async {
      api.markError = const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.providerUnavailable,
        message: 'timeout',
      );

      final Result<int> result = await gateway.markNotificationsRead(<String>[
        'notification-1',
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull!.code, 'notification_read_unavailable');
    });

    test('a non-seam failure maps to the typed unavailable AppError', () async {
      api.markError = null;
      // Force a non-seam failure path: a throwing stub (Object branch).
      final _ThrowingApi throwing = _ThrowingApi();
      final SupabaseNotificationGateway throwingGateway =
          SupabaseNotificationGateway(throwing);

      final Result<int> result = await throwingGateway.markNotificationsRead(
        <String>['notification-1'],
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull!.code, 'notification_mark_unavailable');
    });
  });
}

/// An api stub whose mark call throws a raw non-seam exception (drives the
/// gateway's defensive Object branch without a provider).
class _ThrowingApi implements SupabaseNotificationApi {
  @override
  Future<List<Map<String, dynamic>>> fetchNotifications() async =>
      <Map<String, dynamic>>[];

  @override
  Future<int> markNotificationsRead(List<String> ids) async =>
      throw StateError('transport down');
}
