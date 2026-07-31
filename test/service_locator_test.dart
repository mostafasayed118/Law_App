import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/sample_service.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/locale_store.dart';
import 'package:legalhub/features/auth/data/fake_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/data/fake_sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';

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

  // The full DI graph: configureDependencies() registers eight types. The
  // earlier group only proved SampleService. These tests pin every
  // registration so a future refactor that drops a wiring line fails loudly
  // instead of breaking at runtime in a screen test.
  group('configureDependencies full registration graph', () {
    test('registers all eight application dependencies', () {
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
      expect(serviceLocator.isRegistered<AuthGateway>(), isTrue);
      expect(serviceLocator.isRegistered<ErrorReporter>(), isTrue);
      expect(serviceLocator.isRegistered<LocaleStore>(), isTrue);
      expect(serviceLocator.isRegistered<LocaleCubit>(), isTrue);
      expect(serviceLocator.isRegistered<PasswordRecoveryGateway>(), isTrue);
      expect(serviceLocator.isRegistered<SignUpGateway>(), isTrue);
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

    test('wires AuthGateway to the credential-free fake', () {
      configureDependencies();

      // Auth must not silently gain a real credential backend; the fake
      // intentionally accepts no credentials. Asserting the concrete type keeps
      // that boundary explicit until a real gateway is an approved slice.
      expect(serviceLocator<AuthGateway>(), isA<FakeAuthGateway>());
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
