import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/persistence/in_memory_locale_store.dart';
import 'package:legalhub/core/persistence/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// E2E BUG-1 regression (2026-09-24) — the missing back-stack coverage.
///
/// The live device pass found that the system BACK button exited the app from
/// every feature screen. The cause: every forward navigation from the home
/// dashboard used `context.go`, which REPLACES the nav stack, so Home was
/// never beneath the feature screen and `pop()` had nothing to fall back to.
/// The existing suite covered destinations but never back-stack behaviour,
/// which is exactly why the defect reached the device.
///
/// These tests pin the fix: reaching a feature screen from Home must leave a
/// poppable entry behind, so the system back gesture returns to Home instead
/// of leaving the app. They FAIL on the pre-fix code (all `go`) and PASS once
/// the forward navigations use `push`.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  late GoRouter router;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    configureDependencies();
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await authCubit.startDemoSession();
    router.go(AppRoutes.home);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<LocaleCubit>.value(value: localeCubit),
          BlocProvider<ThemeCubit>.value(value: themeCubit),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ThemeData.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The core BUG-1 assertion: after navigating forward, the router must be
  /// able to pop back to Home rather than sitting at the root.
  void expectCanPopBack() {
    expect(
      router.canPop(),
      isTrue,
      reason:
          'Forward navigation must PUSH (not `go`) so the system back '
          'gesture returns to Home instead of exiting the app (E2E BUG-1).',
    );
  }

  group('back-stack (E2E BUG-1 regression)', () {
    testWidgets('the notification bell pushes, so BACK returns to Home', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byTooltip('Notification feed'));
      await tester.pumpAndSettle();
      expect(find.text('Notification feed'), findsOneWidget);

      expectCanPopBack();

      router.pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello,'), findsOneWidget);
    });

    testWidgets('the app-bar avatar pushes, so BACK returns to Home', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      expectCanPopBack();

      router.pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello,'), findsOneWidget);
    });

    testWidgets('a practice-area card pushes, so BACK returns to Home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHome(tester);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Find an Attorney'), findsOneWidget);

      expectCanPopBack();

      router.pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello,'), findsOneWidget);
    });

    testWidgets('a settings row pushes, so BACK returns to Settings', (
      tester,
    ) async {
      await pumpHome(tester);

      // Settings is a bottom-nav TAB, so reaching it is a legitimate `go`.
      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsWidgets);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      expectCanPopBack();
    });

    testWidgets('the home dashboard itself is a root (nothing to pop)', (
      tester,
    ) async {
      await pumpHome(tester);

      // Home is the shell root: BACK here legitimately exits the app, which
      // is why the assertion above is scoped to forward navigations only.
      expect(router.canPop(), isFalse);
    });
  });
}
