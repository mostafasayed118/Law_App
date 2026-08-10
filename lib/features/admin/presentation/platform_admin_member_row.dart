part of 'platform_admin_screen.dart';

/// One member metadata row: identity + role/status + the platform actions
/// (suspend/reactivate toggle on active/suspended, delete demo account).
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.organizationName,
    required this.pending,
  });

  final OrgMember member;
  final String? organizationName;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(_initial(member.displayName)),
      ),
      title: Text(member.displayName),
      subtitle: Text(
        organizationName == null
            ? _statusLabel(l10n, member)
            : '$organizationName · ${_statusLabel(l10n, member)}',
      ),
      trailing: pending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (member.status == MembershipStatus.active)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline),
                    tooltip: l10n.actionSuspend,
                    onPressed: () => _runToggle(context, suspend: true),
                  ),
                if (member.status == MembershipStatus.suspended)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.actionReactivate,
                    onPressed: () => _runToggle(context, suspend: false),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.platformAdminDeleteDemo,
                  onPressed: () => _confirmAndDelete(context),
                ),
              ],
            ),
    );
  }

  Future<void> _runToggle(BuildContext context, {required bool suspend}) async {
    final PlatformAdminCubit cubit = context.read<PlatformAdminCubit>();
    final OrgFailureKind? kind = suspend
        ? await cubit.suspendMembership(
            organizationId: member.organizationId,
            userId: member.userId,
          )
        : await cubit.reactivateMembership(
            organizationId: member.organizationId,
            userId: member.userId,
          );
    if (!context.mounted) {
      return;
    }
    if (kind != null) {
      _showActionError(context, kind);
    }
  }

  /// Prompts before the destructive delete; the server refuses the caller's
  /// own account (never self). Typed denials surface as localized messages.
  Future<void> _confirmAndDelete(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.platformAdminDeleteConfirmTitle,
      content: Text(l10n.platformAdminDeleteConfirmBody(member.displayName)),
      confirmLabel: l10n.platformAdminDeleteConfirmAction,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final OrgFailureKind? kind = await context
        .read<PlatformAdminCubit>()
        .deleteDemoAccount(userId: member.userId);
    if (!context.mounted) {
      return;
    }
    if (kind != null) {
      _showActionError(context, kind);
    }
  }

  void _showActionError(BuildContext context, OrgFailureKind kind) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(orgErrorMessage(AppLocalizations.of(context), kind)),
      ),
    );
  }

  String _initial(String displayName) =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  String _statusLabel(AppLocalizations l10n, OrgMember member) {
    return switch (member.status) {
      MembershipStatus.invited => l10n.memberStatusInvited,
      MembershipStatus.active => l10n.memberStatusActive,
      MembershipStatus.suspended => l10n.memberStatusSuspended,
      MembershipStatus.removed => l10n.memberStatusRemoved,
    };
  }
}
