import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../l10n/app_localizations.dart';
import 'org_error_messages.dart';

/// Invitation acceptance screen (Phase 2 slice 2.4, R3).
///
/// Token-entry UX decision (scope note §1): a paste-screen in Phase 2; the
/// deep-link variant moves to Phase 4 with the platform intent-filter work.
/// The role is server-owned from the invitation — the client never chooses
/// one; bad tokens surface the localized, non-enumerating
/// `invalidInvitation` message.
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
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final String token = _token.text.trim();
    if (token.isEmpty || _accepting) {
      return;
    }
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
