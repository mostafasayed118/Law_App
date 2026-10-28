import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/tasks/supabase_task_api.dart';
import 'package:legalhub/features/tasks/data/supabase_task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';

void main() {
  group('SupabaseTaskGateway (task-writes slice, Gate 3 2026-09-27)', () {
    late _StubTaskApi api;
    late TaskBoardGateway gateway;

    setUp(() {
      api = _StubTaskApi();
      gateway = SupabaseTaskGateway(api);
    });

    test(
      'fetchTasks maps rows to TaskItems with the embed-resolved matterRef',
      () async {
        api.taskRows = <Map<String, dynamic>>[_row()];

        final Result<List<TaskItem>> result = await gateway.fetchTasks();

        expect(result, isA<Success<List<TaskItem>>>());
        final TaskItem task = (result as Success<List<TaskItem>>).value.single;
        expect(task.id, 'task-1');
        expect(task.organizationId, 'org-1');
        expect(task.matterId, 'matter-1');
        expect(task.title, 'Draft checklist');
        expect(task.matterRef, 'Demo acquisition review');
        expect(task.status, TaskStatus.inProgress);
        expect(task.assigneeId, 'user-3');
        expect(task.acknowledged, isFalse);
      },
    );

    test(
      'fetchTasks maps the server blocked status instead of failing the board',
      () async {
        api.taskRows = <Map<String, dynamic>>[_row(status: 'blocked')];

        final Result<List<TaskItem>> result = await gateway.fetchTasks();

        expect(result, isA<Success<List<TaskItem>>>());
        expect(
          (result as Success<List<TaskItem>>).value.single.status,
          TaskStatus.blocked,
        );
      },
    );

    test(
      'fetchTasks falls back to the raw matter id without an embed',
      () async {
        api.taskRows = <Map<String, dynamic>>[
          _row(matters: null, acknowledgedAt: '2026-09-27T10:00:00Z'),
        ];

        final Result<List<TaskItem>> result = await gateway.fetchTasks();

        final TaskItem task = (result as Success<List<TaskItem>>).value.single;
        expect(task.matterRef, 'matter-1');
        expect(task.acknowledged, isTrue);
      },
    );

    test('fetchTasks maps an unknown server status to task_read_failed '
        '(drift is loud)', () async {
      api.taskRows = <Map<String, dynamic>>[_row(status: 'archived')];

      final Result<List<TaskItem>> result = await gateway.fetchTasks();

      expect(result, isA<Failure<List<TaskItem>>>());
      expect(
        (result as Failure<List<TaskItem>>).error.code,
        'task_read_failed',
      );
    });

    test('fetchTasks maps a denial to task_read_denied', () async {
      api.failure = const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<TaskItem>> result = await gateway.fetchTasks();

      final AppError error = (result as Failure<List<TaskItem>>).error;
      expect(error.code, 'task_read_denied');
      // The denial kind survives so presentation renders ViewUnauthorized
      // (not retryable) instead of a generic retryable error.
      expect(error.kind, AppErrorKind.denied);
    });

    test('fetchTasks maps provider-unavailable to task_read_unavailable '
        'with the retryable kind', () async {
      api.failure = const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.providerUnavailable,
        message: 'connection refused',
      );

      final Result<List<TaskItem>> result = await gateway.fetchTasks();

      final AppError error = (result as Failure<List<TaskItem>>).error;
      expect(error.code, 'task_read_unavailable');
      expect(error.kind, AppErrorKind.unavailable);
    });

    test('createTask returns the server row and records the call', () async {
      api.rowResult = _row();

      final Result<TaskItem> result = await gateway.createTask(
        matterId: 'matter-1',
        title: 'Draft checklist',
        assigneeId: 'user-3',
      );

      expect((result as Success<TaskItem>).value.title, 'Draft checklist');
      expect(api.createCalls, hasLength(1));
      expect(api.createCalls.single['p_title'], 'Draft checklist');
    });

    test(
      'createTask maps a validation refusal to task_create_invalid',
      () async {
        api.failure = const SupabaseTaskException(
          kind: SupabaseTaskFailureKind.validation,
          message: 'task title is required',
        );

        final Result<TaskItem> result = await gateway.createTask(
          matterId: 'matter-1',
          title: '',
        );

        expect((result as Failure<TaskItem>).error.code, 'task_create_invalid');
      },
    );

    test('advanceTask sends the server enum value and maps the row', () async {
      api.rowResult = _row(status: 'done');

      final Result<TaskItem> result = await gateway.advanceTask(
        'task-1',
        TaskStatus.done,
      );

      expect((result as Success<TaskItem>).value.status, TaskStatus.done);
      expect(api.advanceCalls, <List<String>>[
        <String>['task-1', 'done'],
      ]);
    });

    test('advanceTask maps a denial to task_advance_denied', () async {
      api.failure = const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.denied,
        message: 'permission denied',
      );

      final Result<TaskItem> result = await gateway.advanceTask(
        'task-1',
        TaskStatus.done,
      );

      final AppError error = (result as Failure<TaskItem>).error;
      expect(error.code, 'task_advance_denied');
      expect(
        error.userMessage,
        'You do not have permission to advance this task.',
      );
    });

    test(
      'advanceTask maps an illegal transition to task_advance_invalid',
      () async {
        api.failure = const SupabaseTaskException(
          kind: SupabaseTaskFailureKind.validation,
          message: 'illegal task transition from done',
        );

        final Result<TaskItem> result = await gateway.advanceTask(
          'task-1',
          TaskStatus.todo,
        );

        expect(
          (result as Failure<TaskItem>).error.code,
          'task_advance_invalid',
        );
      },
    );

    test('assignTask maps the row and records the call', () async {
      api.rowResult = _row(assigneeId: 'user-2');

      final Result<TaskItem> result = await gateway.assignTask(
        'task-1',
        'user-2',
      );

      expect((result as Success<TaskItem>).value.assigneeId, 'user-2');
      expect(api.assignCalls, <List<String?>>[
        <String?>['task-1', 'user-2'],
      ]);
    });

    test('assignTask forwards a null assignee to unassign', () async {
      api.rowResult = _row(assigneeId: null);

      final Result<TaskItem> result = await gateway.assignTask('task-1', null);

      expect((result as Success<TaskItem>).value.assigneeId, isNull);
      expect(api.assignCalls, <List<String?>>[
        <String?>['task-1', null],
      ]);
    });

    test('acknowledgeTask maps the stamped row', () async {
      api.rowResult = _row(acknowledgedAt: '2026-09-27T10:00:00Z');

      final Result<TaskItem> result = await gateway.acknowledgeTask('task-1');

      final TaskItem task = (result as Success<TaskItem>).value;
      expect(task.acknowledged, isTrue);
      expect(api.acknowledgeCalls, <String>['task-1']);
    });

    test('acknowledgeTask maps the assignee-only denial to '
        'task_acknowledge_denied', () async {
      api.failure = const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.denied,
        message: 'permission denied',
      );

      final Result<TaskItem> result = await gateway.acknowledgeTask('task-1');

      final AppError error = (result as Failure<TaskItem>).error;
      expect(error.code, 'task_acknowledge_denied');
      expect(
        error.userMessage,
        'Only the assigned person can acknowledge this task.',
      );
    });

    test('failure technical messages never carry titles or ids', () async {
      api.failure = const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.unknown,
        message: 'internal error',
      );

      final Result<TaskItem> result = await gateway.createTask(
        matterId: 'matter-1',
        title: 'Secret title task-1',
      );

      final AppError error = (result as Failure<TaskItem>).error;
      expect(error.userMessage, isNot(contains('Secret title')));
      expect(error.userMessage, isNot(contains('task-1')));
    });
  });
}

