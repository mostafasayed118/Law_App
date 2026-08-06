import '../../../core/errors/result.dart';
import 'password_recovery_request.dart';

/// Password-recovery integration boundary.
///
/// Mirrors the credential-free discipline of [AuthGateway]: the recovery flow
/// resolves through generic, non-enumerating responses — the provider never
/// reveals whether an account exists, and wrong/expired codes resolve to one
/// generic denial (plan §7, no enumeration). No real credential, OTP, or
/// password data crosses this boundary in clear text; diagnostics use
/// [PasswordRecoveryRequest.toRedactedMap].
abstract interface class PasswordRecoveryGateway {
  /// Step 1 — request a recovery code for [email]. Generic acknowledgement
  /// only; never reveals whether the account exists.
  Future<Result<void>> sendCode(String email);

  /// Step 2 — verify the emailed [code] for [email]. One generic denial
  /// covers wrong/expired/revoked codes (non-enumerating).
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  });

  /// Step 3 — set the new password. [request] carries the redaction-safe
  /// email/OTP/new-password; the generic success is non-enumerating.
  Future<Result<void>> reset(PasswordRecoveryRequest request);
}
