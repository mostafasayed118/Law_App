import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/session.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/state/view_state.dart';
import '../../../features/auth/presentation/auth_cubit.dart';
import '../../../features/orgs/presentation/org_error_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// Read-only projection of the authenticated session's identity.
///
/// Consumes the existing [AuthCubit] (no new cubit/state): the screen maps
/// [AuthStatus] onto the shared [ViewState] vocabulary and renders
/// [ViewStateView] for the Loading / Error / Empty / expired branches. It
/// never calls a gateway and never renders stale identity when the session
/// is expired — the router guard redirects unauthenticated users before this
/// screen is reached, and [AuthStatus.reauthRequired] maps to a localized
/// expired-session message instead of a stale profile.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AuthState auth = context.watch<AuthCubit>().state;
    final ViewState<Session> viewState = _map(auth, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileNavigation)),
      body: switch (viewState) {
        ViewSuccess<Session>(data: final Session session) => _ProfileBody(
          session: session,
        ),
        _ => Center(
          // Retry only for a recoverable error: restore() cannot resurrect an
          // expired session, so the expired branch offers no Retry loop.
          child: ViewStateView<Session>(
            state: viewState,
            onRetry:
                viewState is ViewError<Session> &&
                    viewState.error.code != 'sessionExpired'
                ? () => context.read<AuthCubit>().restore()
                : null,
          ),
        ),
      },
    );
  }

  /// Projection of [AuthStatus] onto the shared [ViewState] vocabulary.
  ///
  /// - authenticated → success (the identity body);
  /// - loading/restoring/initial → loading;
  /// - error → the reported [AppError], retryable via [AuthCubit.restore];
  /// - reauthRequired → a localized expired-session message, never stale
  ///   identity data;
  /// - unauthenticated → empty (normally unreachable; the router guard
  ///   redirects first).
  ViewState<Session> _map(AuthState auth, AppLocalizations l10n) {
    final Session? session = auth.session;
    return switch (auth.status) {
      AuthStatus.authenticated when session != null => ViewSuccess(session),
      AuthStatus.authenticated => const ViewEmpty<Session>(),
      AuthStatus.loading ||
      AuthStatus.restoring ||
      AuthStatus.initial => const ViewLoading<Session>(),
      AuthStatus.error when auth.error != null => ViewError(auth.error!),
      AuthStatus.error => ViewError(
        AppError(code: 'unknown', userMessage: l10n.stateError),
      ),
      AuthStatus.reauthRequired => ViewError(
        AppError(
          code: 'sessionExpired',
          userMessage: l10n.profileSessionExpired,
        ),
      ),
      AuthStatus.unauthenticated => const ViewEmpty<Session>(),
    };
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.session});

  final Session session;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _deleting = false;

  /// Deletes the caller's identity (Phase 2 slice 2.2): a redaction-safe
  /// confirm first, then `delete_my_account` (the only removal path — D-05)
  /// and a session sign-out. Every failure surfaces as a localized,
  /// non-sensitive message; the session stays alive until success.
  Future<void> _deleteAccount() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.deleteAccountConfirmTitle),
          content: Text(l10n.deleteAccountConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            // Error-tinted confirm so the destructive action reads as
            // dangerous (M3 pattern), like the member-removal dialog.
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: Text(l10n.deleteAccountConfirmAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    final OrgOutcome<void> outcome = await serviceLocator<OrganizationGateway>()
        .deleteMyAccount();
    if (!mounted) {
      return;
    }
    setState(() => _deleting = false);
    switch (outcome) {
      case OrgSuccess<void>():
        // The identity is gone server-side; end the session so the auth
        // gate redirects to sign-in instead of showing stale identity.
        await context.read<AuthCubit>().signOut();
      case OrgFailed<void>(failure: final OrgFailure failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(orgErrorMessage(l10n, failure.kind))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateFormat expiresFormat = DateFormat.yMMMd(l10n.localeName).add_jm();
    final Session session = widget.session;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(session.displayName),
          subtitle: Text(l10n.profileNameLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text(session.userId),
          subtitle: Text(l10n.profileAccountIdLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.work_outline),
          title: RoleLabel(role: session.primaryRole),
          subtitle: Text(l10n.profileRoleLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(expiresFormat.format(session.expiresAt)),
          subtitle: Text(l10n.profileExpiresLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        const Divider(),
        const SizedBox(height: LegalHubTheme.spaceSm),
        // Account deletion is irreversible and scoped out of the read-only
        // identity surface above; the error-tinted row makes it unmistakable.
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_deleting,
          leading: _deleting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
          title: Text(
            l10n.deleteAccountAction,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: _deleting ? null : _deleteAccount,
        ),
      ],
    );
  }
}
