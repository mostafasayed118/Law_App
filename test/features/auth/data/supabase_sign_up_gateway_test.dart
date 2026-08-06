import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/features/auth/data/supabase_sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam for the sign-up gateway
/// tests. Only the [signUp] path is exercised; the remaining methods are
/// inert stubs (codebase convention: fakes over mocks at the auth boundary).
class _FakeAuthApi implements SupabaseAuthApi {
  _FakeAuthApi(this.signUpResult);

  final SupabaseSignUpResult signUpResult;

  String? capturedEmail;
  String? capturedPassword;
  String? capturedDisplayName;

  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();

  @override
  SupabaseAuthSnapshot? get currentSnapshot => null;

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async => null;

  @override
  Future<SupabaseAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async => const SupabaseAuthFailed(
    SupabaseAuthFailure(kind: SupabaseAuthFailureKind.unknown),
  );

  @override
  Future<SupabaseSignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    capturedEmail = email;
    capturedPassword = password;
    capturedDisplayName = displayName;
    return signUpResult;
  }

  @override
  Future<SupabaseAuthResult> resetPasswordForEmail(String email) async =>
      const SupabaseAuthSuccess(null);

  @override
  Future<SupabaseAuthResult> verifyOtp({
    required String email,
    required String code,
  }) async => const SupabaseAuthSuccess(null);

  @override
  Future<SupabaseAuthResult> updateUserPassword(String newPassword) async =>
      const SupabaseAuthSuccess(null);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> dispose() async => _changes.close();
}

void main() {
  const SignUpRequest request = SignUpRequest(
    name: 'Amira Hassan',
    email: 'amira@example.com',
    phone: '+201234567890',
    password: 'super-secret-123',
  );

  group('SupabaseSignUpGateway', () {
    test('maps pending email confirmation to the success state', () async {
      final _FakeAuthApi api = _FakeAuthApi(const SupabaseSignUpPending());
      final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);

      final Result<void> result = await gateway.submit(request);

      expect(result.isSuccess, isTrue);
      // The display name travels as raw_user_meta_data.display_name so the
      // applied handle_new_user trigger creates the profile with the real
      // name (plan §4).
      expect(api.capturedEmail, 'amira@example.com');
      expect(api.capturedPassword, 'super-secret-123');
      expect(api.capturedDisplayName, 'Amira Hassan');
    });

    test(
      'maps an immediate authenticated session to the success state',
      () async {
        final _FakeAuthApi api = _FakeAuthApi(
          SupabaseSignUpAuthenticated(
            const SupabaseAuthSnapshot(userId: 'u-1', displayName: 'Amira'),
          ),
        );
        final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);

        final Result<void> result = await gateway.submit(request);

        expect(result.isSuccess, isTrue);
      },
    );

    test(
      'maps email-in-use to a typed AppError with the redacted context',
      () async {
        final _FakeAuthApi api = _FakeAuthApi(
          const SupabaseSignUpFailed(
            SupabaseAuthFailure(
              kind: SupabaseAuthFailureKind.emailInUse,
              message: 'User already registered',
            ),
          ),
        );
        final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);

        final Result<void> result = await gateway.submit(request);

        expect(result.isSuccess, isFalse);
        // ADR-0003: the failure context is the redacted request map, never raw
        // credentials.
        expect(result.errorOrNull?.code, 'emailInUse');
        expect(result.errorOrNull?.context['password'], '[REDACTED]');
        expect(result.errorOrNull?.context['email'], '[REDACTED]');
      },
    );

    test('maps a provider-unavailable failure to the typed AppError', () async {
      final _FakeAuthApi api = _FakeAuthApi(
        const SupabaseSignUpFailed(
          SupabaseAuthFailure(
            kind: SupabaseAuthFailureKind.providerUnavailable,
          ),
        ),
      );
      final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);

      final Result<void> result = await gateway.submit(request);

      expect(result.errorOrNull?.code, 'providerUnavailable');
    });
  });
}
