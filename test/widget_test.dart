import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/main.dart';

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
  });

  testWidgets('boots into the sign-in screen (initial route)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
      ),
    );
    await tester.pumpAndSettle();

    // The real router sets initialLocation = /sign-in, so the first render
    // must be the sign-in welcome copy.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('demo flow reaches the home shell and changes locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LegalHubApp(
        router: router,
        authCubit: authCubit,
        localeCubit: localeCubit,
      ),
    );
    await tester.pumpAndSettle();

    // Start the demo session directly (the tap mechanics of the sign-in
    // button are covered separately in the sign-in screen widget test). The
    // goal here is to verify the authenticated shell and locale switching.
    await authCubit.startDemoSession();
    await tester.pumpAndSettle();

    // Authenticated redirect lands on /home. The greeting uses the demo
    // display name from FakeAuthGateway.
    expect(find.textContaining('Hello, Demo user'), findsOneWidget);

    // Settings is reachable via the bottom navigation.
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsWidgets);

    // Round-trip home ↔ settings through the shell nav bar: tapping each
    // destination must navigate via its own route (the record-based tap
    // target in _AppShell, not a hardcoded index) — pinned end-to-end in the
    // app-level harness as a user would drive it.
    await tester.ensureVisible(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    // Back on /home: the demo greeting proves the Home destination routed
    // through the real GoRouter rather than a static swap.
    expect(find.textContaining('Hello, Demo user'), findsOneWidget);

    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsWidgets);

    // Locale switch to Arabic flips UI to RTL strings.
    await tester.ensureVisible(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AR').last);
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsNWidgets(2));
    expect(find.text('اللغة'), findsWidgets);
  });

  testWidgets('demo flow drives the shell nav round-trip under Arabic RTL', (
    WidgetTester tester,
  ) async {
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

    // Switch to Arabic via the settings dropdown (same path as the EN flow
    // above) so the shell renders RTL before the round-trip.
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AR').last);
    await tester.pumpAndSettle();

    // RTL is active: Arabic settings title + nav label (2 total).
    expect(find.text('الإعدادات'), findsNWidgets(2));
    expect(find.text('اللغة'), findsWidgets);

    // Round-trip home ↔ settings under RTL: the nav labels are Arabic, and
    // tapping each destination must still route via its own route through
    // the real GoRouter — pinned end-to-end under right-to-left layout.
    await tester.ensureVisible(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    expect(find.textContaining('مرحبًا'), findsOneWidget);

    await tester.ensureVisible(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('اللغة'), findsWidgets);
  });
}
