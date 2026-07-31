import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/onboarding/presentation/onboarding_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
  });

  /// Sizes the test surface to a representative phone viewport.
  ///
  /// `OnboardingScreen` lays out fixed-height content inside a `PageView`; at the
  /// default 800x600 widget-test surface the page area is too short and the
  /// fixed 240px hero container overflows. A phone-class viewport is the
  /// realistic rendering context for a mobile onboarding carousel and is what
  /// these navigation/brand assertions are meant to verify. The responsive
  /// overflow that occurs at the default desktop surface is tracked as a
  /// separate finding (see the audit note below) and is not papered over here.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(411, 867);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Pumps OnboardingScreen directly (no router) for isolated carousel-state
  // interactions, since the screen needs no providers.
  Widget pumpIsolated() {
    return const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OnboardingScreen(),
    );
  }

  group('onboarding carousel', () {
    testWidgets('renders the first page and the LegalHub brand', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(pumpIsolated());
      await tester.pumpAndSettle();

      // First page title and the Continue button (not "Get Started" yet).
      expect(find.text('Expert Legal Advice'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      // D-01 remediation: no stale "Lexis" wordmark on the onboarding surface.
      expect(find.textContaining('Lexis'), findsNothing);
    });

    testWidgets('renders without overflow at the default 800x600 surface', (
      tester,
    ) async {
      // Default widget-test surface is 800x600 — the D-T1 compact/desktop
      // height that previously overflowed the fixed-height page content by
      // ~139px. The scrollable page (LayoutBuilder + SingleChildScrollView)
      // must absorb it without a RenderFlex overflow exception.
      await tester.pumpWidget(pumpIsolated());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Expert Legal Advice'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('SKIP'), findsOneWidget);
    });

    testWidgets('advances through the carousel via the Continue button', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(pumpIsolated());
      await tester.pumpAndSettle();

      // Page 1 -> 2. Invoke the ElevatedButton.icon onPressed directly to
      // avoid hit-test fragility in the page indicator row.
      _tapContinue(tester);
      await tester.pumpAndSettle();
      expect(find.text('Case Tracking'), findsOneWidget);

      // Page 2 -> 3. The label flips to "Get Started" on the last page.
      _tapContinue(tester);
      await tester.pumpAndSettle();
      expect(find.text('Secure Communication'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Skip routes to the sign-in screen', (tester) async {
      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);
      usePhoneViewport(tester);
      // The router's default initial location is /sign-in; jump to onboarding
      // so the Skip action's context.go(signIn) is observable as a navigate.
      router.go(AppRoutes.onboarding);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The SKIP action lives on a TextButton whose label is the 'SKIP' text.
      // find.text('SKIP') resolves to the Text, so find its TextButton ancestor
      // instead of casting the Text to a TextButton.
      final Finder skipLabel = find.text('SKIP');
      expect(skipLabel, findsOneWidget);
      final TextButton skip = tester.widget<TextButton>(
        find.ancestor(of: skipLabel, matching: find.byType(TextButton)),
      );
      expect(skip.onPressed, isNotNull);
      skip.onPressed!();
      await tester.pumpAndSettle();

      // Landed on /sign-in, whose welcome copy is the destination proof.
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('Get Started routes to the onboarding-success screen', (
      tester,
    ) async {
      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);
      usePhoneViewport(tester);
      router.go(AppRoutes.onboarding);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      // Advance to the last page so the Continue button becomes Get Started.
      _tapContinue(tester);
      await tester.pumpAndSettle();
      _tapContinue(tester);
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);

      _tapContinue(tester);
      await tester.pumpAndSettle();

      // The onboarding-success screen's distinctive copy.
      expect(find.text("You're All Set"), findsOneWidget);
    });
  });

  group('onboarding success screen', () {
    testWidgets('Continue to Sign In routes to the sign-in screen', (
      tester,
    ) async {
      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);
      // onboardingSuccess is an ungated onboarding route, so we can land
      // there directly while unauthenticated.
      router.go(AppRoutes.onboardingSuccess);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're All Set"), findsOneWidget);
      final Finder ctaFinder = find.text('Continue to Sign In');
      expect(ctaFinder, findsOneWidget);
      final ElevatedButton cta = tester.widget<ElevatedButton>(
        find.ancestor(of: ctaFinder, matching: find.byType(ElevatedButton)),
      );
      expect(cta.onPressed, isNotNull);
      cta.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}

/// Invokes the onboarding primary ElevatedButton.icon onPressed directly.
///
/// The carousel's single ElevatedButton.icon drives both Continue (pages
/// 1-2) and Get Started (page 3); calling onPressed avoids hit-test fragility
/// from the page-indicator Row overlapping the button's tap target.
void _tapContinue(WidgetTester tester) {
  final ElevatedButton button = tester.widget<ElevatedButton>(
    find.byType(ElevatedButton),
  );
  expect(button.onPressed, isNotNull, reason: 'Continue button is disabled');
  button.onPressed!();
}
