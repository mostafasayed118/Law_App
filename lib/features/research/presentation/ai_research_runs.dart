part of 'ai_research_screen.dart';

/// The persisted run history (design §5: last 20, newest first). A completed
/// run opens its stored findings; running/failed rows are status-only. The
/// history arm never replaces a displayed answer — it has its own reload.
class _RunsHistory extends StatelessWidget {
  const _RunsHistory({
    required this.runs,
    required this.onOpen,
    required this.onRetry,
  });

  final ViewState<List<ResearchRun>> runs;
  final ValueChanged<ResearchRun> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.aiResearchRunsTitle,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: LegalHubTheme.spaceXs),
        switch (runs) {
          ViewLoading<List<ResearchRun>>() => const LinearProgressIndicator(),
          ViewUnauthorized<List<ResearchRun>>() => Text(
            l10n.stateUnauthorized,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          ViewOffline<List<ResearchRun>>() ||
          ViewError<List<ResearchRun>>() => Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.aiResearchRunsError,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.aiResearchReload),
              ),
            ],
          ),
          ViewEmpty<List<ResearchRun>>() => Text(
            l10n.aiResearchRunsEmpty,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          ViewSuccess<List<ResearchRun>>(data: final List<ResearchRun> data)
              when data.isEmpty =>
            Text(
              l10n.aiResearchRunsEmpty,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ViewSuccess<List<ResearchRun>>(data: final List<ResearchRun> data) =>
            Column(
              children: <Widget>[
                for (final ResearchRun run in data)
                  _ResearchRunRow(run: run, onOpen: onOpen),
              ],
            ),
        },
      ],
    );
  }
}

class _ResearchRunRow extends StatelessWidget {
  const _ResearchRunRow({required this.run, required this.onOpen});

  final ResearchRun run;
  final ValueChanged<ResearchRun> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final (IconData icon, Color color, String label) = switch (run.status) {
      ResearchRunStatus.running => (
        Icons.schedule,
        scheme.onSurfaceVariant,
        l10n.aiResearchRunStatusRunning,
      ),
      ResearchRunStatus.completed => (
        Icons.check_circle_outline,
        scheme.primary,
        l10n.aiResearchRunStatusCompleted,
      ),
      ResearchRunStatus.failed => (
        Icons.error_outline,
        scheme.error,
        l10n.aiResearchRunStatusFailed,
      ),
    };
    final bool openable = run.status == ResearchRunStatus.completed;
    return InkWell(
      onTap: openable ? () => onOpen(run) : null,
      borderRadius: const BorderRadius.all(
        Radius.circular(LegalHubTheme.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: LegalHubTheme.spaceXs,
          horizontal: LegalHubTheme.spaceXs,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: LegalHubTheme.spaceXs),
            Expanded(
              child: Text(
                run.promptSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceXs),
            Text(label, style: text.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
