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

/// Phase 0 RED: both conflict routes and the disclosure wizard state machine
/// are missing at the base commit. These assertions use only existing strings,
/// so the file compiles and fails on the unmodified app.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  late GoRouter router;

  setUp(() async {
    configureDependencies();
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    await localeCubit.load();
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    await themeCubit.load();
    await authCubit.startDemoSession();
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  Widget harness() => MultiBlocProvider(
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

  Future<void> open(WidgetTester tester, String path) async {
    router = createAppRouter(authCubit, initialLocation: path);
    tester.view.physicalSize = const Size(411, 867);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  testWidgets('disclosure route opens step 1', (WidgetTester tester) async {
    await open(tester, '/conflicts/disclose');
    expect(find.text('Identify Matter'), findsOneWidget);
  });

  testWidgets('conflict check route opens the search screen', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/check');
    expect(find.text('Conflict Check'), findsWidgets);
    expect(find.text('Check New Party or Entity'), findsOneWidget);
  });

  testWidgets('wizard advances and steps back without losing the draft', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/disclose');
    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('Party Identification'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Identify Matter'), findsOneWidget);
  });
}
