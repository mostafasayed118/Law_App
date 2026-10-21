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
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// A deep link the app does not own: the URI a VIEW intent carried on the
/// device (F2, `docs/device_e2e_2026-10-21_c835ced.md` §2). The app owns
/// exactly one deep link (the accept-invite share link), so this URI matches
/// no route and go_router raises "no routes for location".
const String _unmatchedDeepLink = 'com.legalhub.app.dev:///not-a-route';

/// The copy of the calm surface an unmatched deep link must land on.
const String _unmatchedRouteTitle = 'This link could not be opened.';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;

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
  });

  tearDown(() async {
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  /// A localized harness matching the one the app wires, so the router's
  /// error surface resolves [AppLocalizations.of] and the route builders
  /// find the cubits the app provides app-wide.
  Widget harness({required Widget child, required GoRouter router}) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
        BlocProvider<ThemeCubit>.value(value: themeCubit),
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

  /// The URI the router is currently showing.
  Uri topUri(GoRouter router) => router.routerDelegate.currentConfiguration.uri;

  /// Hands the app the deep link the way the platform does: Android puts the
  /// VIEW intent's data URI in the platform default route name, and go_router
  /// prefers it over the router's own `initialLocation` (go_router
  /// `router.dart` — `_effectiveInitialLocation`).
  void arriveByPlatformDefaultRouteName(WidgetTester tester, String location) {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
  }

  group('unmatched deep link (F2 — no raw GoException)', () {
    testWidgets(
      'a cold unmatched deep link renders a calm surface, never the raw '
      'GoException',
      (tester) async {
        arriveByPlatformDefaultRouteName(tester, _unmatchedDeepLink);

        await authCubit.startDemoSession();
        final GoRouter router = createAppRouter(authCubit);
        addTearDown(router.dispose);

        await tester.pumpWidget(
          harness(child: const SizedBox.shrink(), router: router),
        );
        await tester.pumpAndSettle();

        // go_router's default error page prints the raw exception — the
        // "Page Not Found" + "no routes for location: …" screen the device
        // showed. It must never reach the user.
        expect(find.text('Page Not Found'), findsNothing);
        expect(find.textContaining('GoException'), findsNothing);
        expect(find.textContaining('no routes for location'), findsNothing);

        // The calm, localized surface replaces it.
        expect(find.text(_unmatchedRouteTitle), findsOneWidget);
      },
    );

    testWidgets('the calm surface routes back into the app', (tester) async {
      arriveByPlatformDefaultRouteName(tester, _unmatchedDeepLink);

      await authCubit.startDemoSession();
      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        harness(child: const SizedBox.shrink(), router: router),
      );
      await tester.pumpAndSettle();

      expect(find.text(_unmatchedRouteTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Home'));
      await tester.pumpAndSettle();

      expect(topUri(router).path, AppRoutes.home);
      expect(find.text(_unmatchedRouteTitle), findsNothing);
    });

    testWidgets('a warm unmatched deep link renders the same calm surface', (
      tester,
    ) async {
      await authCubit.startDemoSession();
      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        harness(child: const SizedBox.shrink(), router: router),
      );
      await tester.pumpAndSettle();

      // The warm path: Flutter delivers the VIEW intent's URI as a pushed
      // route while the app is already running.
      await tester.binding.handlePushRoute(_unmatchedDeepLink);
      await tester.pumpAndSettle();

      expect(find.text('Page Not Found'), findsNothing);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.text(_unmatchedRouteTitle), findsOneWidget);
    });

    testWidgets(
      'an unmatched deep link while signed out lands on sign-in, never the '
      'raw GoException',
      (tester) async {
        arriveByPlatformDefaultRouteName(tester, _unmatchedDeepLink);

        final GoRouter router = createAppRouter(authCubit);
        addTearDown(router.dispose);

        await tester.pumpWidget(
          harness(child: const SizedBox.shrink(), router: router),
        );
        await tester.pumpAndSettle();

        expect(find.text('Page Not Found'), findsNothing);
        expect(find.textContaining('GoException'), findsNothing);
        expect(find.text('Welcome Back'), findsOneWidget);
      },
    );
  });

  group('accept-invite deep link (the one link the app owns)', () {
    testWidgets(
      'the accept-invite link still routes to the accept-invitation surface',
      (tester) async {
        await authCubit.startDemoSession();
        final GoRouter router = createAppRouter(authCubit);
        addTearDown(router.dispose);

        await tester.pumpWidget(
          harness(child: const SizedBox.shrink(), router: router),
        );
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

        // The one deep link the app owns keeps working exactly as before:
        // the listener buffers the token and drives the router to the accept
        // surface — never the error surface.
        expect(topUri(router).path, AppRoutes.acceptInvitation);
        expect(find.text('Page Not Found'), findsNothing);
        expect(find.textContaining('GoException'), findsNothing);
      },
    );
  });
}

/// Stands in for the `app_links` plugin: hands the listener one cold-start
/// URI and never emits a warm one.
class _StubAppLinkSource implements AppLinkSource {
  _StubAppLinkSource({required this.initialLink});

  final Uri? initialLink;

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get onUri => const Stream<Uri>.empty();
}