Map<String, dynamic> _row({
  String status = 'in_progress',
  String? matters = 'Demo acquisition review',
  String? assigneeId = 'user-3',
  String? acknowledgedAt,
}) {
  return <String, dynamic>{
    'id': 'task-1',
    'organization_id': 'org-1',
    'matter_id': 'matter-1',
    'title': 'Draft checklist',
    'status': status,
    'assignee_id': assigneeId,
    'acknowledged_by': null,
    'acknowledged_at': acknowledgedAt,
    'created_at': '2026-09-27T09:00:00Z',
    if (matters != null) 'matters': <String, dynamic>{'title': matters},
  };
}

class _StubTaskApi implements SupabaseTaskApi {
  List<Map<String, dynamic>> taskRows = const <Map<String, dynamic>>[];
  Map<String, dynamic> rowResult = const <String, dynamic>{};
  SupabaseTaskException? failure;

  final List<Map<String, dynamic>> createCalls = <Map<String, dynamic>>[];
  final List<List<String>> advanceCalls = <List<String>>[];
  final List<List<String?>> assignCalls = <List<String?>>[];
  final List<String> acknowledgeCalls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final SupabaseTaskException? error = failure;
    if (error != null) {
      throw error;
    }
    return taskRows;
  }

  @override
  Future<Map<String, dynamic>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    createCalls.add(<String, dynamic>{
      'p_matter_id': matterId,
      'p_title': title,
      'p_assignee_id': assigneeId,
    });
    return _rowOrThrow();
  }

  @override
  Future<Map<String, dynamic>> advanceTaskStatus(
    String taskId,
    String toStatus,
  ) async {
    advanceCalls.add(<String>[taskId, toStatus]);
    return _rowOrThrow();
  }

  @override
  Future<Map<String, dynamic>> assignTask(
    String taskId,
    String? assigneeId,
  ) async {
    assignCalls.add(<String?>[taskId, assigneeId]);
    return _rowOrThrow();
  }

  @override
  Future<Map<String, dynamic>> acknowledgeTask(String taskId) async {
    acknowledgeCalls.add(taskId);
    return _rowOrThrow();
  }

  Map<String, dynamic> _rowOrThrow() {
    final SupabaseTaskException? error = failure;
    if (error != null) {
      throw error;
    }
    return rowResult;
  }
}
