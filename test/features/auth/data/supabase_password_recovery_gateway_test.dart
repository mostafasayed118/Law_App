import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/features/auth/data/supabase_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam for the recovery-gateway
/// tests. Each step resolves through the configurable [result]; remaining
/// methods are inert stubs (codebase convention: fakes over mocks at the auth
/// boundary).
class _FakeAuthApi implements SupabaseAuthApi {
  _FakeAuthApi(this.result);

  final SupabaseAuthResult result;

  String? capturedEmail;
  String? capturedCode;
  String? capturedNewPassword;

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
  }) async => const SupabaseSignUpFailed(
    SupabaseAuthFailure(kind: SupabaseAuthFailureKind.unknown),
  );

  @override
  Future<SupabaseAuthResult> resetPasswordForEmail(String email) async {
    capturedEmail = email;
    return result;
  }

  @override
  Future<SupabaseAuthResult> verifyOtp({
    required String email,
    required String code,
  }) async {
    capturedEmail = email;
    capturedCode = code;
    return result;
  }

  @override
  Future<SupabaseAuthResult> updateUserPassword(String newPassword) async {
    capturedNewPassword = newPassword;
    return result;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> dispose() async => _changes.close();
}

void main() {
  group('SupabasePasswordRecoveryGateway', () {
    test(
      'sendCode delegates the email and maps success to a generic success',
      () async {
        final _FakeAuthApi api = _FakeAuthApi(const SupabaseAuthSuccess(null));
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);

        final Result<void> result = await gateway.sendCode('amira@example.com');

        expect(result.isSuccess, isTrue);
        expect(api.capturedEmail, 'amira@example.com');
      },
    );

    test(
      'sendCode maps every failure to one generic denial (non-enumerating)',
      () async {
        final _FakeAuthApi api = _FakeAuthApi(
          const SupabaseAuthFailed(
            SupabaseAuthFailure(kind: SupabaseAuthFailureKind.unknown),
          ),
        );
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);

        final Result<void> result = await gateway.sendCode('amira@example.com');

        // The provider failure is never echoed: a wrong/expired/revoked code
        // and an unknown account all resolve to the same generic denial (plan
        // §7 — no enumeration).
        expect(result.errorOrNull?.code, 'recovery_failed');
      },
    );

    test('verifyCode delegates email and code', () async {
      final _FakeAuthApi api = _FakeAuthApi(const SupabaseAuthSuccess(null));
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);

      final Result<void> result = await gateway.verifyCode(
        email: 'amira@example.com',
        code: '123456',
      );

      expect(result.isSuccess, isTrue);
      expect(api.capturedEmail, 'amira@example.com');
      expect(api.capturedCode, '123456');
    });

    test(
      'verifyCode maps a wrong-code failure to the generic denial',
      () async {
        final _FakeAuthApi api = _FakeAuthApi(
          const SupabaseAuthFailed(
            SupabaseAuthFailure(kind: SupabaseAuthFailureKind.unknown),
          ),
        );
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);

        final Result<void> result = await gateway.verifyCode(
          email: 'amira@example.com',
          code: '000000',
        );

        expect(result.errorOrNull?.code, 'recovery_failed');
      },
    );

    test('reset delegates the new password to updateUserPassword', () async {
      final _FakeAuthApi api = _FakeAuthApi(const SupabaseAuthSuccess(null));
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);

      final Result<void> result = await gateway.reset(
        const PasswordRecoveryRequest(
          email: 'amira@example.com',
          otp: '123456',
          newPassword: 'new-password-1',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(api.capturedNewPassword, 'new-password-1');
    });

    test('reset maps a failure to the generic denial', () async {
      final _FakeAuthApi api = _FakeAuthApi(
        const SupabaseAuthFailed(
          SupabaseAuthFailure(kind: SupabaseAuthFailureKind.rateLimited),
        ),
      );
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);

      final Result<void> result = await gateway.reset(
        const PasswordRecoveryRequest(
          email: 'amira@example.com',
          otp: '123456',
          newPassword: 'new-password-1',
        ),
      );

      expect(result.errorOrNull?.code, 'recovery_failed');
    });
  });
}
