import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_request.dart';
import 'package:legalhub/features/auth/presentation/forgot_password/forgot_password_reset_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  // The reset screen resolves PasswordRecoveryGateway from the service
  // locator when it builds its Cubit. Each test registers the gateway it needs
  // (a failing one for the error-render path) and resets the locator after.
  setUp(() async {
    await resetServiceLocator();
  });

  tearDown(() async {
    await resetServiceLocator();
  });

  Widget pumpScreen() {
    return const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ForgotPasswordResetScreen(),
    );
  }

  testWidgets(
    'renders the ViewStateView error surface when the recovery gateway fails',
    (tester) async {
      // Register a gateway that always fails so the Cubit transitions to
      // ViewError and the shared ViewStateView renders the error affordance.
      serviceLocator.registerSingleton<PasswordRecoveryGateway>(
        _FailingRecoveryGateway(),
      );

      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      // Enter a valid new password and matching confirmation so the form
      // validates and the submit reaches the Cubit.
      await tester.enterText(find.byType(TextFormField).first, 'newpassword1');
      await tester.enterText(find.byType(TextFormField).last, 'newpassword1');
      await tester.pump();

      // Submit. Invoke the ElevatedButton directly to avoid hit-test
      // fragility in the scrollable auth form.
      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pumpAndSettle();

      // ViewStateView renders the AppError.userMessage as the error label.
      // The failing gateway's user message is the destination proof.
      expect(find.text('Recovery failed'), findsOneWidget);
      // The shared retry affordance (localized "Retry") confirms ViewStateView
      // is the renderer, not a hand-rolled error widget.
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}

class _FailingRecoveryGateway implements PasswordRecoveryGateway {
  @override
  Future<Result<void>> reset(PasswordRecoveryRequest request) async {
    return Result<void>.failure(
      const AppError(code: 'recovery_failed', userMessage: 'Recovery failed'),
    );
  }
}
