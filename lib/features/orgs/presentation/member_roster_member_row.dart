part of 'member_roster_screen.dart';

/// One roster row: identity, role + status chips, and — for partners — the
/// management menu. Suspended/removed members render dimmed.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.isPartner,
    required this.pending,
    required this.onAction,
  });

  final OrgMember member;
  final bool isSelf;
  final bool isPartner;
  final bool pending;
  final ValueChanged<OrgMemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool inactive =
        member.status == MembershipStatus.suspended ||
        member.status == MembershipStatus.removed;
    return Opacity(
      opacity: inactive ? 0.55 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            member.displayName.isEmpty
                ? '?'
                : member.displayName.substring(0, 1).toUpperCase(),
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
        title: Text(member.displayName),
        subtitle: Wrap(
          spacing: LegalHubTheme.spaceXs,
          runSpacing: LegalHubTheme.spaceXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _RoleChip(role: member.role),
            _StatusChip(status: member.status),
          ],
        ),
        trailing: pending
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _actionsMenu(context),
      ),
    );
  }

  Widget _actionsMenu(BuildContext context) {
    if (!isPartner) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool invited = member.status == MembershipStatus.invited;
    return PopupMenuButton<OrgMemberAction>(
      onSelected: onAction,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<OrgMemberAction>>[
        PopupMenuItem(
          value: OrgMemberAction.changeRoleToClient,
          child: Text(l10n.roleClient),
        ),
        PopupMenuItem(
          value: OrgMemberAction.changeRoleToAttorney,
          child: Text(l10n.roleAttorney),
        ),
        PopupMenuItem(
          value: OrgMemberAction.changeRoleToPartner,
          child: Text(l10n.rolePartner),
        ),
        // Suspension/reactivation and removal apply to members, not pending
        // invites; invited rows get the invite lifecycle instead (Phase 2
        // slice 2.1): resend rotates the token, revoke retires the pending
        // invite. Both need the invitation id the read surface exposes.
        if (!invited && member.status == MembershipStatus.active)
          PopupMenuItem(
            value: OrgMemberAction.suspend,
            child: Text(l10n.actionSuspend),
          ),
        if (!invited && member.status == MembershipStatus.suspended)
          PopupMenuItem(
            value: OrgMemberAction.reactivate,
            child: Text(l10n.actionReactivate),
          ),
        if (!invited && !isSelf)
          PopupMenuItem(
            value: OrgMemberAction.remove,
            child: Text(l10n.actionRemove),
          ),
        if (invited &&
            member.invitationId != null) ...<PopupMenuEntry<OrgMemberAction>>[
          PopupMenuItem(
            value: OrgMemberAction.resendInvitation,
            child: Text(l10n.actionResendInvitation),
          ),
          PopupMenuItem(
            value: OrgMemberAction.revokeInvitation,
            child: Text(l10n.actionRevokeInvitation),
          ),
        ],
      ],
    );
  }
}
