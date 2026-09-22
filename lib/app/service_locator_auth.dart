part of 'service_locator.dart';

/// The credential seams that flip between the dev fakes and the
/// Supabase-backed implementations on the configured path (Batch 3.3).
void _registerAuthSeams(
  SupabaseEnv env, {
  SupabaseAuthApi Function()? supabaseAuthApiFactory,
}) {
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
}
