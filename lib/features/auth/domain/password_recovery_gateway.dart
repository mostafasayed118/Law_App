import '../../../core/errors/result.dart';
import 'password_recovery_request.dart';

/// Password-recovery integration boundary.
///
/// Mirrors the credential-free discipline of [AuthGateway]: in unconfigured
/// builds a fake/in-memory implementation is registered so the presentation
/// layer can exercise the `ViewState` flow; no real credential, OTP, or
/// password data crosses this boundary in that mode. In configured builds the
/// Supabase-backed implementation is registered instead.
///
/// **Recorded decision (2026-08-03, P3 spec §5 D1, revised):** GoTrue's
/// link-based recovery (email-link + PKCE) still requires deep-link
/// registration (platform intent filters + auth callback + router handling)
/// and stays out of scope. However, GoTrue also offers a code-based variant —
/// send OTP → verify OTP → change password — that needs **no deep links**, and
/// that variant is wired here in three explicit steps ([requestCode],
/// [verifyCode], [reset]) so the flow is never half-wired: every screen action
/// maps to a real provider call when configured. The methods accept
/// redaction-safe values (email/OTP) or the redaction-safe
/// [PasswordRecoveryRequest] so any diagnostic the caller builds can use
/// [PasswordRecoveryRequest.toRedactedMap] for `AppError.context` without
/// leaking the OTP or new password.
abstract interface class PasswordRecoveryGateway {
  /// Sends a recovery code to [email]. Non-enumerating: an unknown address is
  /// acknowledged without revealing whether an account exists.
  Future<Result<void>> requestCode({required String email});

  /// Verifies the emailed [otp] for [email]. Succeeds only when the code is
  /// correct and unexpired; this verification authorizes the later [reset].
  Future<Result<void>> verifyCode({required String email, required String otp});

  /// Resets the password for the verified account.
  Future<Result<void>> reset(PasswordRecoveryRequest request);
}
