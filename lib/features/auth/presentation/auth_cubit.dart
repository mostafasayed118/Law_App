import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_gateway.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/observability/error_reporter.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._gateway, this._reporter)
    : super(_initialState(_gateway.currentSession));

  final AuthGateway _gateway;
  final ErrorReporter _reporter;

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
    final AuthOutcome<Session> outcome = await _gateway.restore();
    await _applySessionOutcome(outcome);
  }

  Future<void> startDemoSession() async {
    if (state.status == AuthStatus.loading || state.isAuthenticated) {
      return;
    }
    emit(const AuthState(status: AuthStatus.loading));
    final AuthOutcome<Session> outcome = await _gateway.startDemoSession();
    await _applySessionOutcome(outcome);
  }

  Future<void> _applySessionOutcome(AuthOutcome<Session> outcome) async {
    switch (outcome) {
      case AuthSuccess<Session>(value: final Session session):
        emit(AuthState(status: AuthStatus.authenticated, session: session));
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
    await _gateway.signOut();
    if (!isClosed) {
      emit(const AuthState.unauthenticated());
    }
  }
}
