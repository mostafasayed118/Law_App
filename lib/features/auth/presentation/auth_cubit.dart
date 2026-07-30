import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_gateway.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/result.dart';
import '../../../core/observability/error_reporter.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._gateway, this._reporter)
    : super(_initialState(_gateway.currentSession));

  final AuthGateway _gateway;
  final ErrorReporter _reporter;

  static AuthState _initialState(Session? session) => session == null
      ? const AuthState.unauthenticated()
      : AuthState(status: AuthStatus.authenticated, session: session);

  Future<void> startDemoSession() async {
    if (state.status == AuthStatus.loading || state.isAuthenticated) {
      return;
    }
    emit(const AuthState(status: AuthStatus.loading));
    final result = await _gateway.startDemoSession();
    if (result case Success(value: final session)) {
      emit(AuthState(status: AuthStatus.authenticated, session: session));
    } else if (result case Failure(error: final error)) {
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
