import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/features/tasks/presentation/task_board_cubit.dart';
import 'package:legalhub/features/tasks/presentation/task_board_state.dart';

void main() {
  late _StubTaskBoardGateway gateway;

  setUp(() {
    gateway = _StubTaskBoardGateway();
  });

  TaskItem task({
    required String id,
    TaskStatus status = TaskStatus.todo,
    bool acknowledged = false,
    String? assigneeId,
  }) {
    return TaskItem(
      id: id,
      title: 'Task $id',
      matterRef: 'Demo acquisition review',
      status: status,
      dueAt: DateTime.utc(2026, 9, 30),
      assigneeId: assigneeId,
      acknowledged: acknowledged,
    );
  }

  group('TaskBoardCubit writes (task-writes slice, Gate 3 2026-09-27)', () {
    blocTest<TaskBoardCubit, TaskBoardState>(
      'advanceTask patches the returned row in place and clears the act',
      setUp: () => gateway = _StubTaskBoardGateway(
        tasks: <TaskItem>[task(id: 'task-1')],
        advanceResults: <Result<TaskItem>>[
          Result<TaskItem>.success(
            task(id: 'task-1', status: TaskStatus.inProgress),
          ),
        ],
      ),
      build: () => TaskBoardCubit(gateway),
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
      ),
      act: (TaskBoardCubit cubit) =>
          cubit.advanceTask('task-1', TaskStatus.inProgress),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
          actingTaskId: 'task-1',
        ),
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
            task(id: 'task-1', status: TaskStatus.inProgress),
          ]),
        ),
      ],
      verify: (_) => expect(gateway.advanceCalls, <List<String>>[
        <String>['task-1', 'TaskStatus.inProgress'],
      ]),
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'advanceTask surfaces the denial inline and keeps the list untouched',
      setUp: () => gateway = _StubTaskBoardGateway(
        advanceResults: <Result<TaskItem>>[
          Result<TaskItem>.failure(
            const AppError(
              code: 'task_advance_denied',
              userMessage: 'You do not have permission to advance this task.',
            ),
          ),
        ],
      ),
      build: () => TaskBoardCubit(gateway),
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
      ),
      act: (TaskBoardCubit cubit) =>
          cubit.advanceTask('task-1', TaskStatus.inProgress),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
          actingTaskId: 'task-1',
        ),
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
          actionError: 'You do not have permission to advance this task.',
        ),
      ],
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'acknowledgeTask stamps the row acknowledged',
      setUp: () => gateway = _StubTaskBoardGateway(
        acknowledgeResults: <Result<TaskItem>>[
          Result<TaskItem>.success(
            task(
              id: 'task-1',
              status: TaskStatus.inProgress,
              acknowledged: true,
            ),
          ),
        ],
      ),
      build: () => TaskBoardCubit(gateway),
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
          task(id: 'task-1', status: TaskStatus.inProgress),
        ]),
      ),
      act: (TaskBoardCubit cubit) => cubit.acknowledgeTask('task-1'),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
            task(id: 'task-1', status: TaskStatus.inProgress),
          ]),
          actingTaskId: 'task-1',
        ),
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
            task(
              id: 'task-1',
              status: TaskStatus.inProgress,
              acknowledged: true,
            ),
          ]),
        ),
      ],
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'createTask with a whitespace-only title surfaces actionError '
      'without a round-trip',
      build: () => TaskBoardCubit(gateway),
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
      ),
      act: (TaskBoardCubit cubit) =>
          cubit.createTask(matterId: 'matter-1', title: '   '),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
          actionError: 'Enter a task title.',
        ),
      ],
      verify: (_) => expect(gateway.createTitles, isEmpty),
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'createTask trims the title and appends the created row',
      setUp: () => gateway = _StubTaskBoardGateway(
        createResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-9')),
        ],
      ),
      build: () => TaskBoardCubit(gateway),
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
      ),
      act: (TaskBoardCubit cubit) =>
          cubit.createTask(matterId: 'matter-1', title: '  Draft checklist  '),
      // taskId is null for create and the seed carries no error, so the
      // acting emission is a no-op — a single patched emission results.
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
            task(id: 'task-1'),
            task(id: 'task-9'),
          ]),
        ),
      ],
      verify: (_) => expect(gateway.createTitles, <String>['Draft checklist']),
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'assignTask patches the re-assigned row',
      setUp: () => gateway = _StubTaskBoardGateway(
        assignResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-1', assigneeId: 'user-2')),
        ],
      ),
      build: () => TaskBoardCubit(gateway),
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
      ),
      act: (TaskBoardCubit cubit) => cubit.assignTask('task-1', 'user-2'),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
          actingTaskId: 'task-1',
        ),
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
            task(id: 'task-1', assigneeId: 'user-2'),
          ]),
        ),
      ],
    );
  });
}

class _StubTaskBoardGateway implements TaskBoardGateway {
  _StubTaskBoardGateway({
    this._tasks = const <TaskItem>[],
    List<Result<TaskItem>> createResults = const <Result<TaskItem>>[],
    List<Result<TaskItem>> advanceResults = const <Result<TaskItem>>[],
    List<Result<TaskItem>> assignResults = const <Result<TaskItem>>[],
    List<Result<TaskItem>> acknowledgeResults = const <Result<TaskItem>>[],
  }) : _createResults = List<Result<TaskItem>>.of(createResults),
       _advanceResults = List<Result<TaskItem>>.of(advanceResults),
       _assignResults = List<Result<TaskItem>>.of(assignResults),
       _acknowledgeResults = List<Result<TaskItem>>.of(acknowledgeResults);

  final List<TaskItem> _tasks;
  final List<Result<TaskItem>> _createResults;
  final List<Result<TaskItem>> _advanceResults;
  final List<Result<TaskItem>> _assignResults;
  final List<Result<TaskItem>> _acknowledgeResults;

  final List<String> createTitles = <String>[];
  final List<List<String>> advanceCalls = <List<String>>[];

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    return Result<List<TaskItem>>.success(_tasks);
  }

  @override
  Future<Result<TaskItem>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    createTitles.add(title);
    return _createResults.removeAt(0);
  }

  @override
  Future<Result<TaskItem>> advanceTask(String taskId, TaskStatus to) async {
    advanceCalls.add(<String>[taskId, to.toString()]);
    return _advanceResults.removeAt(0);
  }

  @override
  Future<Result<TaskItem>> assignTask(String taskId, String assigneeId) async {
    return _assignResults.removeAt(0);
  }

  @override
  Future<Result<TaskItem>> acknowledgeTask(String taskId) async {
    return _acknowledgeResults.removeAt(0);
  }
}
