import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// SignUpScreen has no cubit and no backend (its class doc says "No backend
// registration exists yet; submitting shows a snackbar and routes back to
// sign-in. Real registration is a later data-layer slice."). These tests pin
// the CURRENT stub behavior so that when the real wiring lands in a later
// batch, the behavior change is intentional and detected, not accidental.
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

  // Pump SignUpScreen through the router so context.go(AppRoutes.signIn) is
  // observable as a navigation. The screen is an ungated auth route, so an
  // unauthenticated router lands on it directly.
  Widget pumpScreen() {
    final GoRouter router = createAppRouter(authCubit);
    addTearDown(router.dispose);
    router.go(AppRoutes.signUp);
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('renders the sign-up title and the four input fields', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets);
    // Four text inputs: full name, email, phone, password. The password field
    // is a PasswordField (which wraps a TextFormField internally), so
    // TextFormField is the stable type to count.
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets('disables the create-account button until the terms box is checked', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    // _agreedToTerms is false initially, so onPressed is null (disabled).
    expect(button.onPressed, isNull);

    // Check the terms checkbox to enable the button.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final ElevatedButton enabled = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets(
    'does not submit when the form is invalid (empty fields, terms checked)',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      // Enable the button by agreeing to terms, but leave the fields empty.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pump();

      // Validation failed: no snackbar shown, still on the sign-up screen.
      expect(find.textContaining('Verification code sent'), findsNothing);
      expect(find.text('Create Account'), findsWidgets);
    },
  );

  testWidgets(
    'stub submit shows the code-sent snackbar and routes back to sign-in',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      // Fill all four fields with valid values.
      await tester.enterText(find.byType(TextFormField).at(0), 'Amira Hassan');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'amira@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '+201234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'strong-pw-1');
      await tester.pump();

      // Agree to terms to enable the submit button.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pumpAndSettle();

      // Stub behavior: snackbar with the code-sent notice, then navigation to
      // the sign-in screen (its distinctive welcome copy).
      expect(find.textContaining('Verification code sent'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    },
  );
}
