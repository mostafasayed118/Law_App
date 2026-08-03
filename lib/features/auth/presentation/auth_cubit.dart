import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_gateway.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/observability/error_reporter.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._gateway, this._reporter)
    : super(_initialState(_gateway.currentSession)) {
    // The provider callback handler (Phase 4.1): a session that arrives
    // through the gateway's stream — e.g. the PKCE exchange of a recovery
    // deep link, which never goes through an explicit cubit call — must
    // reach the app state so the router can react to it.
    _sessionSubscription = _gateway.sessionChanges.listen(_onSessionChange);
  }

  final AuthGateway _gateway;
  final ErrorReporter _reporter;
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
        _emitIfChanged(
          AuthState(status: AuthStatus.authenticated, session: session),
        );
      case AuthFailed<Session>(failure: final AuthFailure failure):
        await _handleFailure(failure);
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
