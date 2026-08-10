import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/auth/session.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/roles/user_role.dart';
import '../../../features/auth/presentation/auth_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import 'invite_member_sheet.dart';
import 'org_cubit.dart';
import 'org_error_messages.dart';

/// Member roster for one organization (P3 slice 1.2 + 1.4).
///
/// Rows show identity + role/status chips, with suspended/removed members
/// visually distinct and invited rows listed for pending invites. Partner
/// rows get the management menu (change role / suspend / reactivate /
/// remove) and the invite entry point; every action goes through the
/// [OrgCubit] and the server stays the authority — failures surface as
/// localized, non-sensitive messages (P3 spec §4).
class MemberRosterScreen extends StatefulWidget {
  const MemberRosterScreen({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<MemberRosterScreen> createState() => _MemberRosterScreenState();
}

class _MemberRosterScreenState extends State<MemberRosterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final OrgState state = context.read<OrgCubit>().state;
      // Load whenever the roster is not already visible or in flight — this
      // also covers arriving from the create flow (OrgCreateSuccess).
      if (state is! OrgRosterLoaded && state is! OrgRosterLoading) {
        context.read<OrgCubit>().loadRoster(
          organizationId: widget.organizationId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Session? session = context.watch<AuthCubit>().state.session;
    final bool isPartner = session?.primaryRole == UserRole.partner;
    final String? orgName = _orgNameFor(session, widget.organizationId);
    return Scaffold(
      appBar: AppBar(title: Text(orgName ?? l10n.rosterTitle)),
      floatingActionButton: isPartner
          ? FloatingActionButton.extended(
              onPressed: _openInviteSheet,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.inviteMember),
            )
          : null,
      body: BlocBuilder<OrgCubit, OrgState>(
        builder: (BuildContext context, OrgState state) {
          switch (state) {
            case OrgRosterLoaded(
              members: final List<OrgMember> members,
              pendingUserId: final String? pendingUserId,
            ):
              if (members.isEmpty) {
                return Center(child: Text(l10n.rosterEmpty));
              }
              return ListView.separated(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  LegalHubTheme.marginMobile,
                  LegalHubTheme.spaceMd,
                  LegalHubTheme.marginMobile,
                  LegalHubTheme.spaceXl * 2,
                ),
                itemCount: members.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: LegalHubTheme.spaceSm),
                itemBuilder: (BuildContext context, int index) {
                  final OrgMember member = members[index];
                  return _MemberRow(
                    member: member,
                    isSelf: member.userId == session?.userId,
                    isPartner: isPartner,
                    pending: member.userId == pendingUserId,
                    onAction: (OrgMemberAction action) =>
                        _runAction(action, member),
                  );
                },
              );
            case OrgRosterFailed(error: _, kind: final OrgFailureKind kind):
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline,
                      size: 32,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                    Text(
                      orgErrorMessage(l10n, kind),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                    TextButton(
                      onPressed: () => context.read<OrgCubit>().loadRoster(
                        organizationId: widget.organizationId,
                      ),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            case OrgRosterLoading() ||
                OrgInitial() ||
                OrgCreateLoading() ||
                OrgCreateSuccess() ||
                OrgCreateFailed():
              return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  /// Opens the invite sheet; on success (token delivered) the roster reloads
  /// so the pending invited row appears.
  Future<void> _openInviteSheet() async {
    final bool? invited = await showInviteMemberSheet(
      context,
      organizationId: widget.organizationId,
    );
    if (!mounted) {
      return;
    }
    if (invited == true) {
      await context.read<OrgCubit>().loadRoster(
        organizationId: widget.organizationId,
      );
    }
  }

  /// Runs a partner-only member action; a typed failure surfaces as the
  /// localized message (last-partner guard, denied, …) via snackbar. Removal
  /// is destructive and requires explicit confirmation (roadmap slice 1.4).
  Future<void> _runAction(OrgMemberAction action, OrgMember member) async {
    if (action == OrgMemberAction.remove) {
      final bool? confirmed = await _confirmRemove(member);
      if (confirmed != true || !mounted) {
        return;
      }
    }
    final OrgCubit cubit = context.read<OrgCubit>();
    if (action == OrgMemberAction.resendInvitation) {
      await _resendInvitation(cubit, member);
      return;
    }
    if (action == OrgMemberAction.revokeInvitation) {
      await _revokeInvitation(cubit, member);
      return;
    }
    final OrgFailureKind? kind = switch (action) {
      OrgMemberAction.changeRoleToClient => await cubit.changeMemberRole(
        organizationId: widget.organizationId,
        userId: member.userId,
        role: UserRole.client,
      ),
      OrgMemberAction.changeRoleToAttorney => await cubit.changeMemberRole(
        organizationId: widget.organizationId,
        userId: member.userId,
        role: UserRole.attorney,
      ),
      OrgMemberAction.changeRoleToPartner => await cubit.changeMemberRole(
        organizationId: widget.organizationId,
        userId: member.userId,
        role: UserRole.partner,
      ),
      OrgMemberAction.suspend => await cubit.suspendMember(
        organizationId: widget.organizationId,
        userId: member.userId,
      ),
      OrgMemberAction.reactivate => await cubit.reactivateMember(
        organizationId: widget.organizationId,
        userId: member.userId,
      ),
      OrgMemberAction.remove => await cubit.removeMember(
        organizationId: widget.organizationId,
        userId: member.userId,
      ),
      OrgMemberAction.resendInvitation ||
      OrgMemberAction.revokeInvitation => null,
    };
    if (!mounted) {
      return;
    }
    if (kind != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orgErrorMessage(AppLocalizations.of(context), kind)),
        ),
      );
    }
  }

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

  /// Prompts for confirmation before a destructive removal. Resolves to true
  /// only when the partner explicitly confirms; cancel/dismiss/back all
  /// resolve to false, and the member is left untouched.
  Future<bool?> _confirmRemove(OrgMember member) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showConfirmDialog(
      context: context,
      title: l10n.removeMemberConfirmTitle,
      content: Text(l10n.removeMemberConfirmBody(member.displayName)),
      confirmLabel: l10n.removeMemberConfirmAction,
    );
  }

  String? _orgNameFor(Session? session, String organizationId) {
    if (session == null) {
      return null;
    }
    for (final OrganizationMembership membership in session.memberships) {
      if (membership.organizationId == organizationId) {
        // Null org name (suspended/removed membership) → the AppBar already
        // falls back to the localized roster title.
        return membership.organizationName;
      }
    }
    return null;
  }
}

/// The partner-only actions offered by a member row.
enum OrgMemberAction {
  changeRoleToClient,
  changeRoleToAttorney,
  changeRoleToPartner,
  suspend,
  reactivate,
  remove,
  resendInvitation,
  revokeInvitation,
}

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

/// Small colored chip rendering a member's organization role.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        roleLabel(AppLocalizations.of(context), role),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Small chip rendering a member's lifecycle status with distinct colors:
/// active/invited in container tones, suspended/removed in error tones.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (String label, Color background, Color foreground) = switch (status) {
      MembershipStatus.active => (
        l10n.memberStatusActive,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      MembershipStatus.invited => (
        l10n.memberStatusInvited,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      MembershipStatus.suspended => (
        l10n.memberStatusSuspended,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      MembershipStatus.removed => (
        l10n.memberStatusRemoved,
        scheme.surfaceContainerHighest,
        scheme.outline,
      ),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foreground, letterSpacing: 0.3),
      ),
    );
  }
}
