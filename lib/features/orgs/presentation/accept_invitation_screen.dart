import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/deep_link/pending_accept_invite_store.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/auth/session.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'active_org_store.dart';
import 'org_error_messages.dart';

/// Invitation acceptance screen (Phase 2 slice 2.4, R3; P3.4 handoff).
///
/// Token-entry UX decision (scope note §1): a paste-screen in Phase 2; the
/// deep-link variant moves to Phase 4 with the platform intent-filter work
/// (P3.4 D-P34.2 — recorded forward hook; paste is the P3.4 acceptance
/// surface). The role is server-owned from the invitation — the client never
/// chooses one; bad tokens surface the localized, non-enumerating
/// `invalidInvitation` message. On success the accepted membership is not in
/// the session yet, so the screen re-hydrates ([AuthCubit.hydrate] — the
/// P3.3 D-P33.3 seam) and switches the local active-org context to the new
/// organization (D-08 client-side context, membership-backed).
class AcceptInvitationScreen extends StatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  final TextEditingController _token = TextEditingController();
  bool _accepting = false;
  OrgFailureKind? _failure;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    // Phase 4.1 D-P34.2: a deep-linked accept-invitation share link buffers
    // its one-time token in the pending store (cold start / signed-out
    // arrivals). Consume-and-clear it here so the paste screen is
    // pre-filled; the user still taps Accept, exactly like a pasted token
    // (never an auto-submit).
    final String? pendingToken = serviceLocator<PendingAcceptInviteStore>()
        .takePendingToken();
    if (pendingToken != null) {
      _token.text = pendingToken;
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final String token = _token.text.trim();
    if (token.isEmpty || _accepting) {
      return;
    }
    // Read before any await so the accepted handoff can re-hydrate without
    // using the BuildContext across an async gap.
    final AuthCubit auth = context.read<AuthCubit>();
    setState(() {
      _accepting = true;
      _failure = null;
    });
    final OrgOutcome<String> outcome =
        await serviceLocator<OrganizationGateway>().acceptInvitation(
          token: token,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _accepting = false;
      switch (outcome) {
        case OrgSuccess<String>():
          _accepted = true;
        case OrgFailed<String>(failure: final OrgFailure failure):
          _failure = failure.kind;
      }
    });
    if (_accepted) {
      // P3.4 D-P33.3 handoff — best-effort; the accepted state is already
      // shown and never blocked by the refresh.
      await _refreshMembershipAndSwitch(auth);
    }
  }

  /// Post-accept handoff (P3.4): re-hydrates so the accepted membership
  /// joins [Session.memberships], then switches the local active-org context
  /// to the newly-joined organization so the hub lands on it.
  ///
  /// The new org is derived from the hydrated-session diff (the membership
  /// that was not present before the accept) — the session is the membership
  /// authority (D-08), so the derived id is membership-backed before it is
  /// selected. Best-effort by design: a failed refresh keeps the
  /// last-known-good session (reported through the cubit's diagnostic
  /// channel); if the new org cannot be resolved, the switch is skipped and
  /// the membership still arrives on the next auth op.
  Future<void> _refreshMembershipAndSwitch(AuthCubit auth) async {
    final List<String> knownOrganizationIds = <String>[
      for (final OrganizationMembership membership
          in auth.state.session?.memberships ??
              const <OrganizationMembership>[])
        membership.organizationId,
    ];
    await auth.hydrate();
    String? joinedOrganizationId;
    for (final OrganizationMembership membership
        in auth.state.session?.memberships ??
            const <OrganizationMembership>[]) {
      if (!knownOrganizationIds.contains(membership.organizationId)) {
        joinedOrganizationId = membership.organizationId;
        break;
      }
    }
    if (joinedOrganizationId != null) {
      serviceLocator<ActiveOrgStore>().select(joinedOrganizationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.acceptInvitationTitle)),
      body: _accepted
          ? _buildAccepted(context, l10n)
          : _buildForm(context, l10n),
    );
  }

  Widget _buildAccepted(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(
              l10n.invitationAccepted,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.invitationAcceptedBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    final OrgFailureKind? failure = _failure;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.acceptInvitationBody),
          const SizedBox(height: LegalHubTheme.spaceMd),
          TextField(
            controller: _token,
            enabled: !_accepting,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.inviteTokenLabel,
              errorText: failure == null
                  ? null
                  : orgErrorMessage(AppLocalizations.of(context), failure),
            ),
            onSubmitted: (_) => _accept(),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          FilledButton(
            onPressed: _accepting ? null : _accept,
            child: _accepting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.acceptInvitationAction),
          ),
        ],
      ),
    );
  }
}
