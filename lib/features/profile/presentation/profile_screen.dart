import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/session.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/roles/user_role.dart';
import '../../../core/state/view_state.dart';
import '../../../features/auth/presentation/auth_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/view_state_view.dart';

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

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateFormat expiresFormat = DateFormat.yMMMd(l10n.localeName).add_jm();
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
          title: Text(_roleLabel(l10n, session.primaryRole)),
          subtitle: Text(l10n.profileRoleLabel),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(expiresFormat.format(session.expiresAt)),
          subtitle: Text(l10n.profileExpiresLabel),
        ),
      ],
    );
  }

  /// UX-only projection of the active membership's organization-scoped role.
  /// Mirrors the settings-screen mapping; duplicated here per the approved
  /// slice (shared extraction is a flagged follow-up, ADR-0004 second use).
  String _roleLabel(AppLocalizations l10n, UserRole? role) {
    return switch (role) {
      UserRole.attorney => l10n.roleAttorney,
      UserRole.partner => l10n.rolePartner,
      UserRole.complianceOfficer => l10n.roleComplianceOfficer,
      UserRole.researchAnalyst => l10n.roleResearchAnalyst,
      UserRole.admin => l10n.roleAdmin,
      UserRole.client || null => l10n.roleClient,
    };
  }
}
