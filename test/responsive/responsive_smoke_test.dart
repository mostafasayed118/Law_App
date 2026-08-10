import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/main.dart';

/// Responsive smoke suite: pumps the real app (router + shell + screens)
/// across the required device matrix and asserts NO layout exceptions.
///
/// RenderFlex/pixel overflows and clipped-widget assertions surface as
/// framework exceptions during `pumpAndSettle`, so a test that completes is
/// the overflow proof — no manual overflow grepping needed. Runs against the
/// dev fakes (env-less), matching every other widget test in the repo.
void main() {
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late GoRouter router;

  setUp(() {
    authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await resetServiceLocator();
  });

  /// Pumps the full app (LegalHubApp) at [size] with [textScale] and
  /// [locale], starts the demo session, and lands on /home. Any overflow in
  /// the shell or home layout fails the test via the framework.
  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
    Locale locale = const Locale('en'),
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
      ),
    );
    await tester.pumpAndSettle();
    await authCubit.startDemoSession();
    await tester.pumpAndSettle();
  }

  /// Drives [route] through the real router and settles; the screen renders
  /// (or a typed error state renders) without a layout exception. Any
  /// pending framework exception (RenderFlex overflow, clipped text, …) is
  /// surfaced with the route name for a self-diagnosing failure.
  Future<void> go(WidgetTester tester, String route) async {
    router.go(route);
    await tester.pumpAndSettle();
    final Object? exception = tester.takeException();
    if (exception != null) {
      fail('Layout exception on route $route:\n$exception');
    }
    // A route always renders a Scaffold — an empty tree would mean the guard
    // bounced or the route was dropped, which is itself a regression signal.
    expect(find.byType(Scaffold), findsWidgets);
  }

  // Required device matrix: 320/360/390/412 phones, 600/768 tablets,
  // 1024 landscape tablet — portrait and landscape covered by 1024×768.
  const List<Size> sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(412, 915),
    Size(600, 800),
    Size(768, 1024),
    Size(1024, 768),
  ];

  testWidgets('shell + home render at every device size (LTR, scale 1.0)', (
    WidgetTester tester,
  ) async {
    for (final Size size in sizes) {
      await pumpApp(tester, size: size);
      expect(find.textContaining('Hello, Demo user'), findsOneWidget);
      await tester.pump();
    }
  });

  testWidgets(
    'core shell surfaces render at 320×568 and 1024×768 without overflow',
    (WidgetTester tester) async {
      const List<String> routes = <String>[
        AppRoutes.matters,
        AppRoutes.vault,
        AppRoutes.messages,
        AppRoutes.invoices,
        AppRoutes.alerts,
        AppRoutes.tasks,
        AppRoutes.approvals,
        AppRoutes.organizations,
        AppRoutes.profile,
        AppRoutes.notifications,
        AppRoutes.platformAdmin,
        AppRoutes.settings,
        AppRoutes.book,
        AppRoutes.discovery,
        '${AppRoutes.search}?q=demo',
      ];
      for (final Size size in <Size>[Size(320, 568), Size(1024, 768)]) {
        await pumpApp(tester, size: size);
        for (final String route in routes) {
          await go(tester, route);
        }
      }
    },
  );

  testWidgets('text scale 2.0: home, matter list, matter details, settings', (
    WidgetTester tester,
  ) async {
    // 320×568 is the tightest surface; scale 2.0 is the largest supported
    // accessibility size. The fake seeds matters with ids matter-1..4, so the
    // details route renders the populated layout (not the not-found state).
    await pumpApp(tester, size: const Size(320, 568), textScale: 2.0);
    await go(tester, AppRoutes.matters);
    await go(tester, '/matters/matter-1');
    // The two-chip metadata rows (type + reverse cross-link) are the
    // tightest trailing layouts; verify them at the largest text scale.
    await go(tester, AppRoutes.vault);
    await go(tester, AppRoutes.messages);
    await go(tester, AppRoutes.settings);
  });

  testWidgets('text scale 1.3 at 600×800 tablet renders without overflow', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(600, 800), textScale: 1.3);
    await go(tester, AppRoutes.matters);
    await go(tester, AppRoutes.organizations);
  });

  testWidgets('shell nav round-trip at 320×568 stays overflow-free', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 568));
    // Leaving and returning to a shell surface exercises the route
    // transition's transient narrow layout on the incoming page.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final Object? toSettings = tester.takeException();
    if (toSettings != null) {
      fail('Layout exception navigating to Settings:\n$toSettings');
    }
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final Object? backHome = tester.takeException();
    if (backHome != null) {
      fail('Layout exception navigating back to Home:\n$backHome');
    }
    expect(find.textContaining('Hello, Demo user'), findsOneWidget);
  });

  testWidgets('Arabic RTL renders without overflow on phone and tablet', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(320, 568),
      locale: const Locale('ar'),
    );
    await go(tester, AppRoutes.matters);
    // Directionality is genuinely RTL in the Arabic session.
    final Finder matterText = find.textContaining(
      RegExp('[A-Za-z\u0600-\u06FF]'),
    );
    expect(matterText, findsWidgets);
    expect(
      Directionality.of(tester.element(matterText.first)),
      TextDirection.rtl,
    );
    await pumpApp(
      tester,
      size: const Size(768, 1024),
      locale: const Locale('ar'),
    );
    await go(tester, AppRoutes.settings);
  });

  testWidgets('keyboard-open booking form at 320×568 keeps the CTA usable', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 568));
    // Simulate the software keyboard; the form must resize and scroll rather
    // than clip the primary action.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await go(tester, AppRoutes.book);
    // With the keyboard open the viewport shrinks, so the Continue action sits
    // below the fold — scroll the form to reveal it (the point of the test:
    // the action stays REACHABLE, never hidden by the keyboard).
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    final Object? exception = tester.takeException();
    if (exception != null) {
      fail('Layout exception with keyboard open:\n$exception');
    }
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
