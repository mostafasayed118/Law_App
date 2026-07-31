import 'package:equatable/equatable.dart';

/// Typed reasons an auth operation can fail (contract §5).
enum AuthFailureKind {
  /// No session exists (signed out).
  signedOut,

  /// The session has expired and re-authentication is required.
  sessionExpired,

  /// The provided credentials were rejected.
  invalidCredentials,

  /// The account is disabled.
  userDisabled,

  /// The requested action is denied for the current membership/scope.
  membershipDenied,

  /// The provider/configuration is unavailable.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed, safe auth failure crossing the domain boundary.
///
/// Only the [kind] and a non-sensitive [message] leave the seam. Passwords,
/// tokens, reset codes, and PII must never be carried on this type.
class AuthFailure extends Equatable {
  const AuthFailure({required this.kind, this.message});

  final AuthFailureKind kind;
  final String? message;

  @override
  List<Object?> get props => <Object?>[kind, message];
}

/// Explicit success/failure boundary for auth domain operations.
sealed class AuthOutcome<T> {
  const AuthOutcome._();

  const factory AuthOutcome.success(T value) = AuthSuccess<T>;
  const factory AuthOutcome.failure(AuthFailure failure) = AuthFailed<T>;

  bool get isSuccess => this is AuthSuccess<T>;

  T? get valueOrNull => switch (this) {
    AuthSuccess<T>(value: final value) => value,
    AuthFailed<T>() => null,
  };

  AuthFailure? get failureOrNull => switch (this) {
    AuthSuccess<T>() => null,
    AuthFailed<T>(failure: final failure) => failure,
  };
}

final class AuthSuccess<T> extends AuthOutcome<T> {
  const AuthSuccess(this.value) : super._();

  final T value;
}

final class AuthFailed<T> extends AuthOutcome<T> {
  const AuthFailed(this.failure) : super._();

  final AuthFailure failure;
}
