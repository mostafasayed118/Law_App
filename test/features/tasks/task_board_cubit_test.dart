import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/features/tasks/presentation/task_board_cubit.dart';
import 'package:legalhub/features/tasks/presentation/task_board_state.dart';
import 'package:legalhub/shared/state/write_gate.dart';

void main() {
  late _StubTaskBoardGateway gateway;
  late _StubMatterGateway matterGateway;
  late _StubOrgGateway organizationGateway;

  setUp(() {
    gateway = _StubTaskBoardGateway();
    matterGateway = _StubMatterGateway();
    organizationGateway = _StubOrgGateway();
  });

  TaskBoardCubit buildCubit() =>
      TaskBoardCubit(gateway, matterGateway, organizationGateway);

  TaskItem task({
    required String id,
    TaskStatus status = TaskStatus.todo,
    bool acknowledged = false,
    String? assigneeId,
  }) {
    return TaskItem(
      id: id,
      organizationId: 'org-1',
      matterId: 'matter-1',
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
      build: buildCubit,
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
      build: buildCubit,
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
          actionError: const AppError(
            code: 'task_advance_denied',
            userMessage: 'You do not have permission to advance this task.',
          ),
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
      build: buildCubit,
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
      'createTask returns the failure and surfaces its message inline',
      setUp: () => gateway = _StubTaskBoardGateway(
        createResults: <Result<TaskItem>>[
          Result<TaskItem>.failure(
            const AppError(
              code: 'task_create_denied',
              userMessage:
                  'You do not have permission to create tasks on this matter.',
              kind: AppErrorKind.denied,
            ),
          ),
        ],
      ),
      build: buildCubit,
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
      ),
      act: (TaskBoardCubit cubit) =>
          cubit.createTask(matterId: 'matter-1', title: 'Draft'),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
          actionError: const AppError(
            code: 'task_create_denied',
            userMessage:
                'You do not have permission to create tasks on this matter.',
            kind: AppErrorKind.denied,
          ),
        ),
      ],
      verify: (_) => expect(gateway.createTitles, <String>['Draft']),
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'createTask trims the title and appends the created row',
      setUp: () => gateway = _StubTaskBoardGateway(
        createResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-9')),
        ],
      ),
      build: buildCubit,
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
      'createTask on an empty board becomes a one-row success',
      setUp: () => gateway = _StubTaskBoardGateway(
        createResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-9')),
        ],
      ),
      build: buildCubit,
      seed: () => const TaskBoardState(tasks: ViewEmpty<List<TaskItem>>()),
      act: (TaskBoardCubit cubit) =>
          cubit.createTask(matterId: 'matter-1', title: 'Draft'),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-9')]),
        ),
      ],
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'assignTask patches the re-assigned row',
      setUp: () => gateway = _StubTaskBoardGateway(
        assignResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-1', assigneeId: 'user-2')),
        ],
      ),
      build: buildCubit,
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
      verify: (_) => expect(gateway.assigneeCalls, <String?>['user-2']),
    );

    blocTest<TaskBoardCubit, TaskBoardState>(
      'assignTask forwards a null assignee to unassign',
      setUp: () => gateway = _StubTaskBoardGateway(
        assignResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-1')),
        ],
      ),
      build: buildCubit,
      seed: () => TaskBoardState(
        tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
          task(id: 'task-1', assigneeId: 'user-2'),
        ]),
      ),
      act: (TaskBoardCubit cubit) => cubit.assignTask('task-1', null),
      expect: () => <TaskBoardState>[
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[
            task(id: 'task-1', assigneeId: 'user-2'),
          ]),
          actingTaskId: 'task-1',
        ),
        TaskBoardState(
          tasks: ViewSuccess<List<TaskItem>>(<TaskItem>[task(id: 'task-1')]),
        ),
      ],
      verify: (_) => expect(gateway.assigneeCalls, <String?>[null]),
    );

    test('a second assign returns busyError without a second write', () async {
      gateway = _StubTaskBoardGateway(
        assignResults: <Result<TaskItem>>[
          Result<TaskItem>.success(task(id: 'task-1', assigneeId: 'user-2')),
        ],
      );
      final Completer<void> gate = Completer<void>();
      gateway.assignGate = gate;
      final TaskBoardCubit cubit = buildCubit();
      addTearDown(cubit.close);

      final Future<AppError?> first = cubit.assignTask('task-1', 'user-2');
      await Future<void>.delayed(Duration.zero);
      final AppError? second = await cubit.assignTask('task-1', 'user-3');

      expect(second, WriteGate.busyError);
      expect(gateway.assigneeCalls, <String?>['user-2']);
      // The first write's row spinner stays in place.
      expect(cubit.state.actingTaskId, 'task-1');

      gate.complete();
      expect(await first, isNull);
      expect(cubit.state.actingTaskId, isNull);
    });

    test(
      'a thrown write clears the acting row and returns the typed failure (N1)',
      () async {
        gateway = _StubTaskBoardGateway(throwOnAssign: true);
        final TaskBoardCubit cubit = buildCubit();
        addTearDown(cubit.close);

        final AppError? error = await cubit.assignTask('task-1', 'user-2');

        expect(error?.code, 'task_write_failed');
        expect(cubit.state.actionError?.code, 'task_write_failed');
        expect(cubit.state.actingTaskId, isNull);
      },
    );
  });

  group('TaskBoardCubit load (N1)', () {
    test(
      'a thrown load resets the guard so a retry reaches the gateway',
      () async {
        gateway = _StubTaskBoardGateway(throwFirstFetch: true);
        final TaskBoardCubit cubit = buildCubit();
        addTearDown(cubit.close);

        await expectLater(cubit.load(), throwsA(isA<StateError>()));
        await cubit.load();

        expect(gateway.fetchCalls, 2);
        expect(cubit.state.tasks, isA<ViewEmpty<List<TaskItem>>>());
      },
    );
  });

  group('TaskBoardCubit picker reads', () {
    test('loadMatters returns the gateway result unchanged', () async {
      final Result<List<Matter>> failure = Result<List<Matter>>.failure(
        const AppError(code: 'matters_failed', userMessage: 'offline'),
      );
      matterGateway.result = failure;
      final TaskBoardCubit cubit = buildCubit();
      addTearDown(cubit.close);

      expect(await cubit.loadMatters(), same(failure));
    });

    test('loadAssignableMembers forwards the matter id and outcome', () async {
      const OrgOutcome<List<AssignableMember>> success =
          OrgOutcome<List<AssignableMember>>.success(<AssignableMember>[
            AssignableMember(userId: 'user-2', displayName: 'Amira'),
          ]);
      organizationGateway.result = success;
      final TaskBoardCubit cubit = buildCubit();
      addTearDown(cubit.close);

      final OrgOutcome<List<AssignableMember>> outcome = await cubit
          .loadAssignableMembers('matter-7');

      expect(outcome, same(success));
      expect(organizationGateway.matterCalls, <String>['matter-7']);
    });
  });
}

