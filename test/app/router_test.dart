import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late GoRouter router;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
    router = createAppRouter(authCubit);
  });

  tearDown(() async {
    router.dispose();
    await authCubit.close();
    await gateway.dispose();
  });

  /// A localized harness matching the one used by [LegalHubApp] so route
  /// builders resolve [AppLocalizations.of] and a real theme, and auth route
  /// builders find the [AuthCubit] provider.
  Widget harness({required Widget child}) {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('router redirect logic', () {
    testWidgets('keeps an unauthenticated user on the sign-in route', (
      tester,
    ) async {
      await tester.pumpWidget(harness(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // The sign-in screen renders the localized welcome copy, proving we
      // landed on the /sign-in route rather than a protected route.
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets(
      'redirects an authenticated user away from auth routes to home',
      (tester) async {
        await authCubit.startDemoSession();
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Authenticated redirect lands on /home; the demo greeting appears.
        expect(find.textContaining('Hello, Demo user'), findsOneWidget);
        expect(authCubit.state.isAuthenticated, isTrue);
      },
    );

    testWidgets(
      'blocks unauthenticated access to protected routes by sending to sign-in',
      (tester) async {
        // Start already at a protected route; the redirect fires to /sign-in.
        router.go('/home');
        await tester.pumpWidget(harness(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(authCubit.state.status, AuthStatus.unauthenticated);
      },
    );
  });
}
