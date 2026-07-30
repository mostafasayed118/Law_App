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
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    // Simulate the async work without touching any backend. The request is
    // intentionally unused: real recovery is a later, approved data-layer slice.
    return Result<void>.success(null);
  }
}
