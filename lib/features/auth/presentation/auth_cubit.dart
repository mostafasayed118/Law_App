import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_gateway.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/observability/error_reporter.dart';
import '../../../core/organizations/membership_repository.dart';
import '../../../core/organizations/organization_gateway.dart';
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
  Future<void> restore() async {
    if (state.status == AuthStatus.restoring ||
        state.status == AuthStatus.loading) {
      return;
    }
    emit(const AuthState(status: AuthStatus.restoring));
    _explicitOperationInFlight = true;
    try {
      final AuthOutcome<Session> outcome = await _gateway.restore();
      await _applySessionOutcome(outcome);
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

  Future<void> _applySessionOutcome(AuthOutcome<Session> outcome) async {
    switch (outcome) {
      case AuthSuccess<Session>(value: final Session session):
        await _applyAuthenticatedSession(session);
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
      // Invalidate any in-flight [hydrate] refresh (Slice A review fix): a
      // refresh that resolves after sign-out must not re-emit authenticated
      // for the signed-out session.
      _hydrationEpoch += 1;
      // The gateway stream already emitted null (and the listener mapped it);
      // this explicit emission only matters when the gateway is silent, so it
      // is deduped against the current state.
      _emitIfChanged(const AuthState.unauthenticated());
    } finally {
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
