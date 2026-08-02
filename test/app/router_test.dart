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
  /// wires app-wide.
  Widget harness({required Widget child}) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: MaterialApp.router(
        routerConfig: router,
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

  group('shell NavigationBar selected index', () {
    int selectedIndex(WidgetTester tester) =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

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
  });
}
