import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/features/auth/data/supabase_sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam (codebase convention:
/// fakes over mocks for the auth boundary). Controls the sign-up outcome per
/// test; no GoTrue types appear anywhere in the gateway tests.
class _FakeSupabaseAuthApi implements SupabaseAuthApi {
  _FakeSupabaseAuthApi({this.signUpError});

  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();

  SupabaseAuthException? signUpError;
  int signUpCalls = 0;
  String? lastEmail;
  String? lastPassword;
  Map<String, String>? lastMetadata;

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
  }) async {
    signUpCalls++;
    lastEmail = email;
    lastPassword = password;
    lastMetadata = metadata;
    final SupabaseAuthException? error = signUpError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> dispose() async => _changes.close();
}

void main() {
  final SignUpRequest request = SignUpRequest.fromRaw(
    name: 'Amira Hassan',
    email: 'amira@example.com',
    password: 'secret-pass',
    phone: '+201000000000',
  );

  group('SupabaseSignUpGateway.submit', () {
    test(
      'creates the account with full_name/phone metadata on success',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi();
        final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.submit(request);

        expect(outcome.isSuccess, isTrue);
        expect(api.signUpCalls, 1);
        expect(api.lastEmail, 'amira@example.com');
        expect(api.lastPassword, 'secret-pass');
        expect(api.lastMetadata, <String, String>{
          'full_name': 'Amira Hassan',
          'phone': '+201000000000',
        });
      },
    );

    test('maps emailInUse to a failure carrying the stable code', () async {
      final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
        signUpError: const SupabaseAuthException(
          kind: SupabaseAuthFailureKind.emailInUse,
          message: 'User already registered',
        ),
      );
      final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);
      addTearDown(api.dispose);

      final Result<void> outcome = await gateway.submit(request);

      expect(outcome.isSuccess, isFalse);
      expect(outcome.errorOrNull?.code, 'emailInUse');
      expect(
        outcome.errorOrNull?.userMessage,
        'An account with this email already exists. Try signing in.',
      );
    });

    test(
      'maps rateLimited to a failure with the wait-and-retry message',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
          signUpError: const SupabaseAuthException(
            kind: SupabaseAuthFailureKind.rateLimited,
          ),
        );
        final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.submit(request);

        expect(outcome.errorOrNull?.code, 'rateLimited');
        expect(
          outcome.errorOrNull?.userMessage,
          'Too many attempts. Please wait and try again.',
        );
      },
    );

    test(
      'the failure context is the redacted map (password never leaks)',
      () async {
        final _FakeSupabaseAuthApi api = _FakeSupabaseAuthApi(
          signUpError: const SupabaseAuthException(
            kind: SupabaseAuthFailureKind.unknown,
            message: 'boom',
          ),
        );
        final SupabaseSignUpGateway gateway = SupabaseSignUpGateway(api);
        addTearDown(api.dispose);

        final Result<void> outcome = await gateway.submit(request);

        final Map<String, Object?> context = outcome.errorOrNull!.context;
        // Privacy contract (ADR-0003): no clear-text credential in diagnostics.
        expect(context['password'], '[REDACTED]');
        expect(context['email'], '[REDACTED]');
        expect(context['phone'], '[REDACTED]');
        expect(context['name'], 'Amira Hassan');
      },
    );
  });
}
