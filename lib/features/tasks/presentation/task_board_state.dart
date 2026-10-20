import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/task_item.dart';

/// Immutable state of the task-board surface (v1 queue, 2026-08-09).
///
/// [actionError] carries the latest write failure's user message (the
/// sendError precedent — inline, cleared on the next write attempt);
/// [actingTaskId] marks the row with a write in flight so its affordances
/// disable while the RPC runs.
class TaskBoardState extends Equatable {
  const TaskBoardState({
    this.tasks = const ViewLoading<List<TaskItem>>(),
    this.actionError,
    this.actingTaskId,
  });

  final ViewState<List<TaskItem>> tasks;
  final String? actionError;
  final String? actingTaskId;

  TaskBoardState copyWith({
    ViewState<List<TaskItem>>? tasks,
    Object? actionError = _unset,
    Object? actingTaskId = _unset,
  }) {
    return TaskBoardState(
      tasks: tasks ?? this.tasks,
      actionError: identical(actionError, _unset)
          ? this.actionError
          : actionError as String?,
      actingTaskId: identical(actingTaskId, _unset)
          ? this.actingTaskId
          : actingTaskId as String?,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[tasks, actionError, actingTaskId];
}
