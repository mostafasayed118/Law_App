import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/deep_link/app_link_parser.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/widgets.dart';
import 'org_error_messages.dart';

/// Opens the invite-member bottom sheet for one organization.
///
/// Resolves to `true` when an invitation was minted (the token was shown and
/// acknowledged), so the roster can reload and the pending invited row
/// appears; resolves to `null`/`false` when dismissed without inviting.
Future<bool?> showInviteMemberSheet(
  BuildContext context, {
  required String organizationId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        InviteMemberSheet(organizationId: organizationId),
  );
}

/// Invite-member sheet (P3 slice 1.3).
///
/// Email + assignable role (client/attorney/partner only); on success the
/// one-time token is shown once with a copy affordance (out-of-band
/// delivery — the server stores only the sha-256 hash). Typed failures
/// (duplicate member, denied) surface inline as localized messages.
class InviteMemberSheet extends StatefulWidget {
  const InviteMemberSheet({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<InviteMemberSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  UserRole _role = UserRole.client;
  bool _sending = false;
  InviteResult? _invite;
  OrgFailureKind? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.inviteMember,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              if (_invite == null)
                _buildForm(context)
              else
                _buildToken(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LegalHubTextField(
            controller: _email,
            label: l10n.inviteEmailLabel,
            hint: l10n.emailPlaceholder,
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (String? value) => LegalHubValidators.email(l10n, value),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: InputDecoration(labelText: l10n.inviteRoleLabel),
            items: <DropdownMenuItem<UserRole>>[
              for (final UserRole role in <UserRole>[
                UserRole.client,
                UserRole.attorney,
                UserRole.partner,
              ])
                DropdownMenuItem<UserRole>(
                  value: role,
                  child: Text(roleLabel(l10n, role)),
                ),
            ],
            onChanged: (UserRole? value) {
              if (value != null) {
                setState(() => _role = value);
              }
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          if (_failure != null) ...<Widget>[
            Text(
              orgErrorMessage(l10n, _failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
          ],
          ElevatedButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(l10n.inviteSendButton),
          ),
        ],
      ),
    );
  }

  Widget _buildToken(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final InviteResult invite = _invite!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.inviteTokenBody(invite.email), textAlign: TextAlign.center),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Container(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.all(
              Radius.circular(LegalHubTheme.radiusMd),
            ),
          ),
          child: SelectableText(
            invite.token,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        FilledButton.icon(
          onPressed: () => _copyShareLink(invite.token),
          icon: const Icon(Icons.link_outlined, size: 18),
          label: Text(l10n.inviteShareLink),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        OutlinedButton.icon(
          onPressed: () => _copyToken(invite.token),
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: Text(l10n.inviteTokenCopy),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.back),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    final OrgOutcome<InviteResult> outcome =
        await serviceLocator<OrganizationGateway>().inviteMember(
          organizationId: widget.organizationId,
          email: _email.text.trim(),
          role: _role,
        );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    switch (outcome) {
      case OrgSuccess<InviteResult>(value: final InviteResult invite):
        setState(() => _invite = invite);
      case OrgFailed<InviteResult>(failure: final OrgFailure failure):
        setState(() => _failure = failure.kind);
    }
  }

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).inviteTokenCopied)),
    );
  }

  /// Copies the full accept-deep-link URI for [token] to the clipboard
  /// (D-P34.2 produce side). The link is built on-demand via
  /// [AppLinkParser.acceptInviteUri] from the same scheme/host constants the
  /// consume side classifies with, so every produced link round-trips through
  /// `parse` as an `AcceptInviteIntent` with the identical token. The token
  /// itself is never stored or logged beyond the sheet's existing one-shot
  /// `_invite` state.
  Future<void> _copyShareLink(String token) async {
    final Uri link = AppLinkParser.acceptInviteUri(token);
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).inviteShareLinkCopied),
      ),
    );
  }
}
