import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late GoRouter router;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await gateway.dispose();
  });

  /// A localized harness matching the one used by [LegalHubApp] so route
  /// builders resolve [AppLocalizations.of] and a real theme, and route
  /// builders find the [AuthCubit] and [LocaleCubit] providers the app
  /// wires app-wide. Optional overrides let capability-variant tests inject
  /// their own cubit + router.
  Widget harness({
    required Widget child,
    AuthCubit? cubitOverride,
    GoRouter? routerOverride,
  }) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: cubitOverride ?? authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: MaterialApp.router(
        routerConfig: routerOverride ?? router,
        theme: ThemeData.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  /// Sizes the test surface to a representative phone viewport.
  ///
  /// `OnboardingScreen` lays out fixed-height content inside a `PageView`; at
  /// the default 800x600 widget-test surface it overflows (tracked deviation
  /// D-T1). The phone viewport is its realistic rendering context and keeps
  /// the bypass assertions about navigation, not layout.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(411, 867);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  group('router redirect logic', () {
    testWidgets('keeps an unauthenticated user on the sign-in route', (
      tester,
    ) async {
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The sign-in screen renders the localized welcome copy, proving we
      // landed on the /sign-in route rather than a protected route.
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets(
      'redirects an authenticated user away from auth routes to home',
      (tester) async {
        await authCubit.startDemoSession();
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Authenticated redirect lands on /home; the demo greeting appears.
        expect(find.textContaining('Hello, Demo user'), findsOneWidget);
        expect(authCubit.state.isAuthenticated, isTrue);
      },
    );

    testWidgets(
      'blocks unauthenticated access to protected routes by sending to sign-in',
      (tester) async {
        // Start already at a protected route; the redirect fires to /sign-in.
        router.go('/home');
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(authCubit.state.status, AuthStatus.unauthenticated);
      },
    );
  });

  group('router onboarding bypass (1.5 pin)', () {
    testWidgets('allows an unauthenticated user onto the onboarding route', (
      tester,
    ) async {
      usePhoneViewport(tester);
      router.go(AppRoutes.onboarding);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The redirect whitelists onboarding routes for unauthenticated
      // users; the first carousel page proves we landed on /onboarding
      // rather than being bounced to /sign-in.
      expect(find.text('Expert Legal Advice'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });

    testWidgets(
      'allows an unauthenticated user onto the onboarding-success route',
      (tester) async {
        router.go(AppRoutes.onboardingSuccess);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Same whitelist; the success screen renders for an unauthenticated
        // user so the carousel flow can end at sign-in.
        expect(find.text("You're All Set"), findsOneWidget);
        expect(authCubit.state.isAuthenticated, isFalse);
      },
    );

    testWidgets('still blocks unauthenticated access to the settings route', (
      tester,
    ) async {
      router.go(AppRoutes.settings);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The shell routes stay behind the auth gate even though the
      // onboarding routes are whitelisted — the bypass is scoped.
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });

    testWidgets(
      'still blocks unauthenticated access to the notifications route',
      (tester) async {
        router.go(AppRoutes.notifications);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Same scoped bypass: the notifications route stays behind the auth
        // gate like every other shell route.
        expect(find.text('Welcome Back'), findsOneWidget);
        expect(authCubit.state.isAuthenticated, isFalse);
      },
    );
  });

  group('organization route (1.5 pin)', () {
    testWidgets('renders the roster for an authenticated demo session', (
      tester,
    ) async {
      // OrganizationHubScreen resolves the OrganizationGateway from the
      // locator (the dev fake in env-less runs).
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.organizations);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The demo session's active membership (org-demo) routes the hub
      // straight to the roster; the settings destination stays highlighted.
      expect(find.text('Demo Firm'), findsOneWidget);
      expect(find.text('Demo user'), findsOneWidget);
      expect(selectedIndex(tester), 1);
    });

    testWidgets('blocks unauthenticated access to the organization route', (
      tester,
    ) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      router.go(AppRoutes.organizations);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });

    testWidgets('renders the accept-invitation screen when authenticated', (
      tester,
    ) async {
      await authCubit.startDemoSession();
      router.go(AppRoutes.acceptInvitation);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Accept invitation'), findsWidgets);
      expect(find.text('One-time token'), findsOneWidget);
      expect(selectedIndex(tester), 1);
    });

    testWidgets('blocks unauthenticated access to the accept route', (
      tester,
    ) async {
      router.go(AppRoutes.acceptInvitation);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('shell NavigationBar selected index', () {
    testWidgets('highlights home on /home', (tester) async {
      await authCubit.startDemoSession();
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), 0);
    });

    testWidgets('highlights settings on /settings', (tester) async {
      await authCubit.startDemoSession();
      router.go(AppRoutes.settings);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), 1);
    });

    testWidgets(
      'keeps settings highlighted on /profile instead of falling back to home',
      (tester) async {
        await authCubit.startDemoSession();
        router.go(AppRoutes.profile);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // The profile screen rendered AND the settings destination stays
        // selected — the fix under test.
        expect(find.text('Profile'), findsOneWidget);
        expect(selectedIndex(tester), 1);
      },
    );

    testWidgets(
      'keeps settings highlighted on /notifications instead of falling back '
      'to home',
      (tester) async {
        // NotificationSettingsScreen resolves its store from the locator.
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        router.go(AppRoutes.notifications);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsWidgets);
        expect(selectedIndex(tester), 1);
      },
    );

    // The real capability map grants every role both destinations today, so
    // the per-role matrix pins the *current* contract. The variant tests
    // below inject a restricted map (via the capabilitiesForRole seam) to
    // pin the shell for combinations that do not exist yet — a role without
    // canViewSettings renders only Home, and the index/tap target stay in
    // range for every capability combination.
    testWidgets(
      'renders both destinations and highlights correctly for every role '
      '(real capability map)',
      (tester) async {
        // The loop only visits /home, /settings, /profile — none of which
        // resolve from the service locator, so no configureDependencies is
        // needed here.
        for (final UserRole role in UserRole.values) {
          final AuthCubit roleCubit = AuthCubit(
            RoleGateway(sessionForRole(role)),
            InMemoryErrorReporter(),
          );
          addTearDown(roleCubit.close);
          final GoRouter roleRouter = createAppRouter(roleCubit);
          addTearDown(roleRouter.dispose);

          await tester.pumpWidget(
            harness(
              child: const SizedBox.shrink(),
              cubitOverride: roleCubit,
              routerOverride: roleRouter,
            ),
          );
          await tester.pumpAndSettle();

          // Both destinations render for every role in the real map.
          expect(
            find.byType(NavigationDestination),
            findsNWidgets(2),
            reason: 'role $role renders both destinations',
          );
          // Lands on /home via the authenticated redirect.
          expect(selectedIndex(tester), 0, reason: 'role $role on /home');

          roleRouter.go(AppRoutes.settings);
          await tester.pumpAndSettle();
          expect(selectedIndex(tester), 1, reason: 'role $role on /settings');

          roleRouter.go(AppRoutes.profile);
          await tester.pumpAndSettle();
          expect(selectedIndex(tester), 1, reason: 'role $role on /profile');
        }
      },
    );

    // Material 3's NavigationBar requires >= 2 destinations, so a role with
    // fewer visible destinations gets no bottom bar at all (graceful
    // degradation, never a framework assertion). These variants pin that the
    // shell stays crash-free and the body still renders for capability
    // combinations that do not exist in the real map yet.
    testWidgets(
      'renders no NavigationBar when only Home is visible (canViewSettings '
      'false)',
      (tester) async {
        final AuthCubit restrictedCubit = AuthCubit(
          RoleGateway(sessionForRole(UserRole.client)),
          InMemoryErrorReporter(),
        );
        addTearDown(restrictedCubit.close);
        final GoRouter restrictedRouter = createAppRouter(
          restrictedCubit,
          capabilitiesForRole: <UserRole, RoleCapability>{
            UserRole.client: const RoleCapability(
              canViewHome: true,
              canViewSettings: false,
            ),
          },
        );
        addTearDown(restrictedRouter.dispose);

        await tester.pumpWidget(
          harness(
            child: const SizedBox.shrink(),
            cubitOverride: restrictedCubit,
            routerOverride: restrictedRouter,
          ),
        );
        await tester.pumpAndSettle();

        // Single visible destination → no bottom bar, no framework assert.
        expect(find.byType(NavigationBar), findsNothing);
        // The shell body still renders the redirected route (/home).
        expect(find.textContaining('Hello, User client'), findsOneWidget);

        // A settings-descendant route stays reachable by URL without crash.
        restrictedRouter.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsWidgets);
      },
    );

    testWidgets(
      'renders no NavigationBar when only Settings is visible (canViewHome '
      'false)',
      (tester) async {
        final AuthCubit restrictedCubit = AuthCubit(
          RoleGateway(sessionForRole(UserRole.attorney)),
          InMemoryErrorReporter(),
        );
        addTearDown(restrictedCubit.close);
        final GoRouter restrictedRouter = createAppRouter(
          restrictedCubit,
          capabilitiesForRole: <UserRole, RoleCapability>{
            UserRole.attorney: const RoleCapability(
              canViewHome: false,
              canViewSettings: true,
            ),
          },
        );
        addTearDown(restrictedRouter.dispose);

        await tester.pumpWidget(
          harness(
            child: const SizedBox.shrink(),
            cubitOverride: restrictedCubit,
            routerOverride: restrictedRouter,
          ),
        );
        await tester.pumpAndSettle();

        // Single visible destination → no bottom bar, no framework assert.
        expect(find.byType(NavigationBar), findsNothing);
        // The authenticated redirect still lands on /home and the body
        // renders even though the destination list is settings-only.
        expect(find.textContaining('Hello, User attorney'), findsOneWidget);

        restrictedRouter.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsWidgets);
      },
    );

    testWidgets('tapping a destination navigates to its route', (tester) async {
      await authCubit.startDemoSession();
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // On /home the settings destination is unselected (outlined icon);
      // tapping it must navigate via its route, not a hardcoded index.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.settings,
      );

      // Back on /settings, the home destination is unselected; tapping it
      // returns to /home.
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
    });

    testWidgets('renders no NavigationBar when no destination is visible', (
      tester,
    ) async {
      final AuthCubit emptyCubit = AuthCubit(
        RoleGateway(sessionForRole(UserRole.admin)),
        InMemoryErrorReporter(),
      );
      addTearDown(emptyCubit.close);
      final GoRouter emptyRouter = createAppRouter(
        emptyCubit,
        capabilitiesForRole: <UserRole, RoleCapability>{
          UserRole.admin: const RoleCapability(
            canViewHome: false,
            canViewSettings: false,
          ),
        },
      );
      addTearDown(emptyRouter.dispose);

      await tester.pumpWidget(
        harness(
          child: const SizedBox.shrink(),
          cubitOverride: emptyCubit,
          routerOverride: emptyRouter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      // The body still renders the redirected route with no bar at all.
      expect(find.textContaining('Hello, User admin'), findsOneWidget);
    });
  });

  group('shell navigation end-to-end flow', () {
    testWidgets(
      'drives settings → notifications → profile → settings through the '
      'shell nav',
      (tester) async {
        // NotificationSettingsScreen resolves its store from the locator.
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // 1. Authenticated redirect lands on /home; open /settings via the
        //    bottom NavigationBar (the shell's tap target, not router.go).
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.settings,
        );
        expect(find.text('Language'), findsWidgets);

        // 2. Notifications tile → the notification-settings screen.
        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.notifications,
        );
        expect(find.byType(SwitchListTile), findsNWidgets(3));
        // The settings destination stays highlighted on the descendant route
        // (the 768127b/32803ae behavior).
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );

        // 3. context.go replaces (no back stack), so the shell nav bar is the
        //    realistic way back: tap the highlighted settings destination.
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.settings,
        );

        // 4. Profile tile → the profile screen.
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.profile,
        );
        expect(find.text('Demo user'), findsOneWidget);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );

        // 5. Back to /settings via the shell nav bar.
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.settings,
        );
        expect(find.text('Language'), findsWidgets);
      },
    );
  });
}

/// Test-only gateway emitting a fixed [Session] for a chosen role, so shell
/// capability rendering can be pinned per role without touching the shared
/// demo client session.
class RoleGateway implements AuthGateway {
  RoleGateway(this._session);

  final Session _session;

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async {
    return AuthOutcome<Session>.success(_session);
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    return AuthOutcome<Session>.success(_session);
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    return AuthOutcome<Session>.success(_session);
  }

  @override
  Future<void> signOut() async {}
}

/// Builds a session whose active membership carries [role], so the shell's
/// UX-only capability projection reads that role.
Session sessionForRole(UserRole role) => Session(
  userId: 'user-$role',
  displayName: 'User ${role.name}',
  memberships: <OrganizationMembership>[
    OrganizationMembership(
      organizationId: 'org-demo',
      organizationName: 'Demo Firm',
      role: role,
      status: MembershipStatus.active,
    ),
  ],
  expiresAt: DateTime.now().add(const Duration(hours: 8)),
);
