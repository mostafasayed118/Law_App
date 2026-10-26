import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';
import 'package:legalhub/shared/state/write_gate.dart';
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
///
/// The create/assign slice adds the two picker reads: [loadMatters] feeds the
/// create sheet's matter dropdown and [loadAssignableMembers] feeds the assign
/// sheet's roster. Both return the seam outcome unchanged (the sheets own
/// their loading/error presentation).
class TaskBoardCubit extends Cubit<TaskBoardState> {
  TaskBoardCubit(this._gateway, this._matterGateway, this._organizationGateway)
    : super(const TaskBoardState());

  final TaskBoardGateway _gateway;
  final MatterGateway _matterGateway;
  final OrganizationGateway _organizationGateway;

  final WriteGate _writeGate = WriteGate();

  bool _loading = false;

  /// The matter choices for the create sheet (the gateway's own failure is
  /// returned, never swallowed into an empty list).
  Future<Result<List<Matter>>> loadMatters() => _matterGateway.fetchMatters();

  /// The assignable roster for one matter (`list_matter_assignable_members`).
  Future<OrgOutcome<List<AssignableMember>>> loadAssignableMembers(
    String matterId,
  ) {
    return _organizationGateway.listAssignableMembers(matterId: matterId);
  }

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

  /// Creates a task on [matterId]. The title is trimmed here (the sheet
  /// validates non-empty before submitting). Returns null on success or the
  /// failure's [AppError] so the sheet can render localized inline copy.
  Future<AppError?> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) {
    return _runWrite(
      () => _gateway.createTask(
        matterId: matterId,
        title: title.trim(),
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

  /// Re-points [taskId] at [assigneeId], or unassigns it when null. Returns
  /// null on success or the failure's [AppError] for the sheet's inline copy.
  Future<AppError?> assignTask(String taskId, String? assigneeId) {
    return _runWrite(
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
  /// list on success or surfaces the failure's typed error on denial.
  /// Returns the [AppError] on failure, null on success. A write that loses
  /// the in-flight race returns [WriteGate.busyError] without touching state.
  Future<AppError?> _runWrite(
    Future<Result<TaskItem>> Function() write, {
    required String? taskId,
  }) async {
    Result<TaskItem>? writeResult;
    bool started = false;
    final AppError? error = await _writeGate.run<TaskItem>(
      isClosed: () => isClosed,
      write: () async {
        started = true;
        emit(state.copyWith(actionError: null, actingTaskId: taskId));
        final Result<TaskItem> result = await write();
        writeResult = result;
        return result;
      },
      onSuccess: () async {
        final Result<TaskItem>? result = writeResult;
        if (result is Success<TaskItem>) {
          emit(
            state.copyWith(
              tasks: _patchedTasks(result.value),
              actingTaskId: null,
            ),
          );
        }
      },
    );
    if (isClosed) {
      return error;
    }
    if (!started) {
      return error;
    }
    if (error != null) {
      emit(state.copyWith(actionError: error, actingTaskId: null));
    }
    return error;
  }

  /// Returns the current success list with [updated] patched in by id
  /// (created rows append). An empty board becomes a one-row success — the
  /// create that landed must appear even when the board was empty. Other
  /// non-success lists pass through untouched — the write still landed
  /// server-side and the next load() re-reads it.
  ViewState<List<TaskItem>> _patchedTasks(TaskItem updated) {
    final ViewState<List<TaskItem>> current = state.tasks;
    if (current is ViewEmpty<List<TaskItem>>) {
      return ViewSuccess<List<TaskItem>>(<TaskItem>[updated]);
    }
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
