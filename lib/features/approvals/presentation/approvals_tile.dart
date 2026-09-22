part of 'approvals_screen.dart';

/// A read-only approval row: entity type + reference + status as text+icon
/// (never color alone); **no approve/deny affordance**.
class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({required this.approval});

  final PendingApproval approval;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData, String) status = switch (approval.status) {
      ApprovalStatus.pending => (
        Icons.hourglass_top,
        l10n.approvalStatusPending,
      ),
      ApprovalStatus.approved => (
        Icons.check_circle_outline,
        l10n.approvalStatusApproved,
      ),
      ApprovalStatus.denied => (
        Icons.cancel_outlined,
        l10n.approvalStatusDenied,
      ),
    };
    final String date = formatMediumDate(l10n, approval.createdAt);
    return AppTile(
      leading: Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
      title: '${approval.entityType} · ${approval.reference}',
      subtitles: <String>['${status.$2} · $date'],
    );
  }
}
