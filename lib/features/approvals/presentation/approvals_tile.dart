part of 'approvals_screen.dart';

/// One approval row: title + kind/status/date line, with the status icon as a
/// non-color signal (never color alone). Tapping opens the detail sheet.
class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({required this.approval, required this.onTap});

  final PendingApproval approval;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AppTile(
      leading: Icon(
        approvalStatusIcon(approval.status),
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
      title: demoApprovalTitle(l10n, approval.title),
      subtitles: <String>[
        '${approvalKindLabel(l10n, approval.kind)} · '
            '${approvalStatusLabel(l10n, approval.status)}',
      ],
      onTap: onTap,
    );
  }
}
