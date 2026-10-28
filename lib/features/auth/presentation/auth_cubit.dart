import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/observability/app_log.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
part 'auth_cubit_base.dart';
part 'auth_cubit_hydration.dart';

class AuthCubit extends _AuthCubitBase with _AuthHydration {
  AuthCubit(
    super.gateway,
    super.reporter,
    super.membershipRepository,
    super.organizationGateway,
  ) {
    // The provider callback handler (Phase 4.1): a session that arrives
    // through the gateway's stream — e.g. the PKCE exchange of a recovery
    // deep link, which never goes through an explicit cubit call — must
    // reach the app state so the router can react to it.
    _sessionSubscription = _gateway.sessionChanges.listen(_onSessionChange);
  }

  /// Contract-§5 restore: `restoring` → authenticated / unauthenticated /
  /// reauthRequired / error. Resolves an expired session to [AuthStatus
  /// .reauthRequired] instead of a misleading authenticated state.
  ///
  /// [hydrateMemberships] defaults to true (every explicit auth outcome
  /// hydrates). Bootstrap passes false: the membership read is a network call
  /// and must not hold the first frame (audit 2026-10-27, F2) — the router is
  /// created and `runApp` runs on the local session, then [hydrate] fills the
  /// RLS-scoped memberships in the background.
  Future<void> restore({bool hydrateMemberships = true}) async {
    if (state.status == AuthStatus.restoring ||
        state.status == AuthStatus.loading) {
      return;
    }
    emit(const AuthState(status: AuthStatus.restoring));
    _explicitOperationInFlight = true;
    try {
      final AuthOutcome<Session> outcome = await _gateway.restore();
      await _applySessionOutcome(
        outcome,
        hydrateMemberships: hydrateMemberships,
      );
    } finally {
      _explicitOperationInFlight = false;
    }
  }

  /// Credential sign-in (contract §5): `loading` → authenticated /
  /// unauthenticated / reauthRequired / error. With the dev fake the same
  /// call resolves to the demo session; with a configured provider it signs
  /// in with the entered credentials.
  Future<void> signIn({required String email, required String password}) async {
    if (state.status == AuthStatus.loading || state.isAuthenticated) {
      return;
    }
    emit(const AuthState(status: AuthStatus.loading));
    _explicitOperationInFlight = true;
    try {
      final AuthOutcome<Session> outcome = await _gateway.signIn(
        email: email,
        password: password,
      );
      await _applySessionOutcome(outcome);
    } finally {
      _explicitOperationInFlight = false;
    }
  }

  /// Google OAuth sign-in (browser hand-off).
  ///
  /// The flow is two-legged and this call owns only the first: launching the
  /// provider browser. A `true` launch returns the surface to signed-out while
  /// the user consents — the authenticated session arrives later through the
  /// gateway stream (the callback observer's PKCE exchange), which
  /// [_onSessionChange] maps without needing this call to stay in flight.
  /// A `false` launch is a real failure and takes the normal error path.
  Future<void> signInWithGoogle() async {
    if (state.status == AuthStatus.loading || state.isAuthenticated) {
      return;
    }
    emit(const AuthState(status: AuthStatus.loading));
    _explicitOperationInFlight = true;
    try {
      final bool launched = await _gateway.startGoogleSignIn();
      if (!launched) {
        await _handleFailure(
          const AuthFailure(
            kind: AuthFailureKind.providerUnavailable,
            message: 'Google sign-in could not be started.',
          ),
        );
        return;
      }
      // The browser owns the flow now. Drop the loading state so the pending
      // callback (which may take a while) does not look like a hung request.
      _emitIfChanged(const AuthState.unauthenticated());
    } finally {
      _explicitOperationInFlight = false;
    }
  }

  Future<void> startDemoSession() async {
    if (state.status == AuthStatus.loading || state.isAuthenticated) {
      return;
    }
    emit(const AuthState(status: AuthStatus.loading));
    _explicitOperationInFlight = true;
    try {
      final AuthOutcome<Session> outcome = await _gateway.startDemoSession();
      await _applySessionOutcome(outcome);
    } finally {
      _explicitOperationInFlight = false;
    }
  }

