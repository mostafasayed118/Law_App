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
/// decisions in `docs/auth_tenant_authorization_contract.md` §10. **Recorded
/// decision (2026-08-03, P3 spec §5 D1):** GoTrue's real recovery is an
/// email-link + PKCE-code flow, which requires deep-link registration
/// (platform intent filters + auth callback + router handling) before it can
/// be wired honestly; until that slice exists, recovery stays demo-gated —
/// no half-wired provider path that looks real but dead-ends. The method
/// accepts the redaction-safe [PasswordRecoveryRequest] so any diagnostic the
/// caller builds can use [PasswordRecoveryRequest.toRedactedMap] for
/// `AppError.context` without leaking the OTP or new password.
abstract interface class PasswordRecoveryGateway {
  Future<Result<void>> reset(PasswordRecoveryRequest request);
}
