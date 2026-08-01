import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_gateway.dart';
import '../core/observability/error_reporter.dart';
import '../core/sample_service.dart';
import '../data/auth/fake_auth_gateway.dart';
import '../data/auth/supabase_auth_api.dart';
import '../data/auth/supabase_auth_api_impl.dart';
import '../data/auth/supabase_auth_gateway.dart';
import '../data/auth/supabase_env.dart';
import '../data/local/in_memory_locale_store.dart';
import '../data/local/locale_store.dart';
import '../data/local/shared_preferences_locale_store.dart';
import '../features/auth/data/fake_password_recovery_gateway.dart';
import '../features/auth/data/fake_sign_up_gateway.dart';
import '../features/auth/domain/password_recovery_gateway.dart';
import '../features/auth/domain/sign_up_gateway.dart';
import '../features/auth/presentation/auth_cubit.dart';
import 'localization/locale_cubit.dart';

/// The application's single GetIt service-locator instance.
///
/// Bootstrap spec §4.5 authorizes GetIt as the dependency-injection mechanism.
/// The bootstrap registrations contain only local seams: fake auth, locale
/// persistence, and error reporting. No network, real credentials, or legal
/// data services are registered.
final GetIt serviceLocator = GetIt.instance;

/// Registers all application dependencies.
///
/// Must be called once during application bootstrap (see `main.dart`) before
/// any dependency is resolved. Safe to call again only in tests after
/// [resetServiceLocator] has cleared prior registrations.
///
/// [supabaseEnv] and [supabaseAuthApiFactory] are test seams: when the build
/// injects a configured URL + anon key (Batch 3.3, `--dart-define-from-file`),
/// the real [SupabaseAuthGateway] is registered; otherwise the credential-free
/// [FakeAuthGateway] stays, so tests and env-less local runs keep working.
void configureDependencies({
  SharedPreferences? preferences,
  SupabaseEnv? supabaseEnv,
  SupabaseAuthApi Function()? supabaseAuthApiFactory,
}) {
  // Lazy singleton: stateless service, created on first resolution.
  // Per §4.5, stateless services/repositories register as lazy singletons.
  // App-scoped Cubits below are also lazy singletons because the router and
  // root MaterialApp must observe the same session and locale instances.
  if (!serviceLocator.isRegistered<SampleService>()) {
    serviceLocator.registerLazySingleton<SampleService>(SampleServiceImpl.new);
  }
  if (!serviceLocator.isRegistered<AuthGateway>()) {
    final SupabaseEnv env = supabaseEnv ?? SupabaseEnv.fromEnvironment();
    if (env.isConfigured) {
      // Batch 3.3 anon-key guard: refuse a non-anon key before wiring any
      // provider, so a service-role key can never reach the client build.
      SupabaseEnv.ensureAnonKey(env.anonKey);
      serviceLocator.registerLazySingleton<AuthGateway>(
        () => SupabaseAuthGateway(
          (supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)(),
        ),
        dispose: (AuthGateway gateway) =>
            (gateway as SupabaseAuthGateway).dispose(),
      );
    } else {
      serviceLocator.registerLazySingleton<AuthGateway>(
        FakeAuthGateway.new,
        dispose: (AuthGateway gateway) =>
            (gateway as FakeAuthGateway).dispose(),
      );
    }
  }
  if (!serviceLocator.isRegistered<ErrorReporter>()) {
    serviceLocator.registerLazySingleton<ErrorReporter>(
      ConsoleErrorReporter.new,
    );
  }
  if (!serviceLocator.isRegistered<LocaleStore>()) {
    serviceLocator.registerLazySingleton<LocaleStore>(
      () => preferences == null
          ? InMemoryLocaleStore()
          : SharedPreferencesLocaleStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<LocaleCubit>()) {
    // App-scoped because MaterialApp and routing share the selected locale.
    serviceLocator.registerLazySingleton<LocaleCubit>(
      () => LocaleCubit(serviceLocator<LocaleStore>()),
      dispose: (LocaleCubit cubit) => cubit.close(),
    );
  }
  if (!serviceLocator.isRegistered<PasswordRecoveryGateway>()) {
    // Stateless service: lazy singleton. The recovery Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    serviceLocator.registerLazySingleton<PasswordRecoveryGateway>(
      FakePasswordRecoveryGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<SignUpGateway>()) {
    // Stateless service: lazy singleton. The sign-up Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    serviceLocator.registerLazySingleton<SignUpGateway>(FakeSignUpGateway.new);
  }
  if (!serviceLocator.isRegistered<AuthCubit>()) {
    // App-scoped because the router and all screens observe one session seam.
    serviceLocator.registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        serviceLocator<AuthGateway>(),
        serviceLocator<ErrorReporter>(),
      ),
      dispose: (AuthCubit cubit) => cubit.close(),
    );
  }
}

/// Clears all registrations. Intended for tests that need a clean locator.
Future<void> resetServiceLocator() async {
  await serviceLocator.reset();
}
