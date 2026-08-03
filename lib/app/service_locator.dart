import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_gateway.dart';
import '../core/observability/error_reporter.dart';
import '../core/organizations/organization_gateway.dart';
import '../core/sample_service.dart';
import '../data/auth/fake_auth_gateway.dart';
import '../data/auth/supabase_auth_api.dart';
import '../data/auth/supabase_auth_api_impl.dart';
import '../data/auth/supabase_auth_gateway.dart';
import '../data/auth/supabase_env.dart';
import '../data/local/in_memory_locale_store.dart';
import '../data/local/locale_store.dart';
import '../data/local/shared_preferences_locale_store.dart';
import '../data/orgs/fake_organization_gateway.dart';
import '../data/orgs/supabase_org_api.dart';
import '../data/orgs/supabase_org_api_impl.dart';
import '../data/orgs/supabase_organization_gateway.dart';
import '../features/auth/data/fake_password_recovery_gateway.dart';
import '../features/auth/data/fake_sign_up_gateway.dart';
import '../features/auth/data/supabase_password_recovery_gateway.dart';
import '../features/auth/data/supabase_sign_up_gateway.dart';
import '../features/auth/domain/password_recovery_gateway.dart';
import '../features/auth/domain/sign_up_gateway.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/booking/data/fake_booking_gateway.dart';
import '../features/booking/domain/booking_gateway.dart';
import '../features/booking/domain/booking_prefill.dart';
import '../features/discovery/data/fake_attorney_gateway.dart';
import '../features/discovery/domain/attorney_gateway.dart';
import '../features/notifications/data/in_memory_notification_prefs_store.dart';
import '../features/notifications/data/shared_preferences_notification_prefs_store.dart';
import '../features/notifications/domain/notification_prefs_store.dart';
import '../features/orgs/presentation/active_org_store.dart';
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
  SupabaseOrgApi Function()? supabaseOrgApiFactory,
}) {
  // Lazy singleton: stateless service, created on first resolution.
  // Per §4.5, stateless services/repositories register as lazy singletons.
  // App-scoped Cubits below are also lazy singletons because the router and
  // root MaterialApp must observe the same session and locale instances.
  final SupabaseEnv env = supabaseEnv ?? SupabaseEnv.fromEnvironment();
  if (!serviceLocator.isRegistered<SampleService>()) {
    serviceLocator.registerLazySingleton<SampleService>(SampleServiceImpl.new);
  }
  if (!serviceLocator.isRegistered<AuthGateway>()) {
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
  if (!serviceLocator.isRegistered<NotificationPrefsStore>()) {
    serviceLocator.registerLazySingleton<NotificationPrefsStore>(
      () => preferences == null
          ? InMemoryNotificationPrefsStore()
          : SharedPreferencesNotificationPrefsStore(preferences),
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
    // Like AuthGateway/SignUpGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). Code-based recovery needs no deep links (2026-08-03).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<PasswordRecoveryGateway>(
        () => SupabasePasswordRecoveryGateway(
          (supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<PasswordRecoveryGateway>(
        FakePasswordRecoveryGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<SignUpGateway>()) {
    // Stateless service: lazy singleton. The sign-up Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Like AuthGateway, the flip swaps the dev fake for the Supabase-backed
    // implementation when the build is configured (Batch 3.3 env pattern).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<SignUpGateway>(
        () => SupabaseSignUpGateway(
          (supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<SignUpGateway>(
        FakeSignUpGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<OrganizationGateway>()) {
    // Like AuthGateway, the flip swaps the dev fake for the Supabase-backed
    // implementation when the build is configured (Batch 3.3 env pattern).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<OrganizationGateway>(
        () => SupabaseOrganizationGateway(
          (supabaseOrgApiFactory ?? SupabaseOrgApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<OrganizationGateway>(
        FakeOrganizationGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<BookingGateway>()) {
    // Stateless service: lazy singleton. The booking Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    serviceLocator.registerLazySingleton<BookingGateway>(
      FakeBookingGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<BookingPrefill>()) {
    // Transient prefill holder (Phase 6 D-A3): app-scoped, in-memory only;
    // consumed and cleared by BookingScreen at cubit creation. Never
    // serialized; nothing booking-related travels in route params or
    // GoRouter extra (D-B4).
    serviceLocator.registerLazySingleton<BookingPrefill>(BookingPrefill.new);
  }
  if (!serviceLocator.isRegistered<AttorneyGateway>()) {
    // Stateless service: lazy singleton. The discovery Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Fake-domain (D-A2): a real attorney backend is a later approved
    // data-layer slice.
    serviceLocator.registerLazySingleton<AttorneyGateway>(
      FakeAttorneyGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<ActiveOrgStore>()) {
    // Client-side active-org context (Phase 7 D-M7/D-08): app-scoped,
    // in-memory only, never serialized. The org hub seeds/reads it; the
    // server re-derives membership per D-08.
    serviceLocator.registerLazySingleton<ActiveOrgStore>(ActiveOrgStore.new);
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
