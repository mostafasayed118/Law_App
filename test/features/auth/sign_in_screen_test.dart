import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/auth/presentation/sign_in_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
  });

  // The sign-in screen pumps SignInScreen directly (no router) for the
  // isolated widget interactions, since the SignInScreen only needs the
  // AuthCubit provider above it.
  Widget pumpIsolated() {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SignInScreen(),
      ),
    );
  }

  testWidgets('renders the welcome copy and brand-remediated label', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    // D-01 remediation: the old "Lexis" wordmark must not appear.
    expect(find.textContaining('Lexis'), findsNothing);
    expect(find.textContaining('LegalHub'), findsWidgets);
  });

  testWidgets('form validation blocks submit with empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    // Invoke the primary submit callback directly. The form is empty, so
    // validation fails and startDemoSession must NOT be called.
    final Finder buttonFinder = find.byType(ElevatedButton).last;
    final ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pump();

    // No demo session started; still unauthenticated.
    expect(authCubit.state.status, AuthStatus.unauthenticated);
  });

  testWidgets('valid form submit starts the demo session via the cubit', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'amira@example.com');
    await tester.enterText(find.byType(TextField).last, 'any-password');

    // Invoke the submit callback directly to avoid hit-test fragility in the
    // scrollable auth form; the goal is to verify the validated form routes
    // through to AuthCubit.signIn (which the dev fake resolves to the demo
    // session).
    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).last,
    );
    button.onPressed!();
    await tester.pumpAndSettle();

    expect(authCubit.state.isAuthenticated, isTrue);
    expect(authCubit.state.session?.userId, 'demo-user');
  });

  testWidgets('forgot-password link routes to the forgot-password screen', (
    tester,
  ) async {
    final router = createAppRouter(authCubit);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The "Forgot Password?" trailing TextButton. Invoke its onPressed
    // directly to avoid hit-test fragility in the scrollable auth form.
    final Finder linkFinder = find.text('Forgot Password?');
    expect(linkFinder, findsOneWidget);
    final TextButton link = tester.widget<TextButton>(
      find.ancestor(of: linkFinder, matching: find.byType(TextButton)),
    );
    expect(link.onPressed, isNotNull);
    link.onPressed!();
    await tester.pumpAndSettle();

    // Navigation landed on the forgot-password email step, whose title is
    // "Recover Password" and which shows the lock-reset hero badge.
    expect(find.text('Recover Password'), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset_outlined), findsOneWidget);
  });
}
