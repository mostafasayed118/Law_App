import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/auth/presentation/forgot_password/forgot_password_reset_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  // The reset screen resolves PasswordRecoveryGateway via the service locator
  // when it creates its PasswordRecoveryCubit. configureDependencies() is
  // idempotent and registers a FakePasswordRecoveryGateway, so the screen can
  // build without a real backend. Reset between tests keeps registrations
  // clean and avoids leaking a stale locator across files.
  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
  });

  Widget pumpScreen(Locale locale) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ForgotPasswordResetScreen(),
    );
  }

  // Regression: the confirm-password validator previously captured
  // _password.text at build time, so it could validate against a stale
  // password value when the new-password field was edited after build. The
  // fix defers the read into the validator closure. This test proves the
  // confirm validator re-evaluates against the *current* password value.
  testWidgets(
    'confirm-password validator re-evaluates against the current password',
    (tester) async {
      await tester.pumpWidget(pumpScreen(const Locale('en')));
      await tester.pumpAndSettle();

      // Enter an initial password that satisfies the minLength(8) rule.
      await tester.enterText(find.byType(TextFormField).first, 'password1');
      await tester.pump();

      // Enter a matching confirm value; validation must pass at this point.
      await tester.enterText(find.byType(TextFormField).last, 'password1');
      final FormState form = tester.state(find.byType(Form));
      expect(form.validate(), isTrue);

      // Now edit the new-password field to a different value WITHOUT
      // rebuilding the confirm validator's closure. If the validator had
      // captured the old password at build time, re-validating would still
      // pass against 'password1' (the stale value) — a false positive. With
      // the fix, re-validating must FAIL because the confirm field no longer
      // matches the current password.
      await tester.enterText(find.byType(TextFormField).first, 'newpassword2');
      await tester.pump();

      expect(form.validate(), isFalse);
    },
  );

  testWidgets('confirm-password validator passes when values match', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'newpassword2');
    await tester.enterText(find.byType(TextFormField).last, 'newpassword2');
    final FormState form = tester.state(find.byType(Form));
    expect(form.validate(), isTrue);
  });

  // The success path needs a GoRouter: on ViewSuccess the screen's BlocListener
  // shows the reset snackbar and calls context.go(AppRoutes.signIn). The
  // default FakePasswordRecoveryGateway registered by configureDependencies()
  // resolves to success, so a valid submit drives the full success lifecycle.
  testWidgets(
    'shows the success snackbar and routes to sign-in when recovery succeeds',
    (tester) async {
      final FakeAuthGateway authGateway = FakeAuthGateway();
      final AuthCubit authCubit = AuthCubit(
        authGateway,
        InMemoryErrorReporter(),
      );
      addTearDown(authCubit.close);
      addTearDown(authGateway.dispose);
      final GoRouter router = createAppRouter(authCubit);
      addTearDown(router.dispose);
      router.go(AppRoutes.forgotPasswordReset);

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

      // Enter a valid new password + matching confirmation so the form
      // validates and the submit reaches the Cubit.
      await tester.enterText(find.byType(TextFormField).first, 'newpassword1');
      await tester.enterText(find.byType(TextFormField).last, 'newpassword1');
      await tester.pump();

      final ElevatedButton submit = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(submit.onPressed, isNotNull);
      submit.onPressed!();
      await tester.pumpAndSettle();

      // Success: the snackbar notice renders AND we land on /sign-in. The
      // ScaffoldMessenger is app-level, so the snackbar survives the route
      // change and is visible on the sign-in screen.
      expect(
        find.text('Your password has been reset. You can sign in now.'),
        findsOneWidget,
      );
      expect(find.text('Welcome Back'), findsOneWidget);
      // The reset screen is gone — navigation happened, not an in-place stay.
      expect(find.text('Reset Password'), findsNothing);
    },
  );
}
