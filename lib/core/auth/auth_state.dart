import 'package:equatable/equatable.dart';

import '../errors/app_error.dart';
import 'auth_gateway.dart';

/// Session lifecycle status (contract §5 state diagram).
enum AuthStatus {
  /// No session state known yet (pre-restore).
  initial,

  /// A session restore is in flight.
  restoring,

  /// An auth operation (sign-in/demo start) is in flight.
  loading,

  /// A valid, unexpired session is present.
  authenticated,

  /// No session; the user may sign in.
  unauthenticated,

  /// The session expired and re-authentication is required before protected
  /// access can resume.
  reauthRequired,

  /// The last operation failed.
  error,
}

class AuthState extends Equatable {
  const AuthState({required this.status, this.session, this.error});

  const AuthState.initial() : this(status: AuthStatus.initial);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final Session? session;
  final AppError? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => <Object?>[status, session, error];
}
