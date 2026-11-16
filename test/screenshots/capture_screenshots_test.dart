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
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/main.dart';

import '../support/render_fonts.dart';

/// Deterministic portfolio screenshots from the REAL app, the fake gateways
/// and the bundled fonts — no emulator, no credentials, no device frame.
///
/// This file is skipped in the default `flutter test` run and in CI. Generate
/// the images with:
///
///   CAPTURE_SCREENSHOTS=1 flutter test test/screenshots --update-goldens
///
/// (PowerShell: `$env:CAPTURE_SCREENSHOTS='1'; flutter test test/screenshots --update-goldens`)
///
/// The golden comparator writes the exact PNG bytes to the path below; the
/// images are generated artifacts and are never hand-edited.
void main() {
  final bool enabled = Platform.environment['CAPTURE_SCREENSHOTS'] == '1';
  const String dir = '../../docs/media/screenshots';
  const Key rootKey = Key('screenshot-root');

  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  late GoRouter router;
  late WidgetTester view;

  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
    authCubit = AuthCubit(
      FakeAuthGateway(),
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    await localeCubit.load();
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    await themeCubit.load();
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await resetServiceLocator();
  });

  Future<void> pumpApp({
    required Locale locale,
    required ThemeMode themeMode,
  }) async {
    await loadRenderFonts();
    view.view.physicalSize = const Size(1170, 2532); // 390x844 @3x
    view.view.devicePixelRatio = 3.0;
    view.view.viewInsets = FakeViewPadding.zero;
    addTearDown(view.view.reset);
    await localeCubit.setLocale(locale);
    await themeCubit.setThemeMode(themeMode);
    await view.pumpWidget(
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
    await view.pumpAndSettle();
    await authCubit.startDemoSession();
    await view.pumpAndSettle();
  }

  Future<void> capture(String name) =>
      expectLater(find.byKey(rootKey), matchesGoldenFile('$dir/$name.png'));

  Future<void> open(String route) async {
    router.go(route);
    await view.pumpAndSettle();
  }

  /// Seed one bookmark, one highlight and one history row so the Library
  /// index, reader and Saved screen show real populated states.
  Future<void> seedLibraryUserData() async {
    final LibraryUserDataGateway data =
        serviceLocator<LibraryUserDataGateway>();
    const String body =
        'ينظم هذا النموذج العلاقة الإيجارية بين المؤجر والمستأجر من حيث المدة والأجرة.';
    await data.toggleBookmark('legal-art-1-1');
    await data.createHighlight(
      articleId: 'legal-art-1-1',
      startOffset: 0,
      endOffset: body.runes.length,
      quote: body,
      color: HighlightColorSlot.yellow,
    );
    await data.recordReading('legal-art-1-1');
  }

  testWidgets('English light screenshots', (WidgetTester tester) async {
    if (!enabled) {
      return;
    }
    view = tester;
    await pumpApp(locale: const Locale('en'), themeMode: ThemeMode.light);
    await capture('01_home');
    await open(AppRoutes.matters);
    await capture('02_matters');
    await open(AppRoutes.discovery);
    await capture('03_discovery');
    await open('/messages/thread-1');
    await capture('04_messages');
    await open(AppRoutes.research);
    await capture('05_research');
    await open(AppRoutes.settings);
    await capture('06_settings');
    await seedLibraryUserData();
    await open(AppRoutes.library);
    await capture('07_library');
    await open('/library/articles/legal-art-1-1');
    await capture('08_article_reader');
    await open(AppRoutes.librarySaved);
    await capture('09_saved');
    await open(AppRoutes.privacy);
    await capture('10_privacy');
  }, skip: !enabled);

  testWidgets('Arabic RTL screenshots', (WidgetTester tester) async {
    if (!enabled) {
      return;
    }
    view = tester;
    await pumpApp(locale: const Locale('ar'), themeMode: ThemeMode.light);
    await capture('01_home_ar');
    await seedLibraryUserData();
    await open(AppRoutes.library);
    await capture('07_library_ar');
    await open('/library/articles/legal-art-1-1');
    await capture('08_article_reader_ar');
  }, skip: !enabled);

  testWidgets('dark mode screenshots', (WidgetTester tester) async {
    if (!enabled) {
      return;
    }
    view = tester;
    await pumpApp(locale: const Locale('en'), themeMode: ThemeMode.dark);
    await capture('01_home_dark');
    await seedLibraryUserData();
    await open('/library/articles/legal-art-1-1');
    await capture('08_article_reader_dark');
  }, skip: !enabled);
}
