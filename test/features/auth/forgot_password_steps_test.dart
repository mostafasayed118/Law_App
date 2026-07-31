import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/auth/presentation/forgot_password/recovery_routing_context.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// These tests pin the step-level behavior after the email/OTP threading
// change (83f5bbf). Step 1 threads the entered email to step 2 via
// RecoveryRoutingContext (GoRouter in-memory `extra`, never the URL — email is
// PII); step 2 validates 6 digits, threads email+OTP onward, and keeps the
// "Resend code" control disabled (INSTRUCTIONS §4.4 — no false assurance: no
// gateway exists, so a tappable control would imply a code was sent). The
// end-to-end request-object proof lives in forgot_password_threading_test.dart;
// this file pins each step in isolation.
//
// The steps have no cubit/gateway of their own. The OTP step routes to the
// reset step, which resolves PasswordRecoveryGateway from the service
// locator. configureDependencies() is idempotent and registers the dev fake,
// so the router can navigate through the reset screen without a backend.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;

  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(gateway, InMemoryErrorReporter());
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  Widget pumpAt(String route) {
    final GoRouter router = createAppRouter(authCubit);
    addTearDown(router.dispose);
    router.go(route);
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

  group('ForgotPasswordEmailScreen (step 1)', () {
    testWidgets('renders the recover-password title and the hero badge', (
      tester,
    ) async {
      await tester.pumpWidget(pumpAt(AppRoutes.forgotPassword));
      await tester.pumpAndSettle();

      expect(find.text('Recover Password'), findsOneWidget);
      expect(find.byIcon(Icons.lock_reset_outlined), findsOneWidget);
      expect(find.text('Send Code'), findsOneWidget);
    });

    testWidgets('does not advance when the email field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(pumpAt(AppRoutes.forgotPassword));
      await tester.pumpAndSettle();

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pump();

      // Validation failed: still on the email step (no snackbar, title remains).
      expect(find.textContaining('Verification code sent'), findsNothing);
      expect(find.text('Recover Password'), findsOneWidget);
    });

    testWidgets(
      'shows the code-sent snackbar and routes to the OTP step on a valid email',
      (tester) async {
        await tester.pumpWidget(pumpAt(AppRoutes.forgotPassword));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'amira@example.com',
        );
        await tester.pump();

        final ElevatedButton button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton).first,
        );
        button.onPressed!();
        await tester.pumpAndSettle();

        // Snackbar notice, then navigation to the OTP step whose title is
        // "Verify Email".
        expect(find.textContaining('Verification code sent'), findsOneWidget);
        expect(find.text('Verify Email'), findsOneWidget);

        // The email rides the route `extra` (in-memory, never the URL — email
        // is PII). Reading it back from the OTP route's GoRouterState pins the
        // 83f5bbf threading at the step boundary.
        final GoRouterState otpState = GoRouterState.of(
          tester.element(find.text('Verify Email')),
        );
        final RecoveryRoutingContext? extra =
            otpState.extra is RecoveryRoutingContext
            ? otpState.extra! as RecoveryRoutingContext
            : null;
        expect(extra, isNotNull);
        expect(extra!.email, 'amira@example.com');
        expect(extra.otp, '');
      },
    );

    testWidgets('back-to-sign-in link routes to the sign-in screen', (
      tester,
    ) async {
      await tester.pumpWidget(pumpAt(AppRoutes.forgotPassword));
      await tester.pumpAndSettle();

      final Finder linkFinder = find.text('Back to Sign In');
      expect(linkFinder, findsOneWidget);
      final TextButton link = tester.widget<TextButton>(
        find.ancestor(of: linkFinder, matching: find.byType(TextButton)),
      );
      expect(link.onPressed, isNotNull);
      link.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });

  group('ForgotPasswordOtpScreen (step 2)', () {
    testWidgets(
      'renders the verify-email title and is disabled until 6 digits',
      (tester) async {
        await tester.pumpWidget(pumpAt(AppRoutes.forgotPasswordOtp));
        await tester.pumpAndSettle();

        expect(find.text('Verify Email'), findsOneWidget);
        expect(find.text('Verify & Continue'), findsOneWidget);

        // No digits entered: the verify button is disabled (onPressed null).
        final ElevatedButton button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton).first,
        );
        expect(button.onPressed, isNull);

        // The resend control is disabled by design (83f5bbf, §4.4): no
        // gateway exists, so it must not imply a code was sent. The label
        // states "unavailable in demo" rather than the plain "Resend Code".
        final TextButton resend = tester.widget<TextButton>(
          find.byType(TextButton).last,
        );
        expect(resend.onPressed, isNull);
        expect(find.text('Resend Code (unavailable in demo)'), findsOneWidget);
        expect(find.text('Resend Code'), findsNothing);
      },
    );

    testWidgets(
      'enables Verify & Continue once all 6 digits cells are filled and routes to reset',
      (tester) async {
        await tester.pumpWidget(pumpAt(AppRoutes.forgotPasswordOtp));
        await tester.pumpAndSettle();

        // Enter one digit into each of the 6 cells.
        for (int i = 0; i < 6; i++) {
          await tester.enterText(find.byType(TextField).at(i), '$i');
          await tester.pump();
        }

        final ElevatedButton button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton).first,
        );
        expect(button.onPressed, isNotNull);
        button.onPressed!();
        await tester.pumpAndSettle();

        // Routed to the reset step. "Reset Password" appears as both the
        // page title and the button label on that screen, so assert at least
        // one match rather than exactly one.
        expect(find.text('Reset Password'), findsWidgets);

        // The entered OTP rides the route `extra` onward (in-memory only).
        // Step 1 was skipped in this test, so the email falls back to the
        // empty context — the OTP itself is the threaded value under pin.
        final GoRouterState resetState = GoRouterState.of(
          tester.element(find.text('Reset Password').first),
        );
        final RecoveryRoutingContext? resetExtra =
            resetState.extra is RecoveryRoutingContext
            ? resetState.extra! as RecoveryRoutingContext
            : null;
        expect(resetExtra, isNotNull);
        expect(resetExtra!.otp, '012345');
        expect(resetExtra.email, '');
      },
    );
  });
}
