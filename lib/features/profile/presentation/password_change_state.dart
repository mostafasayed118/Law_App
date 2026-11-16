import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';

/// State of the change-password form (ADR-0011).
class PasswordChangeState extends Equatable {
  const PasswordChangeState({
    this.newPassword = '',
    this.confirmation = '',
    this.saving = false,
    this.changed = false,
    this.lastError,
  });

  final String newPassword;
  final String confirmation;
  final bool saving;
  final bool changed;
  final AppError? lastError;

  /// The provider said the session is too old. The surface must say "sign in
  /// again first", not "try again" — retrying the same call cannot succeed.
  bool get needsReauth => lastError?.code == 'password_reauth_required';

  PasswordChangeState copyWith({
    String? newPassword,
    String? confirmation,
    bool? saving,
    bool? changed,
    AppError? lastError,
    bool clearError = false,
  }) {
    return PasswordChangeState(
      newPassword: newPassword ?? this.newPassword,
      confirmation: confirmation ?? this.confirmation,
      saving: saving ?? this.saving,
      changed: changed ?? (this.changed && lastError == null && !clearError),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    newPassword,
    confirmation,
    saving,
    changed,
    lastError,
  ];
}
