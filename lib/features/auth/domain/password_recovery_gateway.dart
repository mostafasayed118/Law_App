import '../../../core/errors/result.dart';
import 'password_recovery_request.dart';

/// Password-recovery integration boundary.
///
/// Mirrors the credential-free discipline of [AuthGateway]: this bootstrap
/// deliberately has no real recovery backend. A fake/in-memory implementation
/// is registered for dev so the presentation layer can exercise the
/// `ViewState` flow; no real credential, OTP, or password data crosses this
/// boundary yet.
///
/// Real recovery (provider-backed OTP, password persistence, rate limits,
/// non-enumerating acknowledgement) remains blocked behind the P0 product/legal
/// decisions in `docs/auth_tenant_authorization_contract.md` §10. The method
/// accepts the redaction-safe [PasswordRecoveryRequest] so any diagnostic the
/// caller builds can use [PasswordRecoveryRequest.toRedactedMap] for
/// `AppError.context` without leaking the OTP or new password.
abstract interface class PasswordRecoveryGateway {
  Future<Result<void>> reset(PasswordRecoveryRequest request);
}
