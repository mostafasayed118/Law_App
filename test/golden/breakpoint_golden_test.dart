import 'dart:io';

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

import '../support/render_fonts.dart';

/// Pixel pins for the responsive breakpoints.
///
/// These run only when `RUN_GOLDENS=1` (the dedicated CI job), because the
/// baseline PNGs are generated in the pinned Linux renderer
/// (`ghcr.io/cirruslabs/flutter:3.44.4`, the CI Flutter version). A Windows
/// developer running `flutter test` skips them instead of failing on
/// rasterizer differences.
///
/// Regenerate inside the pinned image:
/// `docker run --rm -v "$PWD:/app" -w /app \
///   ghcr.io/cirruslabs/flutter:3.44.4 \
///   bash -lc "flutter pub get && RUN_GOLDENS=1 \
///   flutter test test/golden --update-goldens"`
void main() {
  final bool enabled = Platform.environment['RUN_GOLDENS'] == '1';

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
    String? route,
  }) async {
    await loadRenderFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    configureDependencies();
    const Key rootKey = Key('golden-root');
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: LegalHubApp(
          router: router,
          authCubit: authCubit,
          localeCubit: localeCubit,
          themeCubit: themeCubit,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await authCubit.startDemoSession();
    await tester.pumpAndSettle();
    if (route != null) {
      router.go(route);
      await tester.pumpAndSettle();
    }
  }

  Future<void> pin(
    WidgetTester tester, {
    required Size size,
    required String name,
    String? route,
  }) async {
    await pumpApp(tester, size: size, route: route);
    await expectLater(
      find.byKey(const Key('golden-root')),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets(
    'home at 320',
    (WidgetTester tester) =>
        pin(tester, size: const Size(320, 568), name: 'home-320'),
    skip: !enabled,
  );

  testWidgets(
    'home at 1024 (rail)',
    (WidgetTester tester) =>
        pin(tester, size: const Size(1024, 768), name: 'home-1024'),
    skip: !enabled,
  );

  testWidgets(
    'matters two-pane at 1024',
    (WidgetTester tester) => pin(
      tester,
      size: const Size(1024, 768),
      name: 'matters-1024',
      route: AppRoutes.matters,
    ),
    skip: !enabled,
  );

  testWidgets(
    'messages two-pane at 1024',
    (WidgetTester tester) => pin(
      tester,
      size: const Size(1024, 768),
      name: 'messages-1024',
      route: AppRoutes.messages,
    ),
    skip: !enabled,
  );
}
