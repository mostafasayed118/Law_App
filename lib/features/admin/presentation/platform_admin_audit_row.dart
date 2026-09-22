part of 'platform_admin_screen.dart';

/// One redacted audit row: action + redacted summary + scope + date.
/// Metadata-only (contract §8) — no credentials, no content, no PII field
/// names; rows are read-only (no tap affordance).
class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.organizationName});

  final AuditEntry entry;
  final String? organizationName;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String date = MaterialLocalizations.of(
      context,
    ).formatShortDate(entry.serverTimestamp);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Text(entry.action.isEmpty ? '?' : entry.action[0].toUpperCase()),
      ),
      title: Text(entry.redactedSummary),
      subtitle: Text(
        [?organizationName, entry.action, entry.outcome, date].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
