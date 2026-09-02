import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/notifications/supabase_notification_api.dart';
import 'package:legalhub/data/notifications/supabase_notification_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseNotificationApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late SupabaseNotificationApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      api = SupabaseNotificationApiImpl((String table, String columns) async {
        calls.add('$table:$columns');
        final Object? objectError = objectErrors[table];
        if (objectError != null) {
          throw objectError;
        }
        final PostgrestException? error = tableErrors[table];
        if (error != null) {
          throw error;
        }
        return tableData[table] ?? const <Map<String, dynamic>>[];
      });
    });

    test('fetchNotifications selects the notifications table with the VO '
        'columns', () async {
      tableData['notifications'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'notification-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchNotifications();

      expect(rows, hasLength(1));
      expect(calls, <String>[
        'notifications:id, category, type, summary, server_timestamp, is_read',
      ]);
    });

    test('fetchNotifications maps a table denial to the denied kind', () async {
      tableErrors['notifications'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchNotifications(),
        throwsA(
          isA<SupabaseNotificationException>().having(
            (e) => e.kind,
            'kind',
            SupabaseNotificationFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'fetchNotifications maps an RLS denial text to the denied kind',
      () async {
        tableErrors['notifications'] = const PostgrestException(
          message: 'new row violates row-level security policy',
        );

        await expectLater(
          api.fetchNotifications(),
          throwsA(
            isA<SupabaseNotificationException>().having(
              (e) => e.kind,
              'kind',
              SupabaseNotificationFailureKind.denied,
            ),
          ),
        );
      },
    );

    test(
      'fetchNotifications maps an unknown PostgrestException to unknown',
      () async {
        tableErrors['notifications'] = const PostgrestException(
          message: 'something else',
        );

        await expectLater(
          api.fetchNotifications(),
          throwsA(
            isA<SupabaseNotificationException>().having(
              (e) => e.kind,
              'kind',
              SupabaseNotificationFailureKind.unknown,
            ),
          ),
        );
      },
    );

    test(
      'fetchNotifications maps a non-Postgrest error to providerUnavailable',
      () async {
        objectErrors['notifications'] = Exception('network down');

        await expectLater(
          api.fetchNotifications(),
          throwsA(
            isA<SupabaseNotificationException>().having(
              (e) => e.kind,
              'kind',
              SupabaseNotificationFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );
  });

  group('markNotificationsRead (D-N6 write slice, D-F5)', () {
    late List<(String, Object?)> rpcCalls;
    late PostgrestException? rpcError;
    late Object? rpcResult;
    late SupabaseNotificationApiImpl markApi;

    setUp(() {
      rpcCalls = <(String, Object?)>[];
      rpcError = null;
      rpcResult = 2;
      markApi = SupabaseNotificationApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
        rpc: (String fn, Map<String, dynamic>? params) async {
          rpcCalls.add((fn, params));
          if (rpcError != null) {
            throw rpcError!;
          }
          return rpcResult;
        },
      );
    });

    test(
      'calls mark_notifications_read with the exact uuid[] param pin',
      () async {
        final int flipped = await markApi.markNotificationsRead(<String>[
          'notification-1',
          'notification-2',
        ]);

        expect(flipped, 2);
        expect(rpcCalls, hasLength(1));
        expect(rpcCalls.single.$1, 'mark_notifications_read');
        expect(rpcCalls.single.$2, <String, Object?>{
          'p_notification_ids': <String>['notification-1', 'notification-2'],
        });
      },
    );

    test('maps a denial PostgrestException to the denied kind', () async {
      rpcError = const PostgrestException(message: 'permission denied');

      await expectLater(
        markApi.markNotificationsRead(<String>['notification-1']),
        throwsA(
          isA<SupabaseNotificationException>().having(
            (e) => e.kind,
            'kind',
            SupabaseNotificationFailureKind.denied,
          ),
        ),
      );
    });

    test('maps a non-numeric result to the unknown kind', () async {
      rpcResult = 'not-a-count';

      await expectLater(
        markApi.markNotificationsRead(<String>['notification-1']),
        throwsA(
          isA<SupabaseNotificationException>().having(
            (e) => e.kind,
            'kind',
            SupabaseNotificationFailureKind.unknown,
          ),
        ),
      );
    });

    test('maps a non-Postgrest error to providerUnavailable', () async {
      rpcResult = null;
      rpcCalls.clear();
      // A throwing caller that is not a PostgrestException (the impl's
      // Object branch rethrows the typed seam exception first — verify the
      // transport branch via a separate throwing closure).
      final SupabaseNotificationApiImpl throwingApi =
          SupabaseNotificationApiImpl(
            (String table, String columns) async =>
                const <Map<String, dynamic>>[],
            rpc: (String fn, Map<String, dynamic>? params) async =>
                throw Exception('transport down'),
          );

      await expectLater(
        throwingApi.markNotificationsRead(<String>['notification-1']),
        throwsA(
          isA<SupabaseNotificationException>().having(
            (e) => e.kind,
            'kind',
            SupabaseNotificationFailureKind.providerUnavailable,
          ),
        ),
      );
    });
  });
}
