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
part 'member_roster_actions.dart';
part 'member_roster_member_row.dart';
part 'member_roster_role_chip.dart';
part 'member_roster_status_chip.dart';
part 'member_roster_invitation_actions.dart';

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
      cubit: context.read<OrgCubit>(),
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
