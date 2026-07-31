import '../../../core/errors/result.dart';
import 'sign_up_request.dart';

/// Sign-up integration boundary.
///
/// Mirrors the credential-free discipline of [AuthGateway] and
/// [PasswordRecoveryGateway]: this bootstrap deliberately has no real
/// registration backend. A fake/in-memory implementation is registered for dev
/// so the presentation layer can exercise the submit lifecycle; no real
/// credential, password, or identity data crosses this boundary yet.
///
/// Real sign-up (provider-backed account creation, email verification,
/// duplicate-account handling, consent capture, rate limits) remains blocked
/// behind the P0 product/legal decisions in
/// `docs/auth_tenant_authorization_contract.md` §10. The method accepts the
/// redaction-safe [SignUpRequest] so any diagnostic the caller builds can use
/// [SignUpRequest.toRedactedMap] for `AppError.context` without leaking the
/// password or PII.
abstract interface class SignUpGateway {
  Future<Result<void>> submit(SignUpRequest request);
}
