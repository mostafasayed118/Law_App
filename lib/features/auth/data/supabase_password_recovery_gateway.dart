import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/observability/error_reporter.dart';
import '../../../data/auth/supabase_auth_api.dart';
import '../domain/password_recovery_gateway.dart';
import '../domain/password_recovery_request.dart';

/// Real password recovery backed by the Supabase provider via the
/// [SupabaseAuthApi] seam — the provider-touching path behind the
/// [PasswordRecoveryGateway]. Registered instead of
/// [FakePasswordRecoveryGateway] when the build is configured with a Supabase
/// URL + anon key (`--dart-define-from-file=.env`).
///
/// Uses the code-based GoTrue variant (send OTP → verify OTP → change
/// password), which needs no deep links (decision 2026-08-03, D1 revised).
///
/// **Dashboard requirement (verified live 2026-08-03):** the provider renders
/// the OTP email from the *Magic Link* template, which by default contains
/// only `{{ .ConfirmationURL }}`. For the code to reach the user's inbox the
/// template must also render `{{ .Token }}` (Authentication → Email Templates
/// → Magic Link). The provider rejects unknown addresses with a
/// signups-for-otp error, which [requestCode] maps to a non-enumerating
/// success ack.
///
/// Privacy contract: on failure the [AppError] context is built from
/// redacted maps — [Redactor.map] for the email/OTP steps and
/// [PasswordRecoveryRequest.toRedactedMap] for the reset step — so the email,
/// OTP, and new password never reach diagnostics in clear text (ADR-0003).
class SupabasePasswordRecoveryGateway implements PasswordRecoveryGateway {
  SupabasePasswordRecoveryGateway(this._api);

  final SupabaseAuthApi _api;

  /// The provider's stable rejection for an unknown address with
  /// `create_user: false`. Mapped to a success ack so callers never learn
  /// whether an account exists (non-enumerating acknowledgement).
  static const String _unknownAccountMarker = 'signups not allowed for otp';

  @override
  Future<Result<void>> requestCode({required String email}) async {
    try {
      await _api.sendRecoveryOtp(email: email);
      return const Result<void>.success(null);
    } on SupabaseAuthException catch (e) {
      if (e.message?.toLowerCase().contains(_unknownAccountMarker) ?? false) {
        return const Result<void>.success(null);
      }
      return Result<void>.failure(
        AppError(
          code: e.kind.name,
          userMessage: _requestMessageFor(e),
          context: Redactor.map(<String, Object?>{'email': email}),
        ),
      );
    }
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String otp,
  }) async {
    try {
      await _api.verifyRecoveryOtp(email: email, token: otp);
      return const Result<void>.success(null);
    } on SupabaseAuthException catch (e) {
      return Result<void>.failure(
        AppError(
          code: e.kind.name,
          userMessage: _verifyMessageFor(e),
          context: Redactor.map(<String, Object?>{'email': email, 'otp': otp}),
        ),
      );
    }
  }

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    try {
      await _api.updatePassword(newPassword: request.newPassword);
      return const Result<void>.success(null);
    } on SupabaseAuthException catch (e) {
      return Result<void>.failure(
        AppError(
          code: e.kind.name,
          userMessage: _resetMessageFor(e),
          context: request.toRedactedMap(),
        ),
      );
    }
  }

  /// Locale-agnostic safe fallback text; the code is the stable key for a
  /// future localized mapping. Precedent: AuthCubit._handleFailure uses
  /// English fallbacks for the same reason.
  String _requestMessageFor(SupabaseAuthException e) {
    return switch (e.kind) {
      SupabaseAuthFailureKind.rateLimited =>
        'Too many attempts. Please wait and try again.',
      SupabaseAuthFailureKind.invalidCredentials ||
      SupabaseAuthFailureKind.emailNotConfirmed ||
      SupabaseAuthFailureKind.emailInUse ||
      SupabaseAuthFailureKind.userDisabled ||
      SupabaseAuthFailureKind.unknown =>
        'Unable to send a code right now. Please try again.',
    };
  }

  String _verifyMessageFor(SupabaseAuthException e) {
    return switch (e.kind) {
      SupabaseAuthFailureKind.rateLimited =>
        'Too many attempts. Please wait and try again.',
      SupabaseAuthFailureKind.invalidCredentials =>
        'That code is incorrect or has expired. Please try again.',
      SupabaseAuthFailureKind.emailNotConfirmed ||
      SupabaseAuthFailureKind.emailInUse ||
      SupabaseAuthFailureKind.userDisabled ||
      SupabaseAuthFailureKind.unknown =>
        'Unable to verify the code. Please try again.',
    };
  }

  String _resetMessageFor(SupabaseAuthException e) {
    return switch (e.kind) {
      SupabaseAuthFailureKind.rateLimited =>
        'Too many attempts. Please wait and try again.',
      SupabaseAuthFailureKind.invalidCredentials =>
        'Your verification has expired. Please start over.',
      SupabaseAuthFailureKind.emailNotConfirmed ||
      SupabaseAuthFailureKind.emailInUse ||
      SupabaseAuthFailureKind.userDisabled ||
      SupabaseAuthFailureKind.unknown =>
        'Unable to reset your password. Please try again.',
    };
  }
}
