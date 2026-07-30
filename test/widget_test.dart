import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/main.dart';

void main() {
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late GoRouter router;

  setUp(() {
    authCubit = AuthCubit(FakeAuthGateway(), InMemoryErrorReporter());
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

    // The real router sets initialLocation = /sign-in. The access screen is no
    // longer routed, so the first render must be the sign-in welcome copy.
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
}
