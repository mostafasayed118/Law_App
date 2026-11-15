import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Local screenshot capture for the responsive breakpoints.
///
/// Not a CI golden: goldens are font/rasterizer-sensitive across platforms,
/// and this repo's CI runs on Linux while contributors may be on Windows.
/// Instead this test is skipped unless `CAPTURE_SCREENSHOTS=1` is set, and it
/// writes reviewable PNGs to `build/responsive_screens/`.
///
/// Run:
/// `CAPTURE_SCREENSHOTS=1 flutter test test/responsive/screenshot_capture_test.dart`
void main() {
  final bool enabled = Platform.environment['CAPTURE_SCREENSHOTS'] == '1';

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

  /// One pump + one capture per test. Re-pumping the same app inside a test
  /// after `toImage` leaves the frame pipeline unsettled (10-minute hang), so
  /// every screenshot starts from a fresh binding.
  Future<void> captureAt(
    WidgetTester tester, {
    required Size size,
    required String name,
    String? route,
  }) async {
    await loadRenderFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    configureDependencies();
    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
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
    final RenderRepaintBoundary boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final ByteData? data = await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      return bytes;
    });
    final Directory dir = Directory('build/responsive_screens')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }

  const Timeout shotTimeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'capture home at 320',
    (WidgetTester tester) =>
        captureAt(tester, size: const Size(320, 568), name: 'home-320'),
    skip: !enabled,
    timeout: shotTimeout,
  );

  testWidgets(
    'capture home at 600',
    (WidgetTester tester) =>
        captureAt(tester, size: const Size(600, 800), name: 'home-600'),
    skip: !enabled,
    timeout: shotTimeout,
  );

  testWidgets(
    'capture home at 1024',
    (WidgetTester tester) =>
        captureAt(tester, size: const Size(1024, 768), name: 'home-1024'),
    skip: !enabled,
    timeout: shotTimeout,
  );

  testWidgets(
    'capture matters two-pane',
    (WidgetTester tester) => captureAt(
      tester,
      size: const Size(1024, 768),
      name: 'matters-two-pane-1024',
      route: AppRoutes.matters,
    ),
    skip: !enabled,
    timeout: shotTimeout,
  );

  testWidgets(
    'capture messages two-pane',
    (WidgetTester tester) => captureAt(
      tester,
      size: const Size(1024, 768),
      name: 'messages-two-pane-1024',
      route: AppRoutes.messages,
    ),
    skip: !enabled,
    timeout: shotTimeout,
  );

  testWidgets(
    'capture booking landscape',
    (WidgetTester tester) => captureAt(
      tester,
      size: const Size(1024, 768),
      name: 'booking-landscape-1024',
      route: AppRoutes.book,
    ),
    skip: !enabled,
    timeout: shotTimeout,
  );
}
