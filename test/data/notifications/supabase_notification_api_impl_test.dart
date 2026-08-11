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
}
