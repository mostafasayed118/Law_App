import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_gateway.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/observability/error_reporter.dart';
import '../../../core/organizations/membership_repository.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._gateway, this._reporter, this._membershipRepository)
    : super(_initialState(_gateway.currentSession)) {
    // The provider callback handler (Phase 4.1): a session that arrives
    // through the gateway's stream — e.g. the PKCE exchange of a recovery
    // deep link, which never goes through an explicit cubit call — must
    // reach the app state so the router can react to it.
    _sessionSubscription = _gateway.sessionChanges.listen(_onSessionChange);
  }

  final AuthGateway _gateway;
  final ErrorReporter _reporter;

  /// RLS-scoped membership source for [Session.memberships] hydration
  /// (P3.2): called on every explicit authenticated outcome, never on a
  /// failure, never on an expired session (AC-3).
  final MembershipRepository _membershipRepository;
  late final StreamSubscription<Session?> _sessionSubscription;

  /// True while an explicit operation ([restore], [signIn], [startDemoSession],
  /// [signOut]) is awaiting its gateway outcome.
  ///
  /// The gateway stream replays the session during these calls, and the
  /// replay's emission would preempt the explicit outcome mapping. Letting
  /// the outcome mapping own the emission keeps the state change on the
  /// caller's zone (widget tests construct the cubit outside the FakeAsync
  /// zone; a replay emit there would be delivered to nobody). The listener
  /// therefore only applies provider-initiated changes (the deep-link PKCE
  /// exchange), which never go through an explicit call.
  bool _explicitOperationInFlight = false;

  /// True while the current session is a password-recovery session (Phase
  /// 4.1 deep-link variant). Mirrors the gateway's provider-derived signal
  /// (GoTrue `passwordRecovery` event or a pending `recovery_sent_at`), so
  /// the router can land a recovery session on the reset step instead of
  /// treating it as a normal sign-in. Clears on sign-out.
  bool get recoveryPending => _gateway.recoveryPending;

  /// Bootstrap initial state is derived from the gateway's current session.
  /// There is no provider restore at boot (no session source exists yet), so
  /// a null current session is honestly `unauthenticated`, not `restoring`.
  /// An already-expired current session must not boot into `authenticated`
  /// (contract §5: expiry → re-authentication, never a misleading
  /// authenticated state).
  static AuthState _initialState(Session? session) {
    if (session == null) {
      return const AuthState.unauthenticated();
    }
    if (session.isExpired) {
      return const AuthState(status: AuthStatus.reauthRequired);
    }
    return AuthState(status: AuthStatus.authenticated, session: session);
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

  /// Contract-§5 authenticated mapping + P3.2 membership hydration.
  ///
  /// The loading/restoring status is held until hydration resolves (scope
  /// §7 mitigation — no intermediate authenticated-with-empty render).
  /// Hydration is best-effort enrichment of an already-authenticated
  /// session: a provider-reported empty list stays the honest `[]` (plan
  /// §6), and a failed read still authenticates the session (it is never
  /// invalidated) but is surfaced through the diagnostic channel (Task 8
  /// review inputs). Expiry is honored before hydration (AC-3): an expired
  /// session re-authenticates and is never hydrated.
  ///
  /// Known limitation (recorded): there is no first-class `hydrate()` retry
  /// seam for an already-authenticated session — the next explicit auth op
  /// re-hydrates; retry UI is a screen concern (scope §6). The provider
  /// stream path (Phase 4.1 deep-link) maps without hydration by design.
  Future<void> _applyAuthenticatedSession(Session session) async {
    if (session.isExpired) {
      emit(const AuthState(status: AuthStatus.reauthRequired));
      return;
    }
    final MembershipHydrationResult result = await _membershipRepository
        .loadMemberships(userId: session.userId);
    switch (result) {
      case HydrationSucceeded(:final List<OrganizationMembership> memberships):
        _emitIfChanged(
          AuthState(
            status: AuthStatus.authenticated,
            session: _withMemberships(session, memberships),
          ),
        );
      case HydrationFailed(:final MembershipHydrationFailureKind kind):
        // Honest empty — never a fabricated membership; the session stays
        // authenticated with the gateway snapshot's memberships. The
        // diagnostic report must never gate this emission (a throwing
        // reporter must not strand the session in loading), so the state is
        // emitted first and the report is best-effort.
        _emitIfChanged(
          AuthState(
            status: AuthStatus.authenticated,
            session: _withMemberships(
              session,
              const <OrganizationMembership>[],
            ),
          ),
        );
        await _reportHydrationFailure(kind);
    }
  }

  /// Rebuilds [session] with the hydrated memberships (identity, display
  /// name, and expiry are carried unchanged — only the RLS-scoped
  /// membership view is refreshed).
  Session _withMemberships(
    Session session,
    List<OrganizationMembership> memberships,
  ) => Session(
    userId: session.userId,
    displayName: session.displayName,
    memberships: memberships,
    expiresAt: session.expiresAt,
  );

  /// Diagnostic-channel report (Task 8 review input 2 — the ErrorReporter
  /// seam instead of repository debugPrint). Best-effort by contract: the
  /// authenticated session is emitted before this runs, and a throwing
  /// reporter must never surface as a failure, so the report is wrapped.
  Future<void> _reportHydrationFailure(
    MembershipHydrationFailureKind kind,
  ) async {
    try {
      await _reporter.report(
        AppError(
          code: 'membershipHydrationFailed',
          userMessage: 'Organization memberships could not be loaded.',
          context: <String, Object?>{'kind': kind.name},
        ),
      );
    } catch (error) {
      // Diagnostics must not break the already-emitted authenticated state.
      debugPrint('AuthCubit: hydration diagnostic report failed: $error');
    }
  }

  /// Emits [next] only when it actually differs from the current state.
  ///
  /// The gateway stream replays the session after explicit operations (the
  /// fake emits on `startDemoSession`/`signOut`), so the same [AuthState]
  /// can arrive from both the stream listener and the outcome mapping;
  /// re-emitting an equal state would just churn the router refresh.
  void _emitIfChanged(AuthState next) {
    if (!isClosed && next != state) {
      emit(next);
    }
  }

  /// Applies a provider-initiated session change (the auth callback handler).
  ///
  /// Mirrors the [AuthOutcome] mapping so the app state stays consistent no
  /// matter how the session arrived: a null session is honestly
  /// `unauthenticated`, an expired one `reauthRequired`, and a valid one
  /// `authenticated` (contract §5). Emits only on an actual change; the
  /// gateway stream also replays the session after explicit operations, and
  /// re-emitting an equal [AuthState] would just churn the router refresh.
  void _onSessionChange(Session? session) {
    if (isClosed || _explicitOperationInFlight) {
      return;
    }
    _emitIfChanged(_stateFor(session));
  }

  AuthState _stateFor(Session? session) {
    if (session == null) {
      return const AuthState.unauthenticated();
    }
    if (session.isExpired) {
      return const AuthState(status: AuthStatus.reauthRequired);
    }
    return AuthState(status: AuthStatus.authenticated, session: session);
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
}
