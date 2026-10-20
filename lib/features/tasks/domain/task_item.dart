import 'package:equatable/equatable.dart';

/// Lifecycle of a demo task-board item (v1 queue, 2026-08-09).
///
/// The server task enum matches this set (`todo`/`in_progress`/`blocked`/
/// `done` — `17_tasks.sql`). The UI offers only the forward path
/// (`todo` → `in_progress` → `done`); a `blocked` row may still arrive from
/// the provider and renders without an advance affordance. An unknown server
/// status maps to a loud FormatException, never a silent downgrade.
enum TaskStatus { todo, inProgress, blocked, done }

/// A task-board row (v1 queue; `legalhub_specification.md` §6
/// `collaboration_task_board`, v1). **Synthetic non-PII**: id, generic title,
/// matter reference (one of the known synthetic matter titles, D-W2
/// discipline), status, and due date. No real client/case data (the
/// fake-domain posture of Phases 5–12).
///
/// The task-writes slice (Gate 3 spec 2026-09-27) adds the two write-path
/// fields the server row carries: [assigneeId] (the row's `assignee_id` —
/// null when unassigned) and [acknowledged] (whether `acknowledged_at` is
/// set — the first-person receipt stamp). Both default to the read-only
/// posture so existing synthetic rows keep compiling unchanged.
class TaskItem extends Equatable {
  const TaskItem({
    required this.id,
    required this.organizationId,
    required this.matterId,
    required this.title,
    required this.matterRef,
    required this.status,
    required this.dueAt,
    this.assigneeId,
    this.acknowledged = false,
  });

  final String id;
  final String organizationId;
  final String matterId;
  final String title;
  final String matterRef;
  final TaskStatus status;
  final DateTime dueAt;
  final String? assigneeId;
  final bool acknowledged;

  @override
  List<Object?> get props => <Object?>[
    id,
    organizationId,
    matterId,
    title,
    matterRef,
    status,
    dueAt,
    assigneeId,
    acknowledged,
  ];
}
