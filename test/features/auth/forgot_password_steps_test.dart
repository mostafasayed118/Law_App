import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// The email and OTP steps have no cubit and no gateway yet (their class docs say
// so explicitly). These tests pin the current stub behavior: validation gates
// the forward routing, and the route only advances on a valid submit.
//
// The OTP step routes to the reset step, which resolves PasswordRecoveryGateway
// from the service locator. configureDependencies() is idempotent and
// registers the dev fake, so the router can navigate through the reset screen
// without a real backend.
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

        // Stub: snackbar notice, then navigation to the OTP step whose title
        // is "Verify Email".
        expect(find.textContaining('Verification code sent'), findsOneWidget);
        expect(find.text('Verify Email'), findsOneWidget);
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
      },
    );
  });
}
