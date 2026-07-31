import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/auth/presentation/sign_in_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late AuthCubit authCubit;

  setUp(() {
    authCubit = AuthCubit(
      _FailingAuthGateway(
        const AuthFailure(
          kind: AuthFailureKind.providerUnavailable,
          message: 'The demo session is unavailable.',
        ),
      ),
      InMemoryErrorReporter(),
    );
  });

  tearDown(() async {
    await authCubit.close();
  });

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

  testWidgets('shows a snackbar when the demo session fails', (tester) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    // Enter a valid form so validation passes and startDemoSession runs.
    await tester.enterText(find.byType(TextField).first, 'amira@example.com');
    await tester.enterText(find.byType(TextField).last, 'any-password');

    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).last,
    );
    expect(button.onPressed, isNotNull);
    button.onPressed!();

    // The failing gateway emits AuthStatus.error; the BlocListener must show
    // the localized snackbar notice. Allow the async failure to resolve.
    await tester.pumpAndSettle();

    expect(authCubit.state.status, AuthStatus.error);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Unable to start the demo session.'), findsOneWidget);
  });
}

class _FailingAuthGateway implements AuthGateway {
  _FailingAuthGateway(this.failure);

  final AuthFailure failure;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  Future<AuthOutcome<Session>> restore() async =>
      AuthOutcome<Session>.failure(failure);

  @override
  Future<AuthOutcome<Session>> startDemoSession() async =>
      AuthOutcome<Session>.failure(failure);

  @override
  Future<void> signOut() async {}
}
