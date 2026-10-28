import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/deep_link/app_link_listener.dart';
import 'app/deep_link/app_link_parser.dart';
import 'app/deep_link/app_links_adapter.dart';
import 'app/deep_link/pending_accept_invite_store.dart';
import 'app/flavor.dart';
import 'app/legalhub_theme.dart';
import 'app/localization/locale_cubit.dart';
import 'app/router.dart';
import 'app/service_locator.dart';
import 'app/theme/theme_cubit.dart';
import 'core/observability/crash_boundary.dart';
import 'core/observability/error_reporter.dart';
import 'core/onboarding/onboarding_store.dart';
import 'data/auth/supabase_auth_api_impl.dart';
import 'data/auth/supabase_env.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'l10n/app_localizations.dart';

/// Every entrypoint's error boundary (R2). Module-level so the bootstrap zone
/// and [bootstrap] itself report through the same dedupe window: [main]
/// installs the pre-DI console fallback, [bootstrap] swaps the sink once the
/// service locator owns the reporter.
CrashBoundary? _crashBoundary;

Future<void> main() async {
  // From the first line of the process every uncaught error reaches a sink:
  // the pre-DI fallback is a console reporter (no dependency, no network).
  // `bootstrap` re-points this same boundary at the DI reporter as soon as
  // one exists. A remote sink (Sentry/Firebase) stays owner-gated.
  final CrashBoundary boundary = installGlobalErrorHandlers(
    ConsoleErrorReporter(),
  );
  _crashBoundary = boundary;
  // The binding is initialized inside the guarded zone (in `bootstrap`) so
  // every framework callback inherits the zone.
  await runZonedGuarded<Future<void>>(
    () => bootstrap(AppConfig.fromEnvironment()),
    boundary.reportUncaught,
  );
}

/// Runs a flavor entrypoint inside the same crash boundary [main] uses.
///
/// `main_development` / `main_production` call [bootstrap] directly; without
/// this wrapper they would get the engine hooks but not the guarded zone.
Future<void> runGuardedEntrypoint(Future<void> Function() body) {
  final CrashBoundary boundary = _crashBoundary ??=
      installGlobalErrorHandlers(ConsoleErrorReporter());
  return runZonedGuarded<Future<void>>(body, boundary.reportUncaught) ??
      Future<void>.value();
}

