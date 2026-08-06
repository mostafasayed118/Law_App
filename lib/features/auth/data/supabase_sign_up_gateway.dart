import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../data/auth/supabase_auth_api.dart';
import '../domain/sign_up_gateway.dart';
import '../domain/sign_up_request.dart';

/// [SignUpGateway] backed by the DTO-free [SupabaseAuthApi] seam (P3.1).
///
/// Every provider response is mapped strictly below the [SupabaseAuthApi]
/// seam; this gateway only re-shapes typed results into [Result]. The
/// redaction contract (ADR-0003) is preserved: failure contexts are built
/// from [SignUpRequest.toRedactedMap], never from raw provider data.
///
/// Email confirmation is enabled on the dev project, so a successful sign-up
/// resolves to the pending-verification state (no session). The screen renders
/// that as the "check your email" success state — the gateway does not mint a
/// session the user did not verify.
class SupabaseSignUpGateway implements SignUpGateway {
  SupabaseSignUpGateway(this._api);

  final SupabaseAuthApi _api;

  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    final SupabaseSignUpResult result = await _api.signUp(
      email: request.email,
      password: request.password,
      displayName: request.name,
    );
    switch (result) {
      case SupabaseSignUpPending():
        // Email confirmation is enabled (apply evidence §6): pending IS the
        // success state — the screen shows the "check your email" notice.
        return const Result<void>.success(null);
      case SupabaseSignUpAuthenticated():
        return const Result<void>.success(null);
      case SupabaseSignUpFailed(failure: final SupabaseAuthFailure failure):
        return Result<void>.failure(_toAppError(request, failure));
    }
  }

  AppError _toAppError(SignUpRequest request, SupabaseAuthFailure failure) {
    return AppError(
      code: _codeFor(failure.kind),
      userMessage: _messageFor(failure.kind),
      // ADR-0003: the diagnostic context is the redacted map, never raw data.
      context: request.toRedactedMap(),
    );
  }

  String _codeFor(SupabaseAuthFailureKind kind) => switch (kind) {
    SupabaseAuthFailureKind.invalidCredentials => 'invalidCredentials',
    SupabaseAuthFailureKind.emailNotConfirmed => 'emailNotConfirmed',
    SupabaseAuthFailureKind.emailInUse => 'emailInUse',
    SupabaseAuthFailureKind.userDisabled => 'userDisabled',
    SupabaseAuthFailureKind.rateLimited => 'rateLimited',
    SupabaseAuthFailureKind.providerUnavailable => 'providerUnavailable',
    SupabaseAuthFailureKind.unknown => 'unknown',
  };

  String _messageFor(SupabaseAuthFailureKind kind) => switch (kind) {
    SupabaseAuthFailureKind.invalidCredentials => 'Sign up failed',
    SupabaseAuthFailureKind.emailNotConfirmed => 'Please check your email',
    SupabaseAuthFailureKind.emailInUse =>
      'An account with this email already exists',
    SupabaseAuthFailureKind.userDisabled => 'This account is disabled',
    SupabaseAuthFailureKind.rateLimited => 'Too many attempts, try again later',
    SupabaseAuthFailureKind.providerUnavailable =>
      'Sign up is temporarily unavailable',
    SupabaseAuthFailureKind.unknown => 'Sign up failed',
  };
}
