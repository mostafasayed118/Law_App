import 'package:equatable/equatable.dart';

import '../../../core/observability/error_reporter.dart';

/// Transient, backend-free password-recovery request value object.
///
/// Carries the three fields captured across the forgot-password flow (email
/// from step 1, OTP from step 2, new password from step 3). It is a pure-domain
/// object: it performs no network or persistence work and is safe to construct
/// in tests.
///
/// Privacy contract (decision: redaction is mandatory, not optional):
/// - [newPassword] must never appear in clear text in any diagnostic surface.
/// - [otp] is a short-lived credential and must be masked before diagnostics
///   are stored.
/// - [email] is PII and must be masked before diagnostics are stored.
/// - [toRedactedMap] produces a map that is already sanitized and safe to
///   feed into [AppError.context]; passing it back through [Redactor.map] is
///   idempotent.
///
/// This object is intentionally not yet wired into the forgot-password
/// presentation. Wiring it requires a real recovery gateway (or a recovery use
/// case backed by one), which remains blocked behind the P0 product/legal
/// decisions documented in `auth_tenant_authorization_contract.md`. It is the
/// next slice after the `SignUpRequest` redaction contract (ADR-0003) and
/// follows the same test-first, privacy-by-design discipline.
class PasswordRecoveryRequest extends Equatable {
  const PasswordRecoveryRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  /// Builds a request from raw form input, normalizing whitespace and casing.
  ///
  /// [email] is trimmed and lower-cased to match the canonical stored form.
  /// [otp] is trimmed of surrounding whitespace only (internal characters are
  /// preserved). [newPassword] is trimmed of surrounding whitespace only
  /// (internal characters are preserved).
  factory PasswordRecoveryRequest.fromRaw({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return PasswordRecoveryRequest(
      email: email.trim().toLowerCase(),
      otp: otp.trim(),
      newPassword: newPassword.trim(),
    );
  }

  final String email;
  final String otp;
  final String newPassword;

  /// A diagnostic-safe map representation.
  ///
  /// Delegates to [Redactor.map] so the same privacy policy that governs
  /// [AppError.toLogMap] applies here: `email`, `otp`, and `newPassword` are
  /// masked, and any embedded email/bearer patterns inside string values are
  /// scrubbed. The returned map is safe to embed in [AppError.context].
  Map<String, Object?> toRedactedMap() => Redactor.map(<String, Object?>{
    'email': email,
    'otp': otp,
    'newPassword': newPassword,
  });

  @override
  List<Object?> get props => <Object?>[email, otp, newPassword];
}
