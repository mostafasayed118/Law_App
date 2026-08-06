import '../../../core/errors/result.dart';
import '../domain/password_recovery_gateway.dart';
import '../domain/password_recovery_request.dart';

/// Development-only password-recovery implementation.
///
/// Like [FakeAuthGateway], this never accepts real credentials: it ignores the
/// request contents and resolves to a local-only success. It is a seam for the
/// `PasswordRecoveryCubit` and presentation tests, not a real recovery mechanism.
/// The OTP and new password in [PasswordRecoveryRequest] are never logged or
/// persisted here; diagnostics should use [PasswordRecoveryRequest.toRedactedMap].
class FakePasswordRecoveryGateway implements PasswordRecoveryGateway {
  @override
  Future<Result<void>> sendCode(String email) async {
    // Simulate the async work without touching any backend. The email is
    // intentionally unused: the dev fake never reveals whether an account
    // exists (same non-enumerating contract as the real gateway).
    return Result<void>.success(null);
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  }) async {
    // Any code is accepted locally; wrong/expired handling is a real-backend
    // behavior. The code is never logged or persisted.
    return Result<void>.success(null);
  }

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    // Simulate the async work without touching any backend. The request is
    // intentionally unused: real recovery is a later, approved data-layer slice.
    return Result<void>.success(null);
  }
}