/// Shared bootstrap for every flavor entrypoint
/// (`lib/main_development.dart`, `lib/main_production.dart`, and this
/// default entry).
///
/// Batch 3.3: build-time config comes from the [config] (itself fed by
/// `--dart-define-from-file`). When no env file is injected, the DI flip
/// stays on the fake gateway and no provider is initialized — env-less runs
/// and tests keep working.
Future<void> bootstrap(AppConfig config) async {
  // Flavor entrypoints (`main_development` / `main_production`) call bootstrap
  // directly instead of `main`, so install the pre-DI console fallback here
  // too — before any config guard can throw. A no-op when `main` already did.
  _crashBoundary ??= installGlobalErrorHandlers(ConsoleErrorReporter());
  WidgetsFlutterBinding.ensureInitialized();
  final SupabaseEnv supabaseEnv = config.toSupabaseEnv();
  if (config.isConfigured) {
    // Anon-key guard: refuse a non-anon key before any provider is wired.
    SupabaseEnv.ensureAnonKey(supabaseEnv.anonKey);
    // HTTPS guard (audit A02): refuse a cleartext Supabase URL before any
    // credential crosses the network.
    SupabaseEnv.ensureHttpsUrl(supabaseEnv.url);
    await initializeSupabase(
      url: supabaseEnv.url,
      anonKey: supabaseEnv.anonKey,
    );
  } else if (config.flavor == AppFlavor.production && kReleaseMode) {
    // Audit A07: a production release build must never silently run on the
    // credential-free fakes — a missing `.env` at build time is a hard
    // configuration error, not a demo session. Debug runs and tests still
    // fall through to the fakes below.
    throw StateError(
      'Production release build is missing SUPABASE_URL/SUPABASE_ANON_KEY. '
      'Rebuild with --dart-define-from-file pointing at the production env.',
    );
  }
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  configureDependencies(preferences: preferences);
  // R2: once the service locator owns the reporter, uncaught engine/zone
  // errors go through it (still ConsoleErrorReporter today — a remote sink
  // stays owner-gated). `main` may already have installed the pre-DI console
  // boundary; reusing it keeps the dedupe window across the sink swap.
  final ErrorReporter errorReporter = serviceLocator<ErrorReporter>();
  final CrashBoundary crashBoundary = _crashBoundary ??=
      installGlobalErrorHandlers(errorReporter);
  crashBoundary.useReporter(errorReporter);
  final LocaleCubit localeCubit = serviceLocator<LocaleCubit>();
  final ThemeCubit themeCubit = serviceLocator<ThemeCubit>();
  final AuthCubit authCubit = serviceLocator<AuthCubit>();
  // Parallelize independent restores to shorten time-to-first-frame.
  // Contract-§5 still holds: all complete before the router is created.
  await Future.wait(<Future<void>>[
    localeCubit.load(),
    // Restore the persisted theme mode before the first frame so the app
    // starts on the user's choice (light/dark/system) instead of the default.
    themeCubit.load(),
    // Local session restore only. Membership hydration is a network read
    // and must not hold the first frame (audit 2026-10-27, F2).
    authCubit.restore(hydrateMemberships: false),
  ]);
  final bool onboardingCompleted = await serviceLocator<OnboardingStore>()
      .hasCompleted();
  final GoRouter router = createAppRouter(
    authCubit,
    pendingAcceptInvites: serviceLocator<PendingAcceptInviteStore>(),
    initialLocation: onboardingCompleted
        ? AppRoutes.signIn
        : AppRoutes.onboarding,
  );
  // Phase 4.1 completion (D-P34.2 hook): the app-level deep-link listener
  // bridges OS intents — an accept-invitation share link buffers its
  // one-time token (in-memory only) and opens the accept surface. Recovery
  // /auth-callback URIs are deliberately untouched: `detectSessionInUri` is
  // disabled in `initializeSupabase`, and the explicit `AuthCallbackObserver`
  // (started by `SupabaseAuthApiImpl.bind`) owns them with the narrow
  // query-only PKCE callback rule (docs/p4_1_deeplink_recovery_plan_2026-08-07
  // .md D-P41.2).
  final AppLinkListener appLinkListener = AppLinkListener(
    AppLinksPluginSource(),
    const AppLinkParser(),
    serviceLocator<PendingAcceptInviteStore>(),
    () => router.go(AppRoutes.acceptInvitation),
  );
  runApp(
    LegalHubApp(
      router: router,
      authCubit: authCubit,
      localeCubit: localeCubit,
      themeCubit: themeCubit,
      // The debug banner marks dev-flavor builds on-device so a dev install
      // is never mistaken for production. Production stays banner-free.
      debugBanner: config.flavor == AppFlavor.development,
    ),
  );
  // The router is attached now; fill the RLS-scoped memberships in the
  // background. hydrate() no-ops when the session is absent/expired, so an
  // env-less or signed-out boot pays nothing.
  unawaited(authCubit.hydrate());
  // Start after runApp so the router is attached; the plugin holds the
  // cold-start link until requested, so nothing is missed.
  unawaited(appLinkListener.start());
}

class LegalHubApp extends StatelessWidget {
  const LegalHubApp({
    required this.router,
    required this.authCubit,
    required this.localeCubit,
    required this.themeCubit,
    this.debugBanner = false,
    super.key,
  });

  final RouterConfig<Object> router;
  final AuthCubit authCubit;
  final LocaleCubit localeCubit;
  final ThemeCubit themeCubit;

  /// Shows the Flutter debug banner. Enabled by bootstrap for the
  /// development flavor; defaults to off so existing callers (and tests)
  /// keep the production look.
  final bool debugBanner;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
        BlocProvider<ThemeCubit>.value(value: themeCubit),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        builder: (BuildContext context, LocaleState state) {
          // The theme mode follows the user's persisted choice; system
          // resolves through the platform brightness by ThemeMode.system.
          return BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (BuildContext context, ThemeMode themeMode) {
              return MaterialApp.router(
                onGenerateTitle: (BuildContext context) =>
                    AppLocalizations.of(context).appTitle,
                debugShowCheckedModeBanner: debugBanner,
                theme: LegalHubTheme.forBrightness(
                  Brightness.light,
                  locale: state.locale,
                ),
                darkTheme: LegalHubTheme.forBrightness(
                  Brightness.dark,
                  locale: state.locale,
                ),
                themeMode: themeMode,
                locale: state.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              );
            },
          );
        },
      ),
    );
  }
}
