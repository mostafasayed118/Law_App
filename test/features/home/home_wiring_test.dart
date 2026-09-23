import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:legalhub/l10n/app_localizations.dart';

/// The D-S4 wiring tests: the home dashboard's previously dead taps — the
/// notification bell, the app-bar avatar, and the practice-area cards — now
/// navigate. The entry-card navigations are covered by the router suite;
/// this file pins the tap behavior through the real router.
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

  Future<void> pumpWiredHome(WidgetTester tester) async {
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

  testWidgets('the notification bell opens the org feed', (tester) async {
    await pumpWiredHome(tester);

    await tester.tap(find.byTooltip('Notification feed'));
    await tester.pumpAndSettle();

    expect(find.text('Notification feed'), findsOneWidget);
  });

  testWidgets('the app-bar avatar opens the profile surface', (tester) async {
    await pumpWiredHome(tester);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('a practice-area card opens discovery pre-narrowed', (
    tester,
  ) async {
    // A wide, tall viewport renders the whole dashboard without scrolling
    // AND fits all four practice-area cards side to side (the horizontal
    // row is lazy, so the family card only builds once it is on screen).
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpWiredHome(tester);

    // The family card deep-links with ?area=family; only the family
    // attorney survives the pre-applied filter.
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    expect(find.text('Find an Attorney'), findsOneWidget);
    expect(find.text('Youssef Haddad'), findsOneWidget);
    expect(find.text('Layla Mansour'), findsNothing);
  });

  testWidgets('the video entry card sits beside the booking entry and opens '
      'the demo surface (D-15 A-2)', (tester) async {
    await pumpWiredHome(tester);

    expect(find.text('Video consultation'), findsOneWidget);
    expect(find.textContaining('Preview the demo call'), findsOneWidget);

    await tester.tap(find.text('Video consultation'));
    await tester.pumpAndSettle();

    expect(find.text('Demo attorney — A. Hassan'), findsOneWidget);
    expect(find.text('Join demo call'), findsWidgets);
  });
}
