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
// Also pins the §4.4 no-false-assurance fix: the OTP "Resend" control is
// disabled and carries the "unavailable in demo" label, not the plain
// "Resend Code" label that implies a code was sent.
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

  testWidgets(
    'the OTP resend control is disabled and does not imply a sent code',
    (tester) async {
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

      // The resend control is disabled (onPressed null) — §4.4 no-false-
      // assurance: a tappable no-op would imply a code was sent.
      final TextButton resend = tester.widget<TextButton>(
        find.byType(TextButton).last,
      );
      expect(resend.onPressed, isNull);
      // The label states "unavailable in demo", not the plain "Resend Code"
      // that implies a sent code.
      expect(find.text('Resend Code (unavailable in demo)'), findsOneWidget);
      expect(find.text('Resend Code'), findsNothing);
    },
  );
}

class _CapturingRecoveryGateway implements PasswordRecoveryGateway {
  PasswordRecoveryRequest? received;

  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    received = request;
    return Result<void>.success(null);
  }
}
