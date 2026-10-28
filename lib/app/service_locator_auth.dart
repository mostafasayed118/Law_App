part of 'service_locator.dart';

/// The auth redirect for [config]'s build: the same custom scheme the native
/// shell registers, used by BOTH the OAuth hand-off and the emailed recovery
/// link. A development build must never hand the production scheme to a
/// browser no installed app can answer (audit 2026-10-27, F14).
String authRedirectUriFor(AppConfig config) =>
    AuthCallbackUri.callbackUriFor(config.deepLinkScheme);

/// The credential seams that flip between the dev fakes and the
/// Supabase-backed implementations on the configured path (Batch 3.3).
void _registerAuthSeams(
  SupabaseEnv env, {
  SupabaseAuthApi Function()? supabaseAuthApiFactory,
}) {
  // One redirect source for the whole auth seam.
  final String redirectUri = authRedirectUriFor(AppConfig.fromEnvironment());

  // ONE provider seam instance app-wide (audit 2026-10-27, F15): the auth,
  // recovery, and sign-up gateways all resolve this singleton, so the app
  // holds exactly one auth-state subscription. It is registered on its own —
  // not owned by [AuthGateway] — so the locator's teardown closes it even
  // when only a feature-scoped gateway was ever resolved.
  SupabaseAuthApi sharedAuthApi() {
    if (!serviceLocator.isRegistered<SupabaseAuthApi>()) {
      serviceLocator.registerLazySingleton<SupabaseAuthApi>(
        supabaseAuthApiFactory ??
            () => SupabaseAuthApiImpl.bind(recoveryDeepLinkUri: redirectUri),
        // SupabaseAuthApiImpl.dispose is idempotent: AuthGateway.dispose also
        // releases the same instance, and both paths are torn down on reset.
        dispose: (SupabaseAuthApi api) => api.dispose(),
      );
    }
    return serviceLocator<SupabaseAuthApi>();
  }

  if (!serviceLocator.isRegistered<AuthGateway>()) {
    if (env.isConfigured) {
      // Batch 3.3 anon-key guard: refuse a non-anon key before wiring any
      // provider, so a service-role key can never reach the client build.
      SupabaseEnv.ensureAnonKey(env.anonKey);
      // Audit A02: refuse a cleartext URL on the same path (defense in
      // depth alongside the bootstrap guard — tests inject env directly).
      SupabaseEnv.ensureHttpsUrl(env.url);
      serviceLocator.registerLazySingleton<AuthGateway>(
        () => SupabaseAuthGateway(
          sharedAuthApi(),
          // The OAuth redirect must carry THIS build's scheme: a dev build
          // only registers `com.legalhub.app.dev`.
          oauthRedirectUri: redirectUri,
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
        () => SupabasePasswordRecoveryGateway(sharedAuthApi()),
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
        () => SupabaseSignUpGateway(sharedAuthApi()),
      );
    } else {
      serviceLocator.registerLazySingleton<SignUpGateway>(
        FakeSignUpGateway.new,
      );
    }
  }
}
