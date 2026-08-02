import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/home/presentation/settings_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// SettingsScreen reads LocaleCubit and AuthCubit via context.watch and
// dispatches to them via context.read. It has no direct repository/gateway
// access. These tests pin that wiring: locale dropdown → LocaleCubit.setLocale,
// role display reads the AuthCubit session, and sign-out invokes
// AuthCubit.signOut().
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;

  setUp(() async {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    await localeCubit.load();
  });

  tearDown(() async {
    await authCubit.close();
    await localeCubit.close();
    await gateway.dispose();
  });

  Widget pumpScreen() {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('renders the settings title and the language dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsWidgets);
    // The dropdown's current value (EN) is shown as the selected item.
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets(
    'shows the demo-session notice and the client role when authenticated',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      // Start a demo session so the role display reads a non-null session.
      // FakeAuthGateway.startDemoSession() emits a client-role session.
      await authCubit.startDemoSession();
      await tester.pumpAndSettle();

      expect(authCubit.state.isAuthenticated, isTrue);
      // The demo-session notice is the subtitle of the role ListTile.
      expect(find.text('Development-only demo session'), findsOneWidget);
      // The client role label is rendered from _roleLabel.
      expect(find.text('Client'), findsOneWidget);
    },
  );

  testWidgets(
    'sign-out button invokes AuthCubit.signOut and clears the session',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      // Authenticate first so the sign-out button has a session to clear.
      await authCubit.startDemoSession();
      await tester.pumpAndSettle();
      expect(authCubit.state.isAuthenticated, isTrue);

      // Tap the "End demo session" outlined button.
      await tester.tap(find.text('End demo session'));
      await tester.pumpAndSettle();

      expect(authCubit.state.isAuthenticated, isFalse);
      expect(authCubit.state.status, AuthStatus.unauthenticated);
    },
  );

  testWidgets('selecting a locale from the dropdown updates LocaleCubit', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    // Open the dropdown and select AR.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AR').last);
    await tester.pumpAndSettle();

    expect(localeCubit.state.locale, const Locale('ar'));
  });

  testWidgets(
    'notifications tile navigates to the notification-settings screen',
    (tester) async {
      // NotificationSettingsScreen resolves its NotificationPrefsStore from
      // the service locator, so configure it (in-memory) for this test.
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      // The tile dispatches through the real router (context.go), so the
      // harness must be the actual GoRouter — a bare MaterialApp would
      // throw. Authenticate first so the redirect admits the shell routes.
      await authCubit.startDemoSession();

      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<LocaleCubit>.value(value: localeCubit),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Authenticated redirect lands on /home; open the settings surface.
      // (The bottom NavigationBar also labels its destination "Settings",
      // so assert on the language dropdown, unique to the settings body.)
      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsWidgets);

      // Tap the notifications tile — the wiring under test.
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // The notification-settings screen is reachable: title + three toggles.
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Appointment reminders'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNWidgets(3));
    },
  );

  testWidgets('profile tile navigates to the profile screen', (tester) async {
    // ProfileScreen is a pure projection of AuthCubit state (no store or
    // gateway resolved from the locator), so no service-locator setup is
    // needed here — unlike the notifications screen. Authenticate so the
    // redirect admits the shell routes and identity renders.
    await authCubit.startDemoSession();

    final GoRouter router = createAppRouter(authCubit);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<LocaleCubit>.value(value: localeCubit),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Authenticated redirect lands on /home; open the settings surface.
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsWidgets);

    // Tap the profile tile — the wiring under test.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // The profile screen is reachable: title + rendered session identity.
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Demo user'), findsOneWidget);
  });
}
