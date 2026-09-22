part of 'task_board_screen.dart';

/// A read-only task row: status text + icon, never color alone; no actions.
class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final TaskItem task;

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
    return AppTile(
      leading: Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
      title: task.title,
      subtitles: <String>['${task.matterRef} · ${status.$2}'],
    );
  }
}
