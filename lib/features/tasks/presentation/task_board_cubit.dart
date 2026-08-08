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
/// [ViewState] vocabulary. Read-only — no task actions.
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
      emit(state.copyWith(tasks: const ViewLoading<List<TaskItem>>()));
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
        emit(state.copyWith(tasks: ViewError<List<TaskItem>>(error)));
    }
  }
}