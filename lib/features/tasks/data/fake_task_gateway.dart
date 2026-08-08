import '../../../core/errors/result.dart';
import '../domain/task_gateway.dart';
import '../domain/task_item.dart';

/// Development-only task-board implementation: a fixed synthetic list of 5
/// deterministic non-PII task rows (v1 queue, 2026-08-09).
class FakeTaskGateway implements TaskBoardGateway {
  static final List<TaskItem> syntheticTasks = <TaskItem>[
    TaskItem(
      id: 'task-1',
      title: 'Demo: draft response checklist',
      matterRef: 'Demo acquisition review',
      status: TaskStatus.todo,
      dueAt: DateTime.utc(2026, 8, 15),
    ),
    TaskItem(
      id: 'task-2',
      title: 'Demo: gather documents',
      matterRef: 'Commercial lease consultation',
      status: TaskStatus.inProgress,
      dueAt: DateTime.utc(2026, 8, 12),
    ),
    TaskItem(
      id: 'task-3',
      title: 'Demo: review client notes',
      matterRef: 'Family status consultation',
      status: TaskStatus.blocked,
      dueAt: DateTime.utc(2026, 8, 18),
    ),
    TaskItem(
      id: 'task-4',
      title: 'Demo: schedule follow-up',
      matterRef: 'Startup formation advisory',
      status: TaskStatus.done,
      dueAt: DateTime.utc(2026, 8, 5),
    ),
    TaskItem(
      id: 'task-5',
      title: 'Demo: update matter timeline',
      matterRef: 'Commercial lease consultation',
      status: TaskStatus.inProgress,
      dueAt: DateTime.utc(2026, 8, 20),
    ),
  ];

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    return Result<List<TaskItem>>.success(syntheticTasks);
  }
}