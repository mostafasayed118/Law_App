import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/deep_link/app_link_listener.dart';
import 'package:legalhub/app/deep_link/app_link_parser.dart';
import 'package:legalhub/app/deep_link/app_link_source.dart';
import 'package:legalhub/app/deep_link/pending_accept_invite_store.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/matters/presentation/matter_link_chip.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late GoRouter router;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    // The reset step (Phase 4.1 recovery landing) resolves
    // PasswordRecoveryGateway via the service locator when it builds its
    // cubit; configureDependencies() registers the fake (idempotent).
    configureDependencies();
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
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

  group('router recovery deep link (Phase 4.1)', () {
    testWidgets('lands a recovery session on the reset step instead of home', (
      tester,
    ) async {
      // The provider PKCE exchange for a recovery link fires a session
      // with the recovery marker (supabase_flutter observer → gateway
      // stream → cubit), exactly the path a deep link takes.
      gateway.markAsRecoverySession();
      await authCubit.startDemoSession();
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The reset step renders (recovery intent), not home — the deep
      // link must not boot as a normal authenticated session.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.forgotPasswordReset,
      );
      expect(authCubit.state.isAuthenticated, isTrue);
      expect(authCubit.recoveryPending, isTrue);
    });

    testWidgets(
      'keeps an authenticated user on the reset step while recovery is '
      'pending (no bounce to home)',
      (tester) async {
        gateway.markAsRecoverySession();
        await authCubit.startDemoSession();
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Landing on the reset route itself must not trip the
        // authenticated-on-auth-route bounce.
        router.go(AppRoutes.forgotPasswordReset);
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.forgotPasswordReset,
        );
      },
    );

    testWidgets('clears the recovery landing once the session is signed out', (
      tester,
    ) async {
      gateway.markAsRecoverySession();
      await authCubit.startDemoSession();
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The reset flow signs out after updating the password (the
      // provider impl clears the recovery session); the reset screen's
      // success listener then navigates to sign-in.
      await authCubit.signOut();
      await tester.pumpAndSettle();

      expect(authCubit.recoveryPending, isFalse);
      expect(authCubit.state.isAuthenticated, isFalse);
      // Without the recovery marker, the authenticated-on-auth-route
      // bounce is gone: the router no longer forces any destination.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.forgotPasswordReset,
      );
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        isNot(AppRoutes.home),
      );
    });

    testWidgets('a plain (non-recovery) session still routes to home', (
      tester,
    ) async {
      await authCubit.startDemoSession();
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(authCubit.recoveryPending, isFalse);
      expect(find.textContaining('Hello, Demo user'), findsOneWidget);
    });
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

  group('booking route (Phase 5 slice 5.2)', () {
    testWidgets(
      'renders the booking wizard for an authenticated demo session',
      (tester) async {
        // BookingScreen resolves BookingGateway from the locator (the dev
        // fake in env-less runs).
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        router.go(AppRoutes.book);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // The /book route renders the wizard's category step, not home; the
        // shell keeps home highlighted (the /book route is not a settings
        // descendant).
        expect(find.text('Book a Consultation'), findsOneWidget);
        expect(find.text('Consultation type'), findsOneWidget);
        expect(selectedIndex(tester), 0);
      },
    );

    testWidgets('blocks unauthenticated access to the booking route', (
      tester,
    ) async {
      router.go(AppRoutes.book);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('discovery route (Phase 6 slice 6.1)', () {
    testWidgets(
      'renders the search surface for an authenticated demo session',
      (tester) async {
        // AttorneySearchScreen resolves AttorneyGateway from the locator
        // (the dev fake in env-less runs).
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        router.go(AppRoutes.discovery);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // The /discovery route renders the search surface, not home; the
        // shell keeps home highlighted (not a settings descendant).
        expect(find.text('Find an Attorney'), findsOneWidget);
        expect(find.text('Layla Mansour'), findsOneWidget);
        expect(selectedIndex(tester), 0);
      },
    );

    testWidgets('blocks unauthenticated access to the discovery route', (
      tester,
    ) async {
      router.go(AppRoutes.discovery);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('discovery profile route (Phase 6 slice 6.2)', () {
    testWidgets('renders the profile for an authenticated demo session', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go('/discovery/atty-1');
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The profile route renders the synthetic profile (AC-3), not
      // home; the shell keeps home highlighted.
      expect(find.text('Attorney profile'), findsOneWidget);
      expect(find.text('Layla Mansour'), findsOneWidget);
      expect(find.text('Book with this attorney'), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });

    testWidgets(
      'Book with this attorney routes to /book with the prefill (AC-4)',
      (tester) async {
        usePhoneViewport(tester);
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        router.go('/discovery/atty-1');
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Book with this attorney'));
        await tester.pumpAndSettle();

        // The wizard's category step renders the prefill note — proof the
        // draft carries the optional attorneyId (D-A3).
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.book,
        );
        expect(find.text('Booking with Layla Mansour'), findsOneWidget);
      },
    );

    testWidgets('tapping a search result opens its profile (slice 6.2)', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.discovery);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // A search row is a tap target into the profile route (the slice
      // 6.2 affordance); the profile renders for the tapped attorney.
      await tester.tap(find.text('Layla Mansour'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.attorneyProfile('atty-1'),
      );
      expect(find.text('Attorney profile'), findsOneWidget);
      expect(find.text('Book with this attorney'), findsOneWidget);
    });

    testWidgets('blocks unauthenticated access to the profile route', (
      tester,
    ) async {
      router.go('/discovery/atty-1');
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('matter route (Phase 7 slice 7.1)', () {
    testWidgets('renders the matter list for an authenticated demo session', (
      tester,
    ) async {
      // MatterListScreen resolves MatterGateway from the locator (the
      // dev fake in env-less runs).
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.matters);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The /matters route renders the matter list, not home; the
      // shell keeps home highlighted (not a settings descendant).
      expect(find.text('Matters'), findsOneWidget);
      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });

    testWidgets('blocks unauthenticated access to the matter route', (
      tester,
    ) async {
      router.go(AppRoutes.matters);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('vault route (Phase 8 slice 8.1)', () {
    testWidgets('renders the vault list for an authenticated demo session', (
      tester,
    ) async {
      // DocumentListScreen resolves DocumentGateway from the locator (the
      // dev fake in env-less runs).
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.vault);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The /vault route renders the document list, not home; the shell
      // keeps home highlighted.
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Demo engagement letter'), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });

    testWidgets('tapping a resolved row View matter chip opens its matter '
        '(12.0 AC-1)', (tester) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.vault);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The reverse cross-link (Phase 12 D-C1): the first vault row's
      // matterRef resolves to 'Demo acquisition review' (doc-1 → matter-1),
      // so its View matter chip navigates to the existing read-only details
      // route.
      await tester.tap(find.text('View matter').first);
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.matterDetail('matter-1'),
      );
      expect(find.text('Matter details'), findsOneWidget);
    });

    testWidgets(
      'renders no View matter chip when canViewMatters is not granted (12.0 '
      'AC-4)',
      (tester) async {
        // A capability projection without canViewMatters (D-C4): the vault
        // still renders its documents, but every reverse cross-link chip is
        // hidden — navigation hints only, never authorization.
        final GoRouter restrictedRouter = createAppRouter(
          authCubit,
          capabilitiesForRole: <UserRole, RoleCapability>{
            // The demo identity is the org-creating partner (P3.2 Task 8
            // reconciliation), so the restricted map keys the demo role.
            UserRole.partner: const RoleCapability(
              canViewHome: true,
              canViewSettings: true,
              canBookConsultation: true,
              canViewAttorneyDiscovery: true,
              canViewMatters: false,
              canViewDocuments: true,
              canViewMessages: true,
              canViewFiles: true,
              canViewAudit: true,
            ),
          },
        );
        addTearDown(restrictedRouter.dispose);
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        restrictedRouter.go(AppRoutes.vault);
        await tester.pumpWidget(
          harness(
            child: const SizedBox.shrink(),
            routerOverride: restrictedRouter,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Demo engagement letter'), findsOneWidget);
        expect(find.byType(MatterLinkChip), findsNothing);
      },
    );

    testWidgets('blocks unauthenticated access to the vault route', (
      tester,
    ) async {
      router.go(AppRoutes.vault);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('messages route (Phase 9 slice 9.1)', () {
    testWidgets('renders the thread list for an authenticated demo session', (
      tester,
    ) async {
      // MessageListScreen resolves MessageGateway from the locator (the
      // dev fake in env-less runs).
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.messages);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The /messages route renders the thread list, not home; the
      // shell keeps home highlighted (not a settings descendant).
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Demo matter updates'), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });

    testWidgets('blocks unauthenticated access to the messages route', (
      tester,
    ) async {
      router.go(AppRoutes.messages);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });

    testWidgets('tapping a resolved thread-row View matter chip opens its '
        'matter (12.1 AC-2)', (tester) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.messages);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The reverse cross-link (Phase 12 D-C1): the first thread row's
      // matterRef resolves to 'Demo acquisition review' (thread-1 →
      // matter-1), so its View matter chip navigates to the existing
      // read-only details route.
      await tester.tap(find.text('View matter').first);
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.matterDetail('matter-1'),
      );
      expect(find.text('Matter details'), findsOneWidget);
    });

    testWidgets(
      'tapping a thread row opens the read-only thread-detail surface (realtime '
      'T7, D-RT5)',
      (tester) async {
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        router.go(AppRoutes.messages);
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // The thread-open affordance (D-RT5): the whole first row is
        // tappable and opens /messages/thread-1 with the tapped title as
        // the route extra.
        await tester.tap(find.text('Demo matter updates'));
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.messageThreadDetailFor('thread-1'),
        );
        // The detail surface renders the tapped title and the read-only
        // message rows from the fake (thread-1 carries 12 generic rows),
        // plus the insert-only composer (D-LV1).
        expect(find.text('Demo matter updates'), findsOneWidget);
        expect(find.textContaining('generic demo content'), findsWidgets);
        // The single composer field + send affordance; no edit/delete
        // affordance anywhere (the write path stays insert-only).
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsNothing);
        expect(find.byIcon(Icons.edit), findsNothing);
      },
    );

    testWidgets(
      'renders no View matter chip when canViewMatters is not granted (12.1 '
      'AC-4)',
      (tester) async {
        // A capability projection without canViewMatters (D-C4): the
        // messages list still renders its threads, but every reverse
        // cross-link chip is hidden — navigation hints only, never
        // authorization.
        final GoRouter restrictedRouter = createAppRouter(
          authCubit,
          capabilitiesForRole: <UserRole, RoleCapability>{
            // The demo identity is the org-creating partner (P3.2 Task 8
            // reconciliation), so the restricted map keys the demo role.
            UserRole.partner: const RoleCapability(
              canViewHome: true,
              canViewSettings: true,
              canBookConsultation: true,
              canViewAttorneyDiscovery: true,
              canViewMatters: false,
              canViewDocuments: true,
              canViewMessages: true,
              canViewFiles: true,
              canViewAudit: true,
            ),
          },
        );
        addTearDown(restrictedRouter.dispose);
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        restrictedRouter.go(AppRoutes.messages);
        await tester.pumpWidget(
          harness(
            child: const SizedBox.shrink(),
            routerOverride: restrictedRouter,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Demo matter updates'), findsOneWidget);
        expect(find.byType(MatterLinkChip), findsNothing);
      },
    );
  });

  group('search route (Phase 11 slice 11.1)', () {
    testWidgets('renders the search surface seeded from the q param', (
      tester,
    ) async {
      // SearchScreen resolves the four gateways from the locator (the dev
      // fakes in env-less runs).
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.searchQuery('Demo'));
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The /search route renders the grouped results, not home; the shell
      // keeps home highlighted (not a settings descendant).
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(find.text('Demo engagement letter'), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });

    testWidgets('tapping a matter row opens its details (AC-3)', (
      tester,
    ) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.searchQuery('Demo'));
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // A matter result row navigates to the existing read-only details
      // route (D-S3).
      await tester.tap(find.text('Demo acquisition review'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.matterDetail('matter-1'),
      );
      expect(find.text('Matter details'), findsOneWidget);
    });

    testWidgets('tapping a document row opens the vault (AC-3)', (
      tester,
    ) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.searchQuery('engagement'));
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // A document result row navigates to the existing read-only vault
      // route (D-S3) — no document detail route exists.
      await tester.tap(find.text('Demo engagement letter'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.vault,
      );
    });

    testWidgets('tapping a thread row opens the messages route (AC-3)', (
      tester,
    ) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.searchQuery('updates'));
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // A thread result row navigates to the existing read-only messages
      // route (D-S3) — no thread-open affordance exists anywhere.
      await tester.tap(find.text('Demo matter updates'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.messages,
      );
    });

    testWidgets('tapping an attorney row opens its profile (AC-3)', (
      tester,
    ) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.searchQuery('Layla'));
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // An attorney result row navigates to the existing read-only profile
      // route (D-S3).
      await tester.tap(find.text('Layla Mansour'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.attorneyProfile('atty-1'),
      );
      expect(find.text('Attorney profile'), findsOneWidget);
    });

    testWidgets('home search field submit navigates to /search?q=… (AC-5)', (
      tester,
    ) async {
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The inert home field is now wired: submit opens the unified search
      // surface with the query (D-S4).
      await tester.enterText(find.byType(TextField), 'Demo');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.search,
      );
      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['q'],
        'Demo',
      );
      // The search surface seeds and renders the grouped results.
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Demo acquisition review'), findsOneWidget);
    });

    testWidgets('blocks unauthenticated access to the search route', (
      tester,
    ) async {
      router.go(AppRoutes.search);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
  });

  group('matter details route (Phase 7 slice 7.2)', () {
    testWidgets('renders the details for an authenticated demo session', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go('/matters/matter-1');
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The details route renders the read-only projection (AC-3), not
      // home; the shell keeps home highlighted.
      expect(find.text('Matter details'), findsOneWidget);
      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(find.text('Layla Mansour'), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });

    testWidgets('tapping a matter row opens its details (slice 7.2)', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await resetServiceLocator();
      configureDependencies();
      addTearDown(() => resetServiceLocator());

      await authCubit.startDemoSession();
      router.go(AppRoutes.matters);
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // A matter row is a tap target into the details route (the slice
      // 7.2 affordance); the details render for the tapped matter.
      await tester.tap(find.text('Demo acquisition review'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.matterDetail('matter-1'),
      );
      expect(find.text('Matter details'), findsOneWidget);
      expect(find.text('Layla Mansour'), findsOneWidget);
    });

    testWidgets('blocks unauthenticated access to the details route', (
      tester,
    ) async {
      router.go('/matters/matter-1');
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(authCubit.state.isAuthenticated, isFalse);
    });
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

  group('router accept-invitation deep link (Phase 4.1 Task 5)', () {
    // The D-P34.2 hook, wired end-to-end: the AppLinkListener consumes the
    // cold-start accept-invitation share link (stub AppLinkSource stands in
    // for the app_links plugin), buffers its one-time token in the locator's
    // PendingAcceptInviteStore, and drives the real router to the accept
    // surface — whose initState consume-and-clear pre-fills the paste field
    // (never auto-submits). Recovery URIs are untouched by this listener,
    // which is pinned in the listener's own unit tests.
    testWidgets(
      'a cold-start accept link opens the accept screen pre-filled and '
      'consumes the token',
      (tester) async {
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await authCubit.startDemoSession();
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        final AppLinkListener listener = AppLinkListener(
          _StubAppLinkSource(
            initialLink: Uri.parse(
              'com.legalhub.app://accept-invite?token=one-time-token',
            ),
          ),
          const AppLinkParser(),
          serviceLocator<PendingAcceptInviteStore>(),
          () => router.go(AppRoutes.acceptInvitation),
        );
        addTearDown(listener.dispose);
        await listener.start();
        await tester.pumpAndSettle();

        // The listener drove the real router onto the accept surface.
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.acceptInvitation,
        );
        // The paste field is pre-filled with the one-time token (D-P41.3:
        // pre-fill, never auto-submit — no accepted confirmation).
        final TextField field = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(field.controller!.text, 'one-time-token');
        expect(find.text('Invitation accepted.'), findsNothing);
        // Consumed-and-cleared: the token is single-delivery.
        expect(
          serviceLocator<PendingAcceptInviteStore>().hasPendingToken,
          isFalse,
        );
      },
    );

    testWidgets(
      'a cold-start accept link while signed out bounces to sign-in and '
      'keeps the token pending (D-P41.4)',
      (tester) async {
        await resetServiceLocator();
        configureDependencies();
        addTearDown(() => resetServiceLocator());

        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        final AppLinkListener listener = AppLinkListener(
          _StubAppLinkSource(
            initialLink: Uri.parse(
              'com.legalhub.app://accept-invite?token=pending-token',
            ),
          ),
          const AppLinkParser(),
          serviceLocator<PendingAcceptInviteStore>(),
          () => router.go(AppRoutes.acceptInvitation),
        );
        addTearDown(listener.dispose);
        await listener.start();
        await tester.pumpAndSettle();

        // The accept route sits behind the auth gate: the redirect bounces
        // to sign-in, never exposing the paste surface signed out.
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.signIn,
        );
        expect(find.text('Welcome Back'), findsOneWidget);
        // The token is buffered in-memory, not lost (cold-start / signed-out
        // race, D-P41.4).
        expect(
          serviceLocator<PendingAcceptInviteStore>().hasPendingToken,
          isTrue,
        );

        // A later signed-in visit consummates the D-P41.4 promise: the
        // buffered token pre-fills the accept surface and is consumed.
        await authCubit.startDemoSession();
        router.go(AppRoutes.acceptInvitation);
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.acceptInvitation,
        );
        final TextField field = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(field.controller!.text, 'pending-token');
        expect(
          serviceLocator<PendingAcceptInviteStore>().hasPendingToken,
          isFalse,
        );
      },
    );
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
            FakeMembershipRepository(),
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
          FakeMembershipRepository(),
        );
        addTearDown(restrictedCubit.close);
        final GoRouter restrictedRouter = createAppRouter(
          restrictedCubit,
          capabilitiesForRole: <UserRole, RoleCapability>{
            UserRole.client: const RoleCapability(
              canViewHome: true,
              canViewSettings: false,
              canBookConsultation: true,
              canViewAttorneyDiscovery: true,
              canViewMatters: true,
              canViewDocuments: true,
              canViewMessages: true,
              canViewFiles: true,
              canViewAudit: false,
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
          FakeMembershipRepository(),
        );
        addTearDown(restrictedCubit.close);
        final GoRouter restrictedRouter = createAppRouter(
          restrictedCubit,
          capabilitiesForRole: <UserRole, RoleCapability>{
            UserRole.attorney: const RoleCapability(
              canViewHome: false,
              canViewSettings: true,
              canBookConsultation: false,
              canViewAttorneyDiscovery: false,
              canViewMatters: false,
              canViewDocuments: false,
              canViewMessages: false,
              canViewFiles: false,
              canViewAudit: false,
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
        FakeMembershipRepository(),
      );
      addTearDown(emptyCubit.close);
      final GoRouter emptyRouter = createAppRouter(
        emptyCubit,
        capabilitiesForRole: <UserRole, RoleCapability>{
          UserRole.admin: const RoleCapability(
            canViewHome: false,
            canViewSettings: false,
            canBookConsultation: false,
            canViewAttorneyDiscovery: false,
            canViewMatters: false,
            canViewDocuments: false,
            canViewMessages: false,
            canViewFiles: false,
            canViewAudit: false,
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

    testWidgets('drives settings → platform admin through the settings tile', (
      tester,
    ) async {
      // PlatformAdminScreen resolves its cubit from the locator's registered
      // fake gateway (owner demo identity), so the metadata sections render.
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

      // 2. The platform-admin tile (below the fold in the settings ListView)
      //    → the admin screen renders its sections.
      await tester.scrollUntilVisible(
        find.text('Platform admin'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Platform admin'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.platformAdmin,
      );
      expect(find.text('Organizations'), findsOneWidget);
      expect(find.text('Demo Firm'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      // The settings destination stays highlighted on the descendant route.
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });
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
  bool get recoveryPending => false;

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

/// Test-only [AppLinkSource] with a fixed cold-start link, so the Phase 4.1
/// accept-invitation deep-link pin drives the real router + listener without
/// the app_links plugin. No warm-start emission: the listener's unit tests
/// cover the stream path.
class _StubAppLinkSource implements AppLinkSource {
  _StubAppLinkSource({required this.initialLink});

  final Uri? initialLink;

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get onUri => const Stream<Uri>.empty();
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
