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
    late List<String> rpcCalls;
    late Map<String, Object?> rpcData;
    late Map<String, PostgrestException> rpcErrors;
    late SupabaseMessageApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      rpcCalls = <String>[];
      rpcData = <String, Object?>{};
      rpcErrors = <String, PostgrestException>{};
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
        rpcCaller: (String function, Map<String, dynamic> params) async {
          // The recorded shape pins the RPC contract: function name + the
          // named params (p_thread_id, p_body) and their values.
          rpcCalls.add(
            '$function:${params.keys.join(',')}:${params.values.join(',')}',
          );
          final PostgrestException? error = rpcErrors[function];
          if (error != null) {
            throw error;
          }
          return PostgrestResponse<dynamic>(data: rpcData[function], count: 0);
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

    test('sendMessage calls the audited send_message RPC with the thread + '
        'body and returns the persisted id (D-SM2)', () async {
      rpcData['send_message'] = 'msg-1';

      final String id = await api.sendMessage('thread-1', 'A demo body');

      expect(id, 'msg-1');
      // The only call is the RPC — no org pre-read (Q4: resolution moved
      // into the function) and no INSERT.
      expect(rpcCalls, <String>[
        'send_message:p_thread_id,p_body:thread-1,A demo body',
      ]);
    });

    test('sendMessage sends no author — the RPC derives the stored author '
        'in-function (D-RT4)', () async {
      rpcData['send_message'] = 'msg-2';

      await api.sendMessage('thread-1', 'Body');

      // Exactly the two RPC params (p_thread_id, p_body): the author is
      // derived from profiles inside the function, never sent by the client.
      expect(rpcCalls, <String>[
        'send_message:p_thread_id,p_body:thread-1,Body',
      ]);
    });

    test(
      'sendMessage maps the in-function denial to the denied kind',
      () async {
        // The RPC's `raise exception 'permission denied'` (D-SM1 gate failure)
        // surfaces as a PostgrestException carrying the stable denial text.
        rpcErrors['send_message'] = const PostgrestException(
          message: 'permission denied',
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
      },
    );

    test('sendMessage preserves unknown failures with the message', () async {
      rpcErrors['send_message'] = const PostgrestException(
        message: 'provider hiccup',
      );

      await expectLater(
        api.sendMessage('thread-1', 'Body'),
        throwsA(
          isA<SupabaseMessageException>()
              .having((e) => e.kind, 'kind', SupabaseMessageFailureKind.unknown)
              .having((e) => e.message, 'message', 'provider hiccup'),
        ),
      );
    });

    test('sendMessage maps a non-Postgrest failure to '
        'providerUnavailable', () async {
      // A raw throw from the injected caller bypasses the Postgrest path;
      // the impl's defensive `on Object` catch turns it into the typed
      // unavailable kind (the reads' precedent).
      final SupabaseMessageApiImpl throwing = SupabaseMessageApiImpl(
        (String table, String columns, [String? threadId]) async =>
            const <Map<String, dynamic>>[],
        rpcCaller: (String function, Map<String, dynamic> params) async {
          throw StateError('network down');
        },
      );

      await expectLater(
        throwing.sendMessage('thread-1', 'Body'),
        throwsA(
          isA<SupabaseMessageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.providerUnavailable,
          ),
        ),
      );
    });

    test('sendMessage fails loudly when the RPC returns no id', () async {
      rpcData['send_message'] = null;

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
