import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/tasks/supabase_task_api.dart';
import 'package:legalhub/data/tasks/supabase_task_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseTaskApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late List<String> rpcCalls;
    late Map<String, Object?> rpcData;
    late Map<String, PostgrestException> rpcErrors;
    late SupabaseTaskApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      rpcCalls = <String>[];
      rpcData = <String, Object?>{};
      rpcErrors = <String, PostgrestException>{};
      api = SupabaseTaskApiImpl(
        (String table, String columns, [String? _]) async {
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
        },
        rpcCaller: (String function, Map<String, dynamic> params) async {
          // The recorded shape pins the RPC contract: function name + the
          // named params and their values.
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

    test('fetchTasks selects the tasks table with the VO columns', () async {
      tableData['tasks'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'task-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchTasks();

      expect(rows, hasLength(1));
      expect(calls, <String>[
        'tasks:id, organization_id, matter_id, title, status, assignee_id, '
            'acknowledged_by, acknowledged_at, created_at, matters(title)',
      ]);
    });

    test('fetchTasks maps a table denial to the denied kind', () async {
      tableErrors['tasks'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchTasks(),
        throwsA(
          isA<SupabaseTaskException>().having(
            (e) => e.kind,
            'kind',
            SupabaseTaskFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'fetchTasks maps a non-Postgrest failure to providerUnavailable',
      () async {
        objectErrors['tasks'] = StateError('transport down');

        await expectLater(
          api.fetchTasks(),
          throwsA(
            isA<SupabaseTaskException>().having(
              (e) => e.kind,
              'kind',
              SupabaseTaskFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );

    test('createTask calls the create_task RPC with the matter, title, and '
        'assignee params', () async {
      rpcData['create_task'] = <String, dynamic>{'id': 'task-9'};

      final Map<String, dynamic> row = await api.createTask(
        matterId: 'matter-1',
        title: 'Draft checklist',
        assigneeId: 'user-3',
      );

      expect(row['id'], 'task-9');
      expect(rpcCalls, <String>[
        'create_task:p_matter_id,p_assignee_id,p_title:matter-1,user-3,'
            'Draft checklist',
      ]);
    });

    test(
      'createTask sends an explicit null assignee when unassigned',
      () async {
        rpcData['create_task'] = <String, dynamic>{'id': 'task-9'};

        await api.createTask(matterId: 'matter-1', title: 'Draft checklist');

        // The RPC's p_assignee_id defaults to null server-side; the client
        // passes the key through explicitly (no conditional-param shape to
        // drift between assigned and unassigned creates).
        expect(rpcCalls, <String>[
          'create_task:p_matter_id,p_assignee_id,p_title:matter-1,null,'
              'Draft checklist',
        ]);
      },
    );

    test('createTask maps the 23514 validation SQLSTATE to the validation '
        'kind', () async {
      // The RPC validation gates raise `using errcode = 'check_violation'`
      // (Batch B) — PostgREST surfaces the SQLSTATE digits in `code`.
      rpcErrors['create_task'] = const PostgrestException(
        message: 'task title is required',
        code: '23514',
      );

      await expectLater(
        api.createTask(matterId: 'matter-1', title: ''),
        throwsA(
          isA<SupabaseTaskException>().having(
            (e) => e.kind,
            'kind',
            SupabaseTaskFailureKind.validation,
          ),
        ),
      );
    });

    test('createTask maps the in-function gate to the denied kind', () async {
      rpcErrors['create_task'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.createTask(matterId: 'matter-1', title: 'Draft checklist'),
        throwsA(
          isA<SupabaseTaskException>().having(
            (e) => e.kind,
            'kind',
            SupabaseTaskFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'advanceTaskStatus calls the RPC with the task id + server status',
      () async {
        rpcData['advance_task_status'] = <String, dynamic>{'id': 'task-1'};

        await api.advanceTaskStatus('task-1', 'in_progress');

        expect(rpcCalls, <String>[
          'advance_task_status:p_task_id,p_to_status:task-1,in_progress',
        ]);
      },
    );

    test('assignTask calls the RPC with the task id + assignee id', () async {
      rpcData['assign_task'] = <String, dynamic>{'id': 'task-1'};

      await api.assignTask('task-1', 'user-2');

      expect(rpcCalls, <String>[
        'assign_task:p_task_id,p_assignee_id:task-1,user-2',
      ]);
    });

    test('assignTask sends an explicit null assignee to unassign', () async {
      rpcData['assign_task'] = <String, dynamic>{'id': 'task-1'};

      await api.assignTask('task-1', null);

      // The RPC accepts a null p_assignee_id (unassign); the key is always
      // sent so the param shape never drifts between assign and unassign.
      expect(rpcCalls, <String>[
        'assign_task:p_task_id,p_assignee_id:task-1,null',
      ]);
    });

    test('acknowledgeTask calls the RPC with the task id only', () async {
      // First-person by construction: the stamper derives from the session
      // in-function, so no user id ever crosses (F2-D5).
      rpcData['acknowledge_task'] = <String, dynamic>{'id': 'task-1'};

      await api.acknowledgeTask('task-1');

      expect(rpcCalls, <String>['acknowledge_task:p_task_id:task-1']);
    });

    test(
      'a non-row RPC response is a typed unknown, never a cast error',
      () async {
        rpcData['advance_task_status'] = 'task-1';

        await expectLater(
          api.advanceTaskStatus('task-1', 'done'),
          throwsA(
            isA<SupabaseTaskException>().having(
              (e) => e.kind,
              'kind',
              SupabaseTaskFailureKind.unknown,
            ),
          ),
        );
      },
    );

    test('an unrecognized RPC failure is unknown (never a denial)', () async {
      rpcErrors['acknowledge_task'] = const PostgrestException(
        message: 'connection reset by peer',
      );

      await expectLater(
        api.acknowledgeTask('task-1'),
        throwsA(
          isA<SupabaseTaskException>().having(
            (e) => e.kind,
            'kind',
            SupabaseTaskFailureKind.unknown,
          ),
        ),
      );
    });
  });
}
