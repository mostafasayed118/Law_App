import 'package:equatable/equatable.dart';

import '../../../core/observability/error_reporter.dart';

/// Transient, backend-free sign-up request value object.
///
/// Carries the four bootstrap auth fields captured by the sign-up form (name,
/// email, phone, password). It is a pure-domain object: it performs no
/// network or persistence work and is safe to construct in tests.
///
/// Privacy contract (decision: redaction is mandatory, not optional):
/// - [password] must never appear in clear text in any diagnostic surface.
/// - [email] and [phone] are PII and must be masked before diagnostics are
///   stored.
/// - [toRedactedMap] produces a map that is already sanitized and safe to
///   feed into [AppError.context]; passing it back through [Redactor.map] is
///   idempotent.
///
/// This object is intentionally not yet wired into [SignUpScreen]. Wiring it
/// to the presentation layer is a follow-up slice that depends on a real
/// [AuthGateway], which remains blocked behind the P0 product/legal decisions
/// documented in `auth_tenant_authorization_contract.md`.
class SignUpRequest extends Equatable {
  const SignUpRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  /// Builds a request from raw form input, normalizing whitespace and casing.
  ///
  /// [name] is trimmed. [email] is trimmed and lower-cased to match the
  /// canonical stored form. [phone] is trimmed. [password] is trimmed of
  /// surrounding whitespace only (internal characters are preserved).
  factory SignUpRequest.fromRaw({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return SignUpRequest(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      password: password.trim(),
    );
  }

  final String name;
  final String email;
  final String phone;
  final String password;

  /// A diagnostic-safe map representation.
  ///
  /// Delegates to [Redactor.map] so the same privacy policy that governs
  /// [AppError.toLogMap] applies here: `password`, `email`, and `phone` are
  /// masked, and any embedded email/bearer patterns inside string values are
  /// scrubbed. The returned map is safe to embed in [AppError.context].
  Map<String, Object?> toRedactedMap() => Redactor.map(<String, Object?>{
    'name': name,
    'email': email,
    'phone': phone,
    'password': password,
  });

  @override
  List<Object?> get props => <Object?>[name, email, phone, password];
}
