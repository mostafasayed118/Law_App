import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// Closes the recovery half of D-T2 (Batch 2): the email and OTP captured in
// steps 1-2 are threaded through the route `extra` to the reset screen, which
// builds a PasswordRecoveryRequest with the real values (not empty
// placeholders). These tests pump the whole flow through the router with a
// capturing gateway so the asserted object is the one the screen built.
//
// P3.1 wires the OTP "Resend" control to the recovery gateway: it re-sends
// to the threaded email with a generic acknowledgement (non-enumerating) and
// stays on the step, and a successful resend never blocks a later verify.
void main() {
  late FakeAuthGateway authGateway;
  late AuthCubit authCubit;

  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
    authGateway = FakeAuthGateway();
    authCubit = AuthCubit(authGateway, InMemoryErrorReporter());
  });

  tearDown(() async {
    await authCubit.close();
    await authGateway.dispose();
    await resetServiceLocator();
  });

  Widget pumpRouter() {
    final GoRouter router = createAppRouter(authCubit);
    addTearDown(router.dispose);
    router.go(AppRoutes.forgotPassword);
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

  testWidgets(
    'threads email and OTP from steps 1-2 into the PasswordRecoveryRequest',
    (tester) async {
      final _CapturingRecoveryGateway gateway = _CapturingRecoveryGateway();
      await serviceLocator.reset();
      serviceLocator.registerSingleton<PasswordRecoveryGateway>(gateway);

      await tester.pumpWidget(pumpRouter());
      await tester.pumpAndSettle();

      // Step 1: enter the email and send the code -> routes to OTP step.
      await tester.enterText(
        find.byType(TextFormField).first,
        'amira@example.com',
      );
      await tester.pump();
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).first)
          .onPressed!();
      await tester.pumpAndSettle();

      // Step 2: enter 6 digits, then verify -> routes to reset step.
      expect(find.text('Verify Email'), findsOneWidget);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(find.byType(TextField).at(i), '$i');
        await tester.pump();
      }
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).first)
          .onPressed!();
      await tester.pumpAndSettle();

      // Step 3: enter a new password + matching confirmation, then submit.
      expect(find.text('Reset Password'), findsWidgets);
      await tester.enterText(find.byType(TextFormField).first, 'newpassword1');
      await tester.enterText(find.byType(TextFormField).last, 'newpassword1');
      await tester.pump();
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).last)
          .onPressed!();
      await tester.pumpAndSettle();

      // The request the reset screen built carries the real email and OTP, not
      // empty placeholders. This is the D-T2 recovery-half closure proof.
      expect(gateway.received, isNotNull);
      expect(gateway.received!.email, 'amira@example.com');
      expect(gateway.received!.otp, '012345');
      expect(gateway.received!.newPassword, 'newpassword1');
    },
  );

  testWidgets('the OTP resend control re-sends the code to the same email', (
    tester,
  ) async {
    final _CapturingRecoveryGateway gateway = _CapturingRecoveryGateway();
    await serviceLocator.reset();
    serviceLocator.registerSingleton<PasswordRecoveryGateway>(gateway);

    await tester.pumpWidget(pumpRouter());
    await tester.pumpAndSettle();

    // Advance to the OTP step by submitting a valid email.
    await tester.enterText(
      find.byType(TextFormField).first,
      'amira@example.com',
    );
    await tester.pump();
    tester
        .widget<ElevatedButton>(find.byType(ElevatedButton).first)
        .onPressed!();
    await tester.pumpAndSettle();

    // P3.1: the resend control is wired to the gateway. Tapping it calls
    // sendCode with the same email that was threaded from step 1.
    final TextButton resend = tester.widget<TextButton>(
      find.byType(TextButton).last,
    );
    expect(resend.onPressed, isNotNull);
    resend.onPressed!();
    await tester.pumpAndSettle();

    expect(gateway.sentCodeEmail, 'amira@example.com');
    // Still on the OTP step: a resend must not advance the flow.
    expect(find.text('Verify Email'), findsOneWidget);
  });

  testWidgets(
    'a resend does not block a later verify (P3.1 guard regression pin)',
    (tester) async {
      final _CapturingRecoveryGateway gateway = _CapturingRecoveryGateway();
      await serviceLocator.reset();
      serviceLocator.registerSingleton<PasswordRecoveryGateway>(gateway);

      await tester.pumpWidget(pumpRouter());
      await tester.pumpAndSettle();

      // Advance to the OTP step by submitting a valid email.
      await tester.enterText(
        find.byType(TextFormField).first,
        'amira@example.com',
      );
      await tester.pump();
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).first)
          .onPressed!();
      await tester.pumpAndSettle();

      // Resend once; the cubit lands in ViewSuccess while staying on the
      // step. The next verify must still run (only submit keeps a success
      // guard — it navigates away; verify mirrors sendCode's loading-only
      // guard).
      final TextButton resend = tester.widget<TextButton>(
        find.byType(TextButton).last,
      );
      resend.onPressed!();
      await tester.pumpAndSettle();

      // Enter the 6 digits and verify → routes to reset despite the prior
      // resend success.
      for (int i = 0; i < 6; i++) {
        await tester.enterText(find.byType(TextField).at(i), '$i');
        await tester.pump();
      }
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).first)
          .onPressed!();
      await tester.pumpAndSettle();

      expect(gateway.verifiedEmail, 'amira@example.com');
      expect(gateway.verifiedCode, '012345');
      expect(find.text('Reset Password'), findsWidgets);
    },
  );
}

class _CapturingRecoveryGateway implements PasswordRecoveryGateway {
  PasswordRecoveryRequest? received;
  String? sentCodeEmail;
  String? verifiedEmail;
  String? verifiedCode;

  @override
  Future<Result<void>> sendCode(String email) async {
    sentCodeEmail = email;
    return Result<void>.success(null);
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  }) async {
    verifiedEmail = email;
    verifiedCode = code;
    return Result<void>.success(null);
  }

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    received = request;
    return Result<void>.success(null);
  }
}
