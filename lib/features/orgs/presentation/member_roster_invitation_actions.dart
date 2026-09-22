part of 'member_roster_screen.dart';

/// The invitation-lifecycle actions of the roster state (resend / revoke
/// / the one-time token dialog), kept as extension members of the state
/// class so every call site and `mounted`/`context` access stays unchanged.
extension _MemberInvitationActions on _MemberRosterScreenState {
  /// Resends a pending invite: the fresh one-time token is shown once with a
  /// copy affordance (out-of-band delivery — the server stores only the
  /// sha-256 hash). Typed failures surface as localized snackbars.
  Future<void> _resendInvitation(OrgCubit cubit, OrgMember member) async {
    final String? invitationId = member.invitationId;
    if (invitationId == null || !mounted) {
      return;
    }
    final OrgInviteActionResult result = await cubit.resendInvitation(
      organizationId: widget.organizationId,
      invitationId: invitationId,
      email: member.displayName,
    );
    if (!mounted) {
      return;
    }
    switch (result) {
      case OrgInviteActionSuccess(token: final String token):
        await _showTokenDialog(token, member.displayName);
      case OrgInviteActionFailure(kind: final OrgFailureKind? kind):
        if (kind != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                orgErrorMessage(AppLocalizations.of(context), kind),
              ),
            ),
          );
        }
    }
  }

  /// Revokes a pending invite; the revoked row leaves the roster on the next
  /// refresh. Success and typed failures surface as localized snackbars.
  Future<void> _revokeInvitation(OrgCubit cubit, OrgMember member) async {
    final String? invitationId = member.invitationId;
    if (invitationId == null || !mounted) {
      return;
    }
    final OrgFailureKind? kind = await cubit.revokeInvitation(
      organizationId: widget.organizationId,
      invitationId: invitationId,
      email: member.displayName,
    );
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kind == null ? l10n.invitationRevoked : orgErrorMessage(l10n, kind),
        ),
      ),
    );
  }

  /// Shows a one-time token with a copy affordance. The token is presented
  /// once and never stored client-side beyond this dialog.
  Future<void> _showTokenDialog(String token, String email) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.inviteMember),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.inviteTokenResentBody(email)),
            const SizedBox(height: LegalHubTheme.spaceMd),
            SelectableText(token, textAlign: TextAlign.center),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(l10n.inviteTokenCopied)));
              }
            },
            child: Text(l10n.inviteTokenCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }
}
