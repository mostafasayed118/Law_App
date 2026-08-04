import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../data/auth/supabase_auth_api.dart';
import '../domain/sign_up_gateway.dart';
import '../domain/sign_up_request.dart';

/// Real sign-up backed by the Supabase provider via the [SupabaseAuthApi]
/// seam — the only provider-touching file. Registered instead of
/// [FakeSignUpGateway] when the build is configured with a Supabase URL +
/// anon key (`--dart-define-from-file=.env`).
///
/// Privacy contract: on failure the [AppError] context is built from
/// [SignUpRequest.toRedactedMap], so the password, email, and phone never
/// reach diagnostics in clear text (ADR-0003).
class SupabaseSignUpGateway implements SignUpGateway {
  SupabaseSignUpGateway(this._api);

  final SupabaseAuthApi _api;

  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    try {
      await _api.signUp(
        email: request.email,
        password: request.password,
        metadata: <String, String>{
          // display_name is what the applied handle_new_user trigger reads
          // (02_rls_functions.sql:77) so the profile row carries the real
          // name; full_name/phone stay for client-side display resolution.
          'display_name': request.name,
          'full_name': request.name,
          'phone': request.phone,
        },
      );
      return const Result<void>.success(null);
    } on SupabaseAuthException catch (e) {
      return Result<void>.failure(
        AppError(
          code: e.kind.name,
          userMessage: _messageFor(e),
          context: request.toRedactedMap(),
        ),
      );
    }
  }

  /// Locale-agnostic safe fallback text; the code is the stable key for a
  /// future localized mapping. Precedent: AuthCubit._handleFailure uses
  /// English fallbacks for the same reason.
  String _messageFor(SupabaseAuthException e) {
    return switch (e.kind) {
      SupabaseAuthFailureKind.emailInUse =>
        'An account with this email already exists. Try signing in.',
      SupabaseAuthFailureKind.rateLimited =>
        'Too many attempts. Please wait and try again.',
      SupabaseAuthFailureKind.userDisabled => 'This account has been disabled.',
      SupabaseAuthFailureKind.invalidCredentials ||
      SupabaseAuthFailureKind.emailNotConfirmed ||
      SupabaseAuthFailureKind.unknown =>
        'Sign-up failed. Please check your details and try again.',
    };
  }
}
