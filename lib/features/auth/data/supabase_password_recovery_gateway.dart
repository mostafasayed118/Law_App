import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../data/auth/supabase_auth_api.dart';
import '../domain/password_recovery_gateway.dart';
import '../domain/password_recovery_request.dart';

/// [PasswordRecoveryGateway] backed by the DTO-free [SupabaseAuthApi] seam
/// (P3.1).
///
/// Every step resolves to a **generic, non-enumerating** response (plan §7):
/// the provider never reveals whether an account exists (send-code ack), and
/// wrong/expired/revoked codes resolve to one generic denial. The client
/// never echoes provider details, so an attacker cannot use the recovery flow
/// to enumerate accounts.
class SupabasePasswordRecoveryGateway implements PasswordRecoveryGateway {
  SupabasePasswordRecoveryGateway(this._api);

  final SupabaseAuthApi _api;

  @override
  Future<Result<void>> sendCode(String email) async {
    final SupabaseAuthResult result = await _api.resetPasswordForEmail(email);
    return _map(result);
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  }) async {
    final SupabaseAuthResult result = await _api.verifyOtp(
      email: email,
      code: code,
    );
    return _map(result);
  }

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    final SupabaseAuthResult result = await _api.updateUserPassword(
      request.newPassword,
    );
    return _map(result);
  }

  /// Maps the typed API result to a generic domain [Result]. Failure always
  /// carries the same generic message — one non-enumerating denial for every
  /// failure mode (plan §7).
  Result<void> _map(SupabaseAuthResult result) {
    switch (result) {
      case SupabaseAuthSuccess():
        return const Result<void>.success(null);
      case SupabaseAuthFailed():
        return Result<void>.failure(
          const AppError(
            code: 'recovery_failed',
            userMessage:
                'We couldn\'t complete that request. Please try again.',
          ),
        );
    }
  }
}
