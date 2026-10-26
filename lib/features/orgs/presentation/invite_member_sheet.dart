import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/app/deep_link/deep_link_config.dart';
import 'package:legalhub/app/flavor.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/forms/validators.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'org_cubit.dart';
import 'org_error_messages.dart';

/// Best-effort clipboard wipe for one-time invite payloads.
///
/// Every copy path calls [schedule] so the payload never outlives a 30-second
/// window; the owning widget cancels the timer on dispose and calls
/// [clearIfCurrent] immediately so a surface dismissed early cannot leave the
/// token behind. The current-text check means a value the user copied
/// elsewhere is never overwritten.
class ClipboardAutoClear {
  ClipboardAutoClear._();

  static const Duration delay = Duration(seconds: 30);

  static Timer schedule(String expected) =>
      Timer(delay, () => unawaited(clearIfCurrent(expected)));

  static Future<void> clearIfCurrent(String expected) async {
    try {
      final ClipboardData? current = await Clipboard.getData(
        Clipboard.kTextPlain,
      );
      if (current?.text == expected) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      // Clipboard unavailable — nothing to clear.
    }
  }
}

/// Opens the invite-member bottom sheet for one organization.
///
/// [cubit] is the roster's own [OrgCubit] — passed in and re-provided around
/// the sheet because a modal's context sits under the Navigator, not under the
/// caller's provider scope. The sheet mints the invitation through it rather
/// than calling [OrganizationGateway] itself (audit 2026-09-21, H-4).
///
/// Resolves to `true` when an invitation was minted (the token was shown and
/// acknowledged), so the roster can reload and the pending invited row
/// appears; resolves to `null`/`false` when dismissed without inviting.
Future<bool?> showInviteMemberSheet(
  BuildContext context, {
  required String organizationId,
  required OrgCubit cubit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BlocProvider<OrgCubit>.value(
      value: cubit,
      child: InviteMemberSheet(organizationId: organizationId),
    ),
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

  /// The payload scheduled for the 30s auto-clear, if any. Dispose cancels the
  /// timer (flutter_test forbids leaking one past the tree) and wipes the
  /// payload immediately when the user closes the sheet before it fires.
  String? _clipboardPayload;
  Timer? _clipboardClearTimer;

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = null;
    final String? payload = _clipboardPayload;
    if (payload != null) {
      unawaited(ClipboardAutoClear.clearIfCurrent(payload));
    }
    _email.dispose();
    super.dispose();
  }

  void _scheduleClipboardClear(String expected) {
    _clipboardClearTimer?.cancel();
    _clipboardPayload = expected;
    _clipboardClearTimer = ClipboardAutoClear.schedule(expected);
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
        OutlinedButton(
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
    final OrgOutcome<InviteResult> outcome = await context
        .read<OrgCubit>()
        .inviteMember(
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
    // Bearer-grade one-time token: auto-clear after 30s to limit
    // clipboard-snooping window (OWASP A02). Best-effort only.
    _scheduleClipboardClear(token);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).inviteTokenCopied)),
    );
  }

  /// Copies the full accept-deep-link URI for [token] to the clipboard
  /// (D-P34.2 produce side). The link is built on-demand via
  /// [DeepLinkConfig.acceptInviteUri] from the build's own deep-link scheme,
  /// so every produced link round-trips through the parser as an
  /// `AcceptInviteIntent` with the identical token. The token itself is never
  /// stored or logged beyond the sheet's existing one-shot `_invite` state.
  Future<void> _copyShareLink(String token) async {
    final Uri link = DeepLinkConfig(
      scheme: AppConfig.fromEnvironment().deepLinkScheme,
    ).acceptInviteUri(token);
    final String linkText = link.toString();
    await Clipboard.setData(ClipboardData(text: linkText));
    _scheduleClipboardClear(linkText);
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
