import 'package:equatable/equatable.dart';

/// Lifecycle of a demo task-board item (v1 queue, 2026-08-09).
enum TaskStatus { todo, inProgress, blocked, done }

/// A task-board row (v1 queue; `legalhub_specification.md` §6
/// `collaboration_task_board`, v1). **Synthetic non-PII**: id, generic title,
/// matter reference (one of the known synthetic matter titles, D-W2
/// discipline), status, and due date. No real client/case data (the
/// fake-domain posture of Phases 5–12).
class TaskItem extends Equatable {
  const TaskItem({
    required this.id,
    required this.title,
    required this.matterRef,
    required this.status,
    required this.dueAt,
  });

  final String id;
  final String title;
  final String matterRef;
  final TaskStatus status;
  final DateTime dueAt;

  @override
  List<Object?> get props => <Object?>[id, title, matterRef, status, dueAt];
}
