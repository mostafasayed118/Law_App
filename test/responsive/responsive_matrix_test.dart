import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/main.dart';

/// Exhaustive responsive matrix: every route × every supported width ×
/// text scales up to the 2.0 accessibility ceiling, including a short
/// landscape phone viewport (640×360) that the smoke suite does not cover.
///
/// A route that overflows renders a framework exception during pump; the
/// helper fails with the exact route, size, scale and exception text.
void main() {
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  late GoRouter router;

  setUp(() {
    authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await resetServiceLocator();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
    Locale locale = const Locale('en'),
    bool signIn = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    configureDependencies();
    await localeCubit.setLocale(locale);
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
        themeCubit: themeCubit,
      ),
    );
    await tester.pumpAndSettle();
    if (signIn) {
      await authCubit.startDemoSession();
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(
    WidgetTester tester,
    String route, {
    required Size size,
    required double textScale,
    required List<String> failures,
  }) async {
    router.go(route);
    await tester.pumpAndSettle();
    final Object? exception = tester.takeException();
    if (exception != null) {
      failures.add(
        'Layout exception on $route at ${size.width}x${size.height} '
        '(scale $textScale):\n$exception',
      );
    }
  }

  const List<String> shellRoutes = <String>[
    AppRoutes.home,
    AppRoutes.book,
    AppRoutes.discovery,
    '/discovery/atty-1',
    AppRoutes.matters,
    AppRoutes.matterCreate,
    '/matters/matter-1',
    AppRoutes.vault,
    AppRoutes.messages,
    '/messages/thread-1',
    '${AppRoutes.search}?q=demo',
    AppRoutes.invoices,
    AppRoutes.alerts,
    AppRoutes.tasks,
    AppRoutes.video,
    AppRoutes.approvals,
    AppRoutes.research,
    AppRoutes.settings,
    AppRoutes.organizations,
    AppRoutes.orgAudit,
    AppRoutes.acceptInvitation,
    AppRoutes.profile,
    AppRoutes.notifications,
    AppRoutes.notificationsFeed,
    AppRoutes.platformAdmin,
    AppRoutes.attorneysAdmin,
  ];

  const List<String> authRoutes = <String>[
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.forgotPassword,
    AppRoutes.forgotPasswordOtp,
    AppRoutes.forgotPasswordReset,
    AppRoutes.onboarding,
    AppRoutes.onboardingSuccess,
  ];

  const List<Size> widths = <Size>[
    Size(320, 568), // smallest supported phone
    Size(390, 844), // current iPhone
    Size(600, 800), // medium tablet
    Size(768, 1024), // large tablet portrait
    Size(1024, 768), // landscape tablet
    Size(640, 360), // short landscape phone (height-constrained)
  ];

  testWidgets('every signed-in route survives every width at scale 1.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    for (final Size size in widths) {
      await pumpApp(tester, size: size);
      for (final String route in shellRoutes) {
        await open(
          tester,
          route,
          size: size,
          textScale: 1.0,
          failures: failures,
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('every signed-in route survives text scale 2.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(600, 800),
      const Size(640, 360), // short landscape + 2.0 is the worst case
    ]) {
      await pumpApp(tester, size: size, textScale: 2.0);
      for (final String route in shellRoutes) {
        await open(
          tester,
          route,
          size: size,
          textScale: 2.0,
          failures: failures,
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('every signed-out route survives every width at scale 1.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    for (final Size size in widths) {
      await pumpApp(tester, size: size, signIn: false);
      for (final String route in authRoutes) {
        await open(
          tester,
          route,
          size: size,
          textScale: 1.0,
          failures: failures,
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('every signed-out route survives text scale 2.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(600, 800),
      const Size(640, 360),
    ]) {
      await pumpApp(tester, size: size, textScale: 2.0, signIn: false);
      for (final String route in authRoutes) {
        await open(
          tester,
          route,
          size: size,
          textScale: 2.0,
          failures: failures,
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('key routes survive text scale 3.0 (extreme accessibility)', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(1024, 768),
    ]) {
      await pumpApp(tester, size: size, textScale: 3.0);
      for (final String route in shellRoutes) {
        await open(
          tester,
          route,
          size: size,
          textScale: 3.0,
          failures: failures,
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('signed-out routes survive text scale 3.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    await pumpApp(
      tester,
      size: const Size(320, 568),
      textScale: 3.0,
      signIn: false,
    );
    for (final String route in authRoutes) {
      await open(
        tester,
        route,
        size: const Size(320, 568),
        textScale: 3.0,
        failures: failures,
      );
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('shell is adaptive: rail on wide, bottom bar on phone', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(411, 867));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await pumpApp(tester, size: const Size(1024, 768));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // The rail drives the same real routes as the bottom bar.
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('Arabic RTL survives 320px at text scale 2.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    await pumpApp(
      tester,
      size: const Size(320, 568),
      textScale: 2.0,
      locale: const Locale('ar'),
    );
    for (final String route in <String>[
      AppRoutes.home,
      AppRoutes.matters,
      '/matters/matter-1',
      AppRoutes.vault,
      AppRoutes.messages,
      '/messages/thread-1',
      AppRoutes.settings,
      AppRoutes.invoices,
      AppRoutes.tasks,
    ]) {
      await open(
        tester,
        route,
        size: const Size(320, 568),
        textScale: 2.0,
        failures: failures,
      );
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('keyboard-open forms survive text scale 2.0', (
    WidgetTester tester,
  ) async {
    final List<String> failures = <String>[];
    await pumpApp(tester, size: const Size(320, 568), textScale: 2.0);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    for (final String route in <String>[
      AppRoutes.book,
      AppRoutes.matterCreate,
    ]) {
      await open(
        tester,
        route,
        size: const Size(320, 568),
        textScale: 2.0,
        failures: failures,
      );
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });
}
