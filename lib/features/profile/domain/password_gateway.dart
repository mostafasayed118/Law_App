import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';

/// Changes the signed-in user's password (ADR-0011).
///
/// One narrow action, separate from the auth gateway: settings owns it and the
/// auth gateway owns session transitions. Returns [Result] so the settings cubit
/// maps `reauthRequired` to "sign in again first" instead of a generic retry.
abstract interface class PasswordGateway {
  Future<Result<void>> changePassword(String newPassword);
}

abstract final class PasswordErrors {
  static const String reauthCode = 'password_reauth_required';
  static const String unavailableCode = 'password_unavailable';

  static const AppError reauthRequired = AppError(
    code: reauthCode,
    userMessage: 'Sign in again before changing your password.',
    kind: AppErrorKind.denied,
  );

  static const AppError unavailable = AppError(
    code: unavailableCode,
    userMessage: 'Unable to change your password. Please try again.',
    kind: AppErrorKind.unavailable,
  );
}
