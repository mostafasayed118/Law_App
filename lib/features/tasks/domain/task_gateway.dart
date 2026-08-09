import '../../../core/errors/result.dart';
import 'task_item.dart';

/// Collaboration task-board integration boundary (v1 queue, 2026-08-09).
///
/// Read-only demo surface behind the dev fake (the Phase 5–12 domain
/// discipline). No real task/column servers — the synthetic list is the
/// demo posture, never a claim of real collaboration (INSTRUCTIONS §1.2).
abstract interface class TaskBoardGateway {
  Future<Result<List<TaskItem>>> fetchTasks();
}
