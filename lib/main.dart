import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/deep_link/app_link_listener.dart';
import 'app/deep_link/app_link_parser.dart';
import 'app/deep_link/app_links_adapter.dart';
import 'app/deep_link/pending_accept_invite_store.dart';
import 'app/legalhub_theme.dart';
import 'app/localization/locale_cubit.dart';
import 'app/router.dart';
import 'app/service_locator.dart';
import 'data/auth/supabase_auth_api_impl.dart';
import 'data/auth/supabase_env.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Batch 3.3: consume build-time config (`--dart-define-from-file=.env`).
  // When no env file is injected, the DI flip stays on the fake gateway and
  // no provider is initialized — env-less runs and tests keep working.
  final SupabaseEnv supabaseEnv = SupabaseEnv.fromEnvironment();
  if (supabaseEnv.isConfigured) {
    // Anon-key guard: refuse a non-anon key before any provider is wired.
    SupabaseEnv.ensureAnonKey(supabaseEnv.anonKey);
    await initializeSupabase(
      url: supabaseEnv.url,
      anonKey: supabaseEnv.anonKey,
    );
  }
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  configureDependencies(preferences: preferences);
  final LocaleCubit localeCubit = serviceLocator<LocaleCubit>();
  await localeCubit.load();
  final AuthCubit authCubit = serviceLocator<AuthCubit>();
  // Contract-§5: restore any persisted provider session before the first
  // frame so the router starts on the true auth state instead of a
  // misleading default. Harmless with the fake (resolves to signed-out);
  // meaningful once a real provider gateway is configured (Batch 3.3).
  await authCubit.restore();
  final GoRouter router = createAppRouter(authCubit);
  // Phase 4.1 completion (D-P34.2 hook): the app-level deep-link listener
  // bridges OS intents — an accept-invitation share link buffers its
  // one-time token (in-memory only) and opens the accept surface. Recovery
  // /auth-callback URIs are deliberately untouched: supabase_flutter's
  // `detectSessionInUri` observer owns them (docs/p4_1_deeplink_recovery
  // _plan_2026-08-07.md D-P41.2).
  final AppLinkListener appLinkListener = AppLinkListener(
    AppLinksPluginSource(),
    const AppLinkParser(),
    serviceLocator<PendingAcceptInviteStore>(),
    () => router.go(AppRoutes.acceptInvitation),
  );
  runApp(
    LegalHubApp(router: router, authCubit: authCubit, localeCubit: localeCubit),
  );
  // Start after runApp so the router is attached; the plugin holds the
  // cold-start link until requested, so nothing is missed.
  unawaited(appLinkListener.start());
}

class LegalHubApp extends StatelessWidget {
  const LegalHubApp({
    required this.router,
    required this.authCubit,
    required this.localeCubit,
    super.key,
  });

  final RouterConfig<Object> router;
  final AuthCubit authCubit;
  final LocaleCubit localeCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        builder: (BuildContext context, LocaleState state) {
          return MaterialApp.router(
            onGenerateTitle: (BuildContext context) =>
                AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: LegalHubTheme.forBrightness(
              Brightness.light,
              locale: state.locale,
            ),
            darkTheme: LegalHubTheme.forBrightness(
              Brightness.dark,
              locale: state.locale,
            ),
            themeMode: ThemeMode.system,
            locale: state.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
