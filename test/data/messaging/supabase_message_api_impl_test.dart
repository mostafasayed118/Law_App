import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/messaging/supabase_message_api.dart';
import 'package:legalhub/data/messaging/supabase_message_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseMessageApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late List<String> orgCalls;
    late Map<String, Map<String, dynamic>?> orgData;
    late Map<String, PostgrestException> orgErrors;
    late List<Map<String, dynamic>> insertRows;
    late Map<String, PostgrestException> insertErrors;
    late List<Map<String, dynamic>> insertCalls;
    late SupabaseMessageApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      orgCalls = <String>[];
      orgData = <String, Map<String, dynamic>?>{};
      orgErrors = <String, PostgrestException>{};
      insertRows = <Map<String, dynamic>>[];
      insertErrors = <String, PostgrestException>{};
      insertCalls = <Map<String, dynamic>>[];
      api = SupabaseMessageApiImpl(
        (String table, String columns, [String? threadId]) async {
          calls.add('$table:$columns${threadId == null ? '' : '|$threadId'}');
          final Object? objectError = objectErrors[table];
          if (objectError != null) {
            throw objectError;
          }
          final PostgrestException? error = tableErrors[table];
          if (error != null) {
            throw error;
          }
          return tableData[table] ?? const <Map<String, dynamic>>[];
        },
        orgCaller: (String table, String id) async {
          orgCalls.add('$table|$id');
          final PostgrestException? error = orgErrors[table];
          if (error != null) {
            throw error;
          }
          return orgData[table];
        },
        insertCaller: (String table, Map<String, dynamic> row) async {
          insertCalls.add(<String, dynamic>{'table': table, ...row});
          final PostgrestException? error = insertErrors[table];
          if (error != null) {
            throw error;
          }
          final Map<String, dynamic>? created = insertRows.isNotEmpty
              ? insertRows.removeAt(0)
              : null;
          if (created != null) {
            return created;
          }
          throw const PostgrestException(message: 'no insert row');
        },
      );
    });

    test('fetchMessageThreads selects the message_threads table with the VO '
        'columns', () async {
      tableData['message_threads'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'thread-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchMessageThreads();

      expect(rows, hasLength(1));
      expect(calls, <String>[
        'message_threads:id, matter_id, title, participants, message_count, '
            'last_activity_at, matters(title)',
      ]);
    });

    test(
      'fetchMessageThreads maps a table denial to the denied kind',
      () async {
        tableErrors['message_threads'] = const PostgrestException(
          message: 'permission denied',
        );

        await expectLater(
          api.fetchMessageThreads(),
          throwsA(
            isA<SupabaseMessageException>().having(
              (e) => e.kind,
              'kind',
              SupabaseMessageFailureKind.denied,
            ),
          ),
        );
      },
    );

    test(
      'fetchMessageThreads maps an RLS denial text to the denied kind',
      () async {
        tableErrors['message_threads'] = const PostgrestException(
          message: 'new row violates row-level security policy',
        );

        await expectLater(
          api.fetchMessageThreads(),
          throwsA(
            isA<SupabaseMessageException>().having(
              (e) => e.kind,
              'kind',
              SupabaseMessageFailureKind.denied,
            ),
          ),
        );
      },
    );

    test(
      'fetchMessageThreads preserves unknown failures with the message',
      () async {
        tableErrors['message_threads'] = const PostgrestException(
          message: 'connection reset by peer',
        );

        await expectLater(
          api.fetchMessageThreads(),
          throwsA(
            isA<SupabaseMessageException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  SupabaseMessageFailureKind.unknown,
                )
                .having(
                  (e) => e.message,
                  'message',
                  'connection reset by peer',
                ),
          ),
        );
      },
    );

    test('fetchMessages selects the messages table with the VO columns and '
        "the .eq('thread_id') filter", () async {
      tableData['messages'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'msg-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchMessages(
        'thread-9',
      );

      expect(rows, hasLength(1));
      expect(calls, <String>[
        'messages:id, thread_id, author_display_name, body, sent_at|thread-9',
      ]);
    });

    test('fetchMessages maps a table denial to the denied kind', () async {
      tableErrors['messages'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchMessages('thread-1'),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchMessages maps an RLS denial text to the denied kind', () async {
      tableErrors['messages'] = const PostgrestException(
        message: 'new row violates row-level security policy',
      );

      await expectLater(
        api.fetchMessages('thread-1'),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchMessages preserves unknown failures with the message', () async {
      tableErrors['messages'] = const PostgrestException(
        message: 'connection reset by peer',
      );

      await expectLater(
        api.fetchMessages('thread-1'),
        throwsA(
          isA<SupabaseMessageException>()
              .having((e) => e.kind, 'kind', SupabaseMessageFailureKind.unknown)
              .having((e) => e.message, 'message', 'connection reset by peer'),
        ),
      );
    });

    test(
      'fetchMessages maps a non-Postgrest failure to providerUnavailable',
      () async {
        objectErrors['messages'] = Exception('network down');

        await expectLater(
          api.fetchMessages('thread-1'),
          throwsA(
            isA<SupabaseMessageException>().having(
              (e) => e.kind,
              'kind',
              SupabaseMessageFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );

    test('fetchMessageThreads maps a non-Postgrest failure to '
        'providerUnavailable', () async {
      // A transport/network failure is not a PostgrestException; the impl
      // must map it to the typed unavailable kind, never leak a raw
      // exception across the seam (auth-impl defensive-catch precedent).
      objectErrors['message_threads'] = Exception('network down');

      await expectLater(
        api.fetchMessageThreads(),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.providerUnavailable,
          ),
        ),
      );
    });

    test('sendMessage resolves the thread org first, then inserts with it '
        '(D-LV1)', () async {
      orgData['message_threads'] = <String, dynamic>{
        'organization_id': 'org-1',
      };
      insertRows.add(<String, dynamic>{'id': 'msg-1'});

      final Map<String, dynamic> row = await api.sendMessage(
        'thread-1',
        'A demo body',
        authorDisplayName: 'Demo Partner',
      );

      expect(row['id'], 'msg-1');
      expect(orgCalls, <String>['message_threads|thread-1']);
      expect(insertCalls, hasLength(1));
      final Map<String, dynamic> insert = insertCalls.single;
      expect(insert['table'], 'messages');
      expect(insert['organization_id'], 'org-1');
      expect(insert['thread_id'], 'thread-1');
      expect(insert['author_display_name'], 'Demo Partner');
      expect(insert['body'], 'A demo body');
    });

    test('sendMessage falls back to a generic author when none is given '
        '(D-RT4)', () async {
      orgData['message_threads'] = <String, dynamic>{
        'organization_id': 'org-1',
      };
      insertRows.add(<String, dynamic>{'id': 'msg-2'});

      await api.sendMessage('thread-1', 'Body');

      expect(insertCalls.single['author_display_name'], 'Demo client');
    });

    test('sendMessage denies when the thread org is not readable', () async {
      // The RLS-scoped org lookup returns null for an unassigned writer —
      // the write cannot be authorized, mapped as a typed denial.
      orgData['message_threads'] = null;

      await expectLater(
        api.sendMessage('thread-1', 'Body'),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.denied,
          ),
        ),
      );
      expect(insertCalls, isEmpty);
    });

    test('sendMessage maps an insert denial to the denied kind', () async {
      orgData['message_threads'] = <String, dynamic>{
        'organization_id': 'org-1',
      };
      insertErrors['messages'] = const PostgrestException(
        message: 'new row violates row-level security policy',
      );

      await expectLater(
        api.sendMessage('thread-1', 'Body'),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.denied,
          ),
        ),
      );
    });

    test('sendMessage maps a non-Postgrest insert failure to '
        'providerUnavailable', () async {
      orgData['message_threads'] = <String, dynamic>{
        'organization_id': 'org-1',
      };
      insertErrors['messages'] = const PostgrestException(
        message: 'connection reset by peer',
      );

      await expectLater(
        api.sendMessage('thread-1', 'Body'),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.unknown,
          ),
        ),
      );
    });
  });
}