class _StubTaskBoardGateway implements TaskBoardGateway {
  _StubTaskBoardGateway({
    this._tasks = const <TaskItem>[],
    List<Result<TaskItem>> createResults = const <Result<TaskItem>>[],
    List<Result<TaskItem>> advanceResults = const <Result<TaskItem>>[],
    List<Result<TaskItem>> assignResults = const <Result<TaskItem>>[],
    List<Result<TaskItem>> acknowledgeResults = const <Result<TaskItem>>[],
    this.throwFirstFetch = false,
    this.throwOnAssign = false,
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
  final List<String?> assigneeCalls = <String?>[];
  Completer<void>? assignGate;
  final bool throwFirstFetch;
  final bool throwOnAssign;
  int fetchCalls = 0;

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    fetchCalls += 1;
    if (throwFirstFetch && fetchCalls == 1) {
      throw StateError('task board gateway blew up');
    }
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
  Future<Result<TaskItem>> assignTask(String taskId, String? assigneeId) async {
    assigneeCalls.add(assigneeId);
    if (throwOnAssign) {
      throw StateError('task write gateway blew up');
    }
    final Completer<void>? gate = assignGate;
    if (gate != null) {
      await gate.future;
    }
    return _assignResults.removeAt(0);
  }

  @override
  Future<Result<TaskItem>> acknowledgeTask(String taskId) async {
    return _acknowledgeResults.removeAt(0);
  }
}

class _StubMatterGateway extends FakeMatterGateway {
  Result<List<Matter>>? result;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    final Result<List<Matter>>? stub = result;
    if (stub != null) {
      return stub;
    }
    return super.fetchMatters();
  }
}

class _StubOrgGateway extends FakeOrganizationGateway {
  OrgOutcome<List<AssignableMember>>? result;
  final List<String> matterCalls = <String>[];

  @override
  Future<OrgOutcome<List<AssignableMember>>> listAssignableMembers({
    required String matterId,
  }) async {
    matterCalls.add(matterId);
    final OrgOutcome<List<AssignableMember>>? stub = result;
    if (stub != null) {
      return stub;
    }
    return super.listAssignableMembers(matterId: matterId);
  }
}