  Future<void> _applySessionOutcome(
    AuthOutcome<Session> outcome, {
    bool hydrateMemberships = true,
  }) async {
    switch (outcome) {
      case AuthSuccess<Session>(value: final Session session):
        if (!hydrateMemberships) {
          // Local session only (bootstrap): emit the gateway snapshot
          // immediately; the caller runs [hydrate] once the router is
          // attached. Expiry is still honored by [_stateFor].
          _emitIfChanged(_stateFor(session));
        } else {
          await _applyAuthenticatedSession(session);
        }
      case AuthFailed<Session>(failure: final AuthFailure failure):
        await _handleFailure(failure);
    }
  }

  Future<void> _handleFailure(AuthFailure failure) async {
    switch (failure.kind) {
      case AuthFailureKind.signedOut:
        emit(const AuthState.unauthenticated());
      case AuthFailureKind.sessionExpired:
        emit(const AuthState(status: AuthStatus.reauthRequired));
      case AuthFailureKind.invalidCredentials ||
          AuthFailureKind.emailNotConfirmed ||
          AuthFailureKind.rateLimited ||
          AuthFailureKind.userDisabled ||
          AuthFailureKind.membershipDenied ||
          AuthFailureKind.providerUnavailable ||
          AuthFailureKind.unknown:
        final AppError error = AppError(
          code: failure.kind.name,
          userMessage: failure.message ?? 'Authentication failed',
        );
        await _reporter.report(error);
        emit(AuthState(status: AuthStatus.error, error: error));
    }
  }

  Future<void> signOut() async {
    _explicitOperationInFlight = true;
    try {
      await _gateway.signOut();
    } catch (error) {
      // The provider already dropped the local session before it threw
      // (GoTrue's order), so a transport failure must never leave the app
      // locally authenticated (audit 2026-10-27, F4). Surface it on the
      // diagnostic channel and continue to the unauthenticated emission.
      AppLog.diagnostic(
        'AuthCubit: provider sign-out failed; local session cleared: $error',
      );
    } finally {
      // Invalidate any in-flight [hydrate] refresh (Slice A review fix): a
      // refresh that resolves after sign-out must not re-emit authenticated
      // for the signed-out session.
      _hydrationEpoch += 1;
      // The gateway stream already emitted null (and the listener mapped it);
      // this explicit emission only matters when the gateway is silent or
      // threw, so it is deduped against the current state.
      _emitIfChanged(const AuthState.unauthenticated());
      _explicitOperationInFlight = false;
    }
  }

  @override
  Future<void> close() async {
    await _sessionSubscription.cancel();
    await super.close();
  }

  /// Deletes the caller's own account, then ends the session.
  ///
  /// Session-ending is exactly why this lives here rather than on a
  /// profile-scoped cubit (owner decision OI-D1, 2026-09-22). Returns the typed
  /// failure kind on failure, or null on success.
  ///
  /// Moved from `profile_screen.dart`, which was calling
  /// [OrganizationGateway] directly (audit 2026-09-21, H-4); the
  /// returning-method shape is owner decision OI-D2. The screen keeps the
  /// confirmation dialog and the failure affordance.
  Future<OrgFailureKind?> deleteAccount() async {
    final OrgOutcome<void> outcome = await _organizationGateway
        .deleteMyAccount();
    final OrgFailureKind? kind = outcome.failureOrNull?.kind;
    if (kind == null) {
      // The identity is gone server-side; end the session so the auth gate
      // redirects to sign-in instead of showing a stale identity.
      await signOut();
    }
    return kind;
  }

  /// Accepts an invitation [token], joining the caller to the organization.
  /// Returns the typed failure kind on failure, or null on success.
  ///
  /// The post-accept handoff (re-hydrate, then switch the local active-org
  /// context) deliberately stays in the screen: it snapshots the known
  /// organizations *before* hydrating so it can diff out the joined one, and
  /// the switch itself is the `ActiveOrgStore` concern the screens already own.
  /// Moved from `accept_invitation_screen.dart`, which was calling
  /// [OrganizationGateway] directly (audit 2026-09-21, H-4).
  Future<OrgFailureKind?> acceptInvitation(String token) async {
    final OrgOutcome<String> outcome = await _organizationGateway
        .acceptInvitation(token: token);
    return outcome.failureOrNull?.kind;
  }
}
