import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

/// Development-only task-board implementation: a fixed synthetic list of 5
/// deterministic non-PII task rows (v1 queue, 2026-08-09) plus an
/// instance-local write surface for the task-writes slice (Gate 3 spec
/// 2026-09-27).
///
/// Reads return the synthetic list; the four writes mutate an instance-local
/// copy (the FakeMessageGateway `_sentByThread` precedent — writes never
/// leak across instances or tests) enforcing the same legal-transition shape
/// as the server: `todo` → `in_progress` → `done`, `done` terminal,
/// `blocked` synthetic-only and never advanceable.
class FakeTaskGateway implements TaskBoardGateway {
  FakeTaskGateway() : _tasks = List<TaskItem>.of(syntheticTasks);

  static const String demoOrganizationId = DemoCorpus.organizationId;

  static final List<TaskItem> syntheticTasks = <TaskItem>[
    TaskItem(
      id: 'task-1',
      organizationId: demoOrganizationId,
      matterId: DemoCorpus.matterIds[0],
      title: 'Demo: draft response checklist',
      matterRef: DemoCorpus.matterTitleAcquisition,
      status: TaskStatus.todo,
      dueAt: DateTime.utc(2026, 8, 15),
      assigneeId: DemoCorpus.attorneyId,
    ),
    TaskItem(
      id: 'task-2',
      organizationId: demoOrganizationId,
      matterId: DemoCorpus.matterIds[1],
      title: 'Demo: gather documents',
      matterRef: DemoCorpus.matterTitleLease,
      status: TaskStatus.inProgress,
      dueAt: DateTime.utc(2026, 8, 12),
    ),
    TaskItem(
      id: 'task-3',
      organizationId: demoOrganizationId,
      matterId: DemoCorpus.matterIds[3],
      title: 'Demo: review client notes',
      matterRef: DemoCorpus.matterTitleFamily,
      status: TaskStatus.blocked,
      dueAt: DateTime.utc(2026, 8, 18),
    ),
    TaskItem(
      id: 'task-4',
      organizationId: demoOrganizationId,
      matterId: DemoCorpus.matterIds[4],
      title: 'Demo: schedule follow-up',
      matterRef: DemoCorpus.matterTitleStartup,
      status: TaskStatus.done,
      dueAt: DateTime.utc(2026, 8, 5),
    ),
    TaskItem(
      id: 'task-5',
      organizationId: demoOrganizationId,
      matterId: DemoCorpus.matterIds[1],
      title: 'Demo: update matter timeline',
      matterRef: DemoCorpus.matterTitleLease,
      status: TaskStatus.inProgress,
      dueAt: DateTime.utc(2026, 8, 20),
    ),
  ];

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    return Result<List<TaskItem>>.success(List<TaskItem>.unmodifiable(_tasks));
  }

  /// Instance-local working copy: creates/advances/assigns/acknowledges
  /// mutate this list only, so no test or screen leaks writes into the
  /// shared synthetic baseline.
  final List<TaskItem> _tasks;

  int _createdCount = 0;

  @override
  Future<Result<TaskItem>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return Result<TaskItem>.failure(
        const AppError(
          code: 'task_create_invalid',
          userMessage:
              'The task could not be created. Check the title and try again.',
          messageKey: AppMessageKey.errTheTaskCouldNotBeCreatedCheckThe,
          technicalMessage: 'FakeTaskGateway: empty title.',
        ),
      );
    }
    _createdCount++;
    final TaskItem created = TaskItem(
      id: 'task-local-$_createdCount',
      organizationId: demoOrganizationId,
      matterId: matterId,
      title: trimmed,
      matterRef: DemoCorpus.matterTitlesById[matterId] ?? matterId,
      status: TaskStatus.todo,
      dueAt: DateTime.utc(2026, 9, 30),
      assigneeId: assigneeId,
    );
    _tasks.add(created);
    return Result<TaskItem>.success(created);
  }

  @override
  Future<Result<TaskItem>> advanceTask(String taskId, TaskStatus to) async {
    final int index = _tasks.indexWhere((TaskItem task) => task.id == taskId);
    if (index < 0) {
      return Result<TaskItem>.failure(
        const AppError(
          code: 'task_advance_denied',
          userMessage: 'You do not have permission to advance this task.',
          messageKey: AppMessageKey.errYouDoNotHavePermissionToAdvanceThis,
          technicalMessage: 'FakeTaskGateway: unknown task id.',
        ),
      );
    }
    final TaskItem current = _tasks[index];
    if (!_isLegalTransition(current.status, to)) {
      return Result<TaskItem>.failure(
        AppError(
          code: 'task_advance_invalid',
          userMessage:
              'The task cannot move to that status. It may already be done.',
          messageKey: AppMessageKey.errTheTaskCannotMoveToThatStatusIt,
          technicalMessage:
              'FakeTaskGateway: illegal transition '
              '${current.status.name} -> ${to.name}.',
        ),
      );
    }
    final TaskItem updated = TaskItem(
      id: current.id,
      organizationId: current.organizationId,
      matterId: current.matterId,
      title: current.title,
      matterRef: current.matterRef,
      status: to,
      dueAt: current.dueAt,
      assigneeId: current.assigneeId,
      acknowledged: current.acknowledged,
    );
    _tasks[index] = updated;
    return Result<TaskItem>.success(updated);
  }

  /// Mirrors the server's legal-transition gate (`advance_task_status`):
  /// one step forward only, `done` terminal, `blocked` never advanceable.
  bool _isLegalTransition(TaskStatus from, TaskStatus to) {
    return switch ((from, to)) {
      (TaskStatus.todo, TaskStatus.inProgress) => true,
      (TaskStatus.inProgress, TaskStatus.done) => true,
      _ => false,
    };
  }

  @override
  Future<Result<TaskItem>> assignTask(String taskId, String? assigneeId) async {
    final int index = _tasks.indexWhere((TaskItem task) => task.id == taskId);
    if (index < 0) {
      return Result<TaskItem>.failure(
        const AppError(
          code: 'task_assign_denied',
          userMessage: 'You do not have permission to re-assign this task.',
          messageKey: AppMessageKey.errYouDoNotHavePermissionToReAssign,
          technicalMessage: 'FakeTaskGateway: unknown task id.',
        ),
      );
    }
    final TaskItem current = _tasks[index];
    // Re-assigning clears the acknowledgement stamp (the server rewrites
    // the stamp columns on every assign — a new assignee's receipt is
    // outstanding, never inherited).
    final TaskItem updated = TaskItem(
      id: current.id,
      organizationId: current.organizationId,
      matterId: current.matterId,
      title: current.title,
      matterRef: current.matterRef,
      status: current.status,
      dueAt: current.dueAt,
      assigneeId: assigneeId,
    );
    _tasks[index] = updated;
    return Result<TaskItem>.success(updated);
  }

  @override
  Future<Result<TaskItem>> acknowledgeTask(String taskId) async {
    final int index = _tasks.indexWhere((TaskItem task) => task.id == taskId);
    if (index < 0) {
      return Result<TaskItem>.failure(
        const AppError(
          code: 'task_acknowledge_denied',
          userMessage: 'Only the assigned person can acknowledge this task.',
          messageKey:
              AppMessageKey.errOnlyTheAssignedPersonCanAcknowledgeThisTask,
          technicalMessage: 'FakeTaskGateway: unknown task id.',
        ),
      );
    }
    final TaskItem current = _tasks[index];
    final TaskItem updated = TaskItem(
      id: current.id,
      organizationId: current.organizationId,
      matterId: current.matterId,
      title: current.title,
      matterRef: current.matterRef,
      status: current.status,
      dueAt: current.dueAt,
      assigneeId: current.assigneeId,
      acknowledged: true,
    );
    _tasks[index] = updated;
    return Result<TaskItem>.success(updated);
  }
}
