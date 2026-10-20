import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/task_gateway.dart';
import '../domain/task_item.dart';
import 'task_board_state.dart';

/// Owns the task-board list (v1 queue, 2026-08-09).
///
/// [load] fetches the deterministic synthetic task list on screen open
/// (the vault/messaging pattern); loading/empty/error+retry via the shared
/// [ViewState] vocabulary.
///
/// The task-writes slice (Gate 3 spec 2026-09-27) adds the four RPC-backed
/// writes: [createTask] / [advanceTask] / [assignTask] / [acknowledgeTask].
/// Successful writes patch the returned row into the current list in place
/// (the RPC returns the server's own persisted row — no follow-up re-read,
/// the D-SM2 convention); failures surface [TaskBoardState.actionError]
/// inline and keep the list untouched.
class TaskBoardCubit extends Cubit<TaskBoardState> {
  TaskBoardCubit(this._gateway) : super(const TaskBoardState());

  final TaskBoardGateway _gateway;

  bool _loading = false;

  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.tasks is! ViewLoading<List<TaskItem>>) {
      // A reload also clears the previous write error — the banner belongs
      // to the last action, not to the new read.
      emit(
        state.copyWith(
          tasks: const ViewLoading<List<TaskItem>>(),
          actionError: null,
        ),
      );
    }
    final Result<List<TaskItem>> result = await _gateway.fetchTasks();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<TaskItem>>(value: final List<TaskItem> tasks):
        emit(
          state.copyWith(
            tasks: tasks.isEmpty
                ? const ViewEmpty<List<TaskItem>>()
                : ViewSuccess<List<TaskItem>>(tasks),
          ),
        );
      case Failure<List<TaskItem>>(error: final AppError error):
        emit(state.copyWith(tasks: viewStateForFailure<List<TaskItem>>(error)));
    }
  }

  /// Creates a task on [matterId]. The title is trimmed here (the composer
  /// owns the empty-disable, Batch B send() precedent); a whitespace-only
  /// title surfaces actionError without a round-trip.
  Future<void> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(actionError: 'Enter a task title.'));
      return;
    }
    await _runWrite(
      () => _gateway.createTask(
        matterId: matterId,
        title: trimmed,
        assigneeId: assigneeId,
      ),
      taskId: null,
    );
  }

  /// Moves [taskId] one legal step to [to] (`todo` → `in_progress` →
  /// `done`). The tile only offers the single legal next step, so an
  /// illegal call here is a programming error surfaced as actionError —
  /// never a silent no-op.
  Future<void> advanceTask(String taskId, TaskStatus to) async {
    await _runWrite(() => _gateway.advanceTask(taskId, to), taskId: taskId);
  }

  /// Re-points [taskId] at [assigneeId].
  Future<void> assignTask(String taskId, String assigneeId) async {
    await _runWrite(
      () => _gateway.assignTask(taskId, assigneeId),
      taskId: taskId,
    );
  }

  /// Stamps [taskId] acknowledged as the caller.
  Future<void> acknowledgeTask(String taskId) async {
    await _runWrite(() => _gateway.acknowledgeTask(taskId), taskId: taskId);
  }

  /// Runs one write: marks the row acting (a global act for create),
  /// clears the previous error, then patches the returned row into the
  /// list on success or surfaces the failure's user message on denial.
  Future<void> _runWrite(
    Future<Result<TaskItem>> Function() write, {
    required String? taskId,
  }) async {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(actionError: null, actingTaskId: taskId));
    final Result<TaskItem> result = await write();
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<TaskItem>(value: final TaskItem updated):
        emit(state.copyWith(tasks: _patchedTasks(updated), actingTaskId: null));
      case Failure<TaskItem>(error: final AppError error):
        emit(
          state.copyWith(actionError: error.userMessage, actingTaskId: null),
        );
    }
  }

  /// Returns the current success list with [updated] patched in by id
  /// (created rows append). A non-success list passes through untouched —
  /// the write still landed server-side and the next load() re-reads it.
  ViewState<List<TaskItem>> _patchedTasks(TaskItem updated) {
    final ViewState<List<TaskItem>> current = state.tasks;
    if (current is! ViewSuccess<List<TaskItem>>) {
      return current;
    }
    final List<TaskItem> tasks = List<TaskItem>.of(current.data);
    final int index = tasks.indexWhere(
      (TaskItem task) => task.id == updated.id,
    );
    if (index < 0) {
      tasks.add(updated);
    } else {
      tasks[index] = updated;
    }
    return ViewSuccess<List<TaskItem>>(tasks);
  }
}
