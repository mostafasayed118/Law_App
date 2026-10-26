import 'package:legalhub/core/errors/result.dart';
import 'task_item.dart';

/// Collaboration task-board integration boundary (v1 queue, 2026-08-09).
///
/// The task-writes slice (Gate 3 spec 2026-09-27) adds the four RPC-only
/// writes beside the read: create / advance / assign / acknowledge. Every
/// write returns the server's own persisted row as a [TaskItem] (the
/// send_message D-SM2 convention — never a fabricated VO), and every denial
/// or validation refusal surfaces as a [Failure] with a `task_*` [AppError]
/// code (titles/ids never cross into errors). The dev fake implements the
/// same contract in-memory; the Supabase gateway binds the applied
/// `create_task` / `advance_task_status` / `assign_task` /
/// `acknowledge_task` RPCs.
abstract interface class TaskBoardGateway {
  Future<Result<List<TaskItem>>> fetchTasks();

  /// Creates a task on [matterId] with [title] (already trimmed by the
  /// caller — the cubit owns the whitespace guard, the Batch B send()
  /// precedent), optionally assigned to [assigneeId].
  Future<Result<TaskItem>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  });

  /// Moves [taskId] one legal step to [to] (`todo` → `in_progress` →
  /// `done`; `done` is terminal — the server refuses anything else with a
  /// validation failure).
  Future<Result<TaskItem>> advanceTask(String taskId, TaskStatus to);

  /// Re-points [taskId] at [assigneeId] (must be an active member of the
  /// task's org, never the platform owner — F2-D2/D4). A null [assigneeId]
  /// unassigns the task.
  Future<Result<TaskItem>> assignTask(String taskId, String? assigneeId);

  /// Stamps [taskId] acknowledged as the caller (assignee-only,
  /// first-person — the server derives the stamper from the session).
  Future<Result<TaskItem>> acknowledgeTask(String taskId);
}
