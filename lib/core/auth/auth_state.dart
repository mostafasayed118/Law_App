import 'package:equatable/equatable.dart';

import '../errors/app_error.dart';
import 'auth_gateway.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  const AuthState({required this.status, this.session, this.error});

  const AuthState.initial() : this(status: AuthStatus.initial);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final Session? session;
  final AppError? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => <Object?>[
    status,
    session?.id,
    session?.role,
    error,
  ];
}
