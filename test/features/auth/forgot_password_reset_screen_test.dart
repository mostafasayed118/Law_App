import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
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
}
