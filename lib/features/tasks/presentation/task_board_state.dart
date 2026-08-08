import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/task_item.dart';

/// Immutable state of the task-board surface (v1 queue, 2026-08-09).
class TaskBoardState extends Equatable {
  const TaskBoardState({this.tasks = const ViewLoading<List<TaskItem>>()});

  final ViewState<List<TaskItem>> tasks;

  TaskBoardState copyWith({ViewState<List<TaskItem>>? tasks}) {
    return TaskBoardState(tasks: tasks ?? this.tasks);
  }

  @override
  List<Object?> get props => <Object?>[tasks];
}