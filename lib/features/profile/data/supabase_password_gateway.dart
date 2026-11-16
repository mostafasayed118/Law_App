import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/auth/supabase_password_api.dart';
import 'package:legalhub/features/profile/domain/password_gateway.dart';

/// Password change backed by the provider seam (ADR-0011).
class SupabasePasswordGateway implements PasswordGateway {
  SupabasePasswordGateway(this._api);

  final PasswordApi _api;

  @override
  Future<Result<void>> changePassword(String newPassword) async {
    try {
      await _api.changePassword(newPassword);
      return const Result<void>.success(null);
    } on PasswordChangeException catch (e) {
      return Result<void>.failure(
        e.kind == PasswordChangeFailureKind.reauthRequired
            ? PasswordErrors.reauthRequired
            : AppError(
                code: PasswordErrors.unavailableCode,
                userMessage:
                    'Unable to change your password. Please try again.',
                technicalMessage: e.message,
                kind: AppErrorKind.unavailable,
              ),
      );
    }
  }
}
