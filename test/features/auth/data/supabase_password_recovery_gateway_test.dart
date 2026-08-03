import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/features/auth/data/supabase_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam (codebase convention: fakes
/// over mocks for the auth boundary). Controls each recovery outcome per
/// test; no GoTrue types appear anywhere in the gateway tests.
class _FakeSupabaseAuthApi implements SupabaseAuthApi {
  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();

  SupabaseAuthException? sendError;
  SupabaseAuthException? verifyError;
  SupabaseAuthException? updateError;
  int sendCalls = 0;
  int verifyCalls = 0;
  int updateCalls = 0;
  String? lastEmail;
  String? lastToken;
  String? lastPassword;

  @override
  SupabaseAuthSnapshot? get currentSnapshot => null;

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async => null;

  @override
  Future<SupabaseAuthSnapshot?> signInWithPassword({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, String> metadata,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendRecoveryOtp({required String email}) async {
    sendCalls++;
    lastEmail = email;
    final SupabaseAuthException? error = sendError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    verifyCalls++;
    lastEmail = email;
    lastToken = token;
    final SupabaseAuthException? error = verifyError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    updateCalls++;
    lastPassword = newPassword;
    final SupabaseAuthException? error = updateError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async => _changes.close();
}

void main() {
  final PasswordRecoveryRequest request = PasswordRecoveryRequest.fromRaw(
    email: 'amira@example.com',
    otp: '123456',
    newPassword: 'new-secret-pass',
  );

  group('SupabasePasswordRecoveryGateway.requestCode', () {
    test('sends the recovery OTP for the email on success', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi();
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.requestCode(
        email: 'amira@example.com',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.sendCalls, 1);
      expect(api.lastEmail, 'amira@example.com');
    });

    test(
      'treats the signups-for-otp rejection as a non-enumerating success ack',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
          ..sendError = const SupabaseAuthException(
            kind: SupabaseAuthFailureKind.unknown,
            message: 'Signups not allowed for otp',
          );
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.requestCode(
          email: 'nobody@example.com',
        );

        // An unknown address must never reveal that no account exists.
        expect(outcome.isSuccess, isTrue);
      },
    );

    test(
      'maps rateLimited to a failure with the wait-and-retry message',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
          ..sendError = const SupabaseAuthException(
            kind: SupabaseAuthFailureKind.rateLimited,
          );
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.requestCode(
          email: 'amira@example.com',
        );

        expect(outcome.isSuccess, isFalse);
        expect(outcome.errorOrNull?.code, 'rateLimited');
        expect(
          outcome.errorOrNull?.userMessage,
          'Too many attempts. Please wait and try again.',
        );
      },
    );

    test('the failure context is redacted (email never leaks)', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
        ..sendError = const SupabaseAuthException(
          kind: SupabaseAuthFailureKind.unknown,
          message: 'boom',
        );
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.requestCode(
        email: 'amira@example.com',
      );

      expect(outcome.errorOrNull!.context['email'], '[REDACTED]');
    });
  });

  group('SupabasePasswordRecoveryGateway.verifyCode', () {
    test('verifies the emailed code with email and OTP on success', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi();
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.verifyCode(
        email: 'amira@example.com',
        otp: '123456',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.verifyCalls, 1);
      expect(api.lastEmail, 'amira@example.com');
      expect(api.lastToken, '123456');
    });

    test(
      'maps invalidCredentials to the incorrect-or-expired message',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
          ..verifyError = const SupabaseAuthException(
            kind: SupabaseAuthFailureKind.invalidCredentials,
            message: 'Token has expired or is invalid',
          );
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.verifyCode(
          email: 'amira@example.com',
          otp: '000000',
        );

        expect(outcome.isSuccess, isFalse);
        expect(
          outcome.errorOrNull?.userMessage,
          'That code is incorrect or has expired. Please try again.',
        );
      },
    );

    test('the failure context redacts email and OTP', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
        ..verifyError = const SupabaseAuthException(
          kind: SupabaseAuthFailureKind.unknown,
          message: 'boom',
        );
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.verifyCode(
        email: 'amira@example.com',
        otp: '123456',
      );

      expect(outcome.errorOrNull!.context['email'], '[REDACTED]');
      expect(outcome.errorOrNull!.context['otp'], '[REDACTED]');
    });
  });

  group('SupabasePasswordRecoveryGateway.reset', () {
    test('updates the password on success', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi();
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.reset(request);

      expect(outcome.isSuccess, isTrue);
      expect(api.updateCalls, 1);
      expect(api.lastPassword, 'new-secret-pass');
    });

    test(
      'maps invalidCredentials to the verification-expired message',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
          ..updateError = const SupabaseAuthException(
            kind: SupabaseAuthFailureKind.invalidCredentials,
          );
        final SupabasePasswordRecoveryGateway gateway =
            SupabasePasswordRecoveryGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.reset(request);

        expect(outcome.isSuccess, isFalse);
        expect(
          outcome.errorOrNull?.userMessage,
          'Your verification has expired. Please start over.',
        );
      },
    );

    test('the failure context is the redacted request map', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi()
        ..updateError = const SupabaseAuthException(
          kind: SupabaseAuthFailureKind.unknown,
          message: 'boom',
        );
      final SupabasePasswordRecoveryGateway gateway =
          SupabasePasswordRecoveryGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.reset(request);

      final Map<String, Object?> context = outcome.errorOrNull!.context;
      expect(context['email'], '[REDACTED]');
      expect(context['otp'], '[REDACTED]');
      expect(context['newPassword'], '[REDACTED]');
    });
  });
}
