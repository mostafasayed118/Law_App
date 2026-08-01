import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/sample_service.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/data/auth/supabase_auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_env.dart';
import 'package:legalhub/data/local/locale_store.dart';
import 'package:legalhub/features/auth/data/fake_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/data/fake_sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/booking/data/fake_booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam for the DI flip test.
/// The real `SupabaseAuthApiImpl.bind()` needs a running `Supabase.instance`,
/// which no test should spin up — the flip's test seam injects this instead.
class _FakeSupabaseAuthApi implements SupabaseAuthApi {
  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();

  @override
  SupabaseAuthSnapshot? get currentSnapshot => null;

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> dispose() async => _changes.close();
}

/// Builds a JWT-shaped string whose payload carries the given role claim.
/// Matches the base64url convention used by the supabase adapter tests.
String _jwtWithRole(String role) {
  final String header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final String payload = base64Url
      .encode(utf8.encode('{"iss":"supabase","role":"$role"}'))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

/// Builds a JWT-shaped string whose payload carries `role: anon` — a valid
/// anon-public-key shape for the guard, without any real credential.
String _anonJwt() => _jwtWithRole('anon');

void main() {
  // Ensure a clean locator between tests; GetIt is a process-global singleton.
  tearDown(resetServiceLocator);

  group('configureDependencies (B3 DI foundation)', () {
    test('registers SampleService', () {
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
    });

    test('resolves SampleService as a lazy singleton', () {
      configureDependencies();

      final SampleService first = serviceLocator<SampleService>();
      final SampleService second = serviceLocator<SampleService>();

      // Lazy singleton: same instance across resolutions.
      expect(identical(first, second), isTrue);
      expect(first.name, 'SampleService');
    });

    test('is idempotent when called more than once', () {
      configureDependencies();
      // Calling again must not throw (guard prevents double registration).
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
    });

    test('throws when resolving an unregistered dependency', () {
      // Before configureDependencies() runs, nothing is registered.
      expect(() => serviceLocator<SampleService>(), throwsStateError);
    });
  });

  // The full DI graph: configureDependencies() registers every application
  // dependency. The earlier group only proved SampleService. These tests pin
  // each registration so a future refactor that drops a wiring line fails
  // loudly instead of breaking at runtime in a screen test.
  group('configureDependencies full registration graph', () {
    test('registers every application dependency', () {
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
      expect(serviceLocator.isRegistered<AuthGateway>(), isTrue);
      expect(serviceLocator.isRegistered<ErrorReporter>(), isTrue);
      expect(serviceLocator.isRegistered<LocaleStore>(), isTrue);
      expect(serviceLocator.isRegistered<LocaleCubit>(), isTrue);
      expect(serviceLocator.isRegistered<PasswordRecoveryGateway>(), isTrue);
      expect(serviceLocator.isRegistered<SignUpGateway>(), isTrue);
      expect(serviceLocator.isRegistered<BookingGateway>(), isTrue);
      expect(serviceLocator.isRegistered<AuthCubit>(), isTrue);
    });

    test('resolves each dependency as a lazy singleton (stable instance)', () {
      configureDependencies();

      // Stateful app-scoped cubits must resolve to the same instance across
      // calls; the router and MaterialApp depend on that identity.
      expect(
        identical(serviceLocator<LocaleCubit>(), serviceLocator<LocaleCubit>()),
        isTrue,
      );
      expect(
        identical(serviceLocator<AuthCubit>(), serviceLocator<AuthCubit>()),
        isTrue,
      );
      // Stateless services are also lazy singletons.
      expect(
        identical(
          serviceLocator<PasswordRecoveryGateway>(),
          serviceLocator<PasswordRecoveryGateway>(),
        ),
        isTrue,
      );
      expect(
        identical(
          serviceLocator<BookingGateway>(),
          serviceLocator<BookingGateway>(),
        ),
        isTrue,
      );
    });

    test('wires the recovery gateway to the fake dev implementation', () {
      configureDependencies();

      // The dev-only fake is the registered seam; a real backend is a later
      // approved data-layer slice. Pinning the concrete type catches a future
      // swap that forgets to update this test.
      expect(
        serviceLocator<PasswordRecoveryGateway>(),
        isA<FakePasswordRecoveryGateway>(),
      );
    });

    test('wires the sign-up gateway to the fake dev implementation', () {
      configureDependencies();

      // Same boundary discipline as the recovery gateway: the dev fake is the
      // registered seam and real sign-up remains a later approved slice.
      expect(serviceLocator<SignUpGateway>(), isA<FakeSignUpGateway>());
    });

    test('wires the booking gateway to the fake dev implementation', () {
      configureDependencies();

      // F2: same boundary discipline as the recovery/sign-up gateways — the
      // dev fake is the registered seam; a real booking backend is a later
      // approved data-layer slice (data contract deferred).
      expect(serviceLocator<BookingGateway>(), isA<FakeBookingGateway>());
    });

    test('stays on the credential-free fake when no env is injected', () {
      configureDependencies();

      // With no build-time env (tests, env-less runs) the flip keeps the
      // fake. Asserting the concrete type pins the unconfigured default so a
      // future change that flips the default breaks loudly.
      expect(serviceLocator<AuthGateway>(), isA<FakeAuthGateway>());
    });

    test('flips to SupabaseAuthGateway when env carries an anon key', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
      );

      expect(serviceLocator<AuthGateway>(), isA<SupabaseAuthGateway>());
    });

    test('refuses a non-anon key at configure time (Batch 3.3 guard)', () {
      expect(
        () => configureDependencies(
          supabaseEnv: SupabaseEnv(
            url: 'https://example.supabase.co',
            anonKey: _jwtWithRole('service_role'),
          ),
          supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
        ),
        throwsStateError,
      );

      // Nothing must be wired when the guard refused the key.
      expect(serviceLocator.isRegistered<AuthGateway>(), isFalse);
    });

    test('refuses an undecodable anon-key value at configure time', () {
      expect(
        () => configureDependencies(
          supabaseEnv: SupabaseEnv(
            url: 'https://example.supabase.co',
            anonKey: 'not-a-jwt',
          ),
          supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
        ),
        throwsStateError,
      );
    });

    test('constructs AuthCubit from the registered gateway and reporter', () {
      configureDependencies();

      final AuthCubit cubit = serviceLocator<AuthCubit>();

      // AuthCubit is app-scoped and observes one session seam. The fake
      // gateway has no session at construction, so the cubit starts
      // unauthenticated (not "initial" — _initialState maps a null session
      // straight to unauthenticated).
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.status, AuthStatus.unauthenticated);
    });

    test('clears every registration on resetServiceLocator', () async {
      configureDependencies();
      expect(serviceLocator.isRegistered<SampleService>(), isTrue);

      await resetServiceLocator();

      expect(serviceLocator.isRegistered<SampleService>(), isFalse);
      expect(serviceLocator.isRegistered<AuthCubit>(), isFalse);
      expect(serviceLocator.isRegistered<LocaleCubit>(), isFalse);
    });
  });
}
