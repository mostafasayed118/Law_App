part of 'task_board_screen.dart';

/// A task row: status text + icon, never color alone (INSTRUCTIONS §4.5).
///
/// The task-writes slice (Gate 3 spec 2026-09-27) adds the two row-level
/// affordances the server authorizes for any assigned member: advance one
/// legal step ([TaskBoardCubit.advanceTask]) and acknowledge
/// ([TaskBoardCubit.acknowledgeTask]). Only the single legal next step is
/// ever offered (`todo` → `in_progress` → `done`; `done` terminal and the
/// synthetic-only `blocked` offer nothing), so the client can never send an
/// illegal transition. The row's buttons disable while its write is in
/// flight ([TaskBoardState.actingTaskId]).
class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final TaskItem task;

  /// The single legal next status the tile may offer, or null when the row
  /// is terminal (`done`) or synthetic-only (`blocked`).
  static TaskStatus? nextStepFor(TaskStatus status) {
    return switch (status) {
      TaskStatus.todo => TaskStatus.inProgress,
      TaskStatus.inProgress => TaskStatus.done,
      TaskStatus.blocked || TaskStatus.done => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData, String) status = switch (task.status) {
      TaskStatus.todo => (Icons.radio_button_unchecked, l10n.taskStatusTodo),
      TaskStatus.inProgress => (Icons.hourglass_top, l10n.taskStatusInProgress),
      TaskStatus.blocked => (Icons.block, l10n.taskStatusBlocked),
      TaskStatus.done => (Icons.check_circle_outline, l10n.taskStatusDone),
    };
    final TaskBoardCubit cubit = context.read<TaskBoardCubit>();
    final bool acting = context.select<TaskBoardCubit, bool>(
      (TaskBoardCubit cubit) => cubit.state.actingTaskId == task.id,
    );
    final TaskStatus? next = nextStepFor(task.status);
    return AppTile(
      leading: Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
      title: demoTaskTitle(l10n, task.title),
      subtitles: <String>[
        '${demoMatterTitle(l10n, task.matterRef)} · ${status.$2}',
        if (task.acknowledged) l10n.taskAcknowledged,
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Unassigned rows have no one who can acknowledge them: the
          // server's first-person gate only accepts the assignee, so hiding
          // the affordance keeps the board honest. (A non-assignee still
          // sees the button when someone else is assigned; the server
          // replies with the denied message, which the banner renders.)
          if (!task.acknowledged && task.assigneeId != null)
            TextButton(
              onPressed: acting ? null : () => cubit.acknowledgeTask(task.id),
              child: Text(l10n.taskAcknowledge),
            ),
          if (next != null)
            IconButton(
              tooltip: next == TaskStatus.done
                  ? l10n.taskStatusDone
                  : l10n.taskStatusInProgress,
              onPressed: acting ? null : () => cubit.advanceTask(task.id, next),
              icon: Icon(
                next == TaskStatus.done
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top,
              ),
            ),
        ],
      ),
    );
  }
}
