import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_request.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// SignUpScreen now builds a redaction-safe SignUpRequest on submit and hands
// it to a SignUpCubit backed by a SignUpGateway seam. On success (Phase 4.2)
// the form is replaced by a "check your inbox" confirmation instead of the
// old snackbar + silent route to sign-in; the user verifies email first and
// taps the explicit action to continue. These tests pin that wiring: the VO
// is constructed with the entered (normalized) values, success renders the
// check-inbox state (no auto-route), the action routes to sign-in, and a
// gateway failure renders the ViewStateView error surface.
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

  // Pump SignUpScreen through the router so context.go(AppRoutes.signIn) is
  // observable as a navigation. The screen resolves SignUpGateway from the
  // service locator, so the locator must be configured before pumping.
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

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Amira Hassan');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'amira@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '+201234567890');
    await tester.enterText(find.byType(TextFormField).at(3), 'strong-pw-1');
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  testWidgets('renders the sign-up title and the four input fields', (
    tester,
  ) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets(
    'disables the create-account button until the terms box is checked',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final ElevatedButton enabled = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(enabled.onPressed, isNotNull);
    },
  );

  testWidgets(
    'does not submit when the form is invalid (empty fields, terms checked)',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pump();

      expect(find.textContaining('Verification code sent'), findsNothing);
      expect(find.text('Create Account'), findsWidgets);
    },
  );

  testWidgets(
    'valid submit builds a SignUpRequest with normalized values and shows '
    'the check-inbox state instead of routing',
    (tester) async {
      // Substitute the dev fake with a capturing gateway so the test can
      // assert the VO the screen constructed, not just the success surface.
      // The capturing gateway implements the real contract interface (no
      // contract mocking per INSTRUCTIONS §5).
      final _CapturingSignUpGateway gateway = _CapturingSignUpGateway();
      await serviceLocator.reset();
      serviceLocator.registerSingleton<SignUpGateway>(gateway);

      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      await fillValidForm(tester);

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pumpAndSettle();

      // The screen built a SignUpRequest from the entered values and handed
      // it to the cubit, which called the gateway. Normalization (trim +
      // lower-case email) is applied by SignUpRequest.fromRaw.
      expect(gateway.received, isNotNull);
      expect(gateway.received!.name, 'Amira Hassan');
      expect(gateway.received!.email, 'amira@example.com');
      expect(gateway.received!.phone, '+201234567890');
      expect(gateway.received!.password, 'strong-pw-1');

      // Success (Phase 4.2): the form is replaced by the check-your-inbox
      // confirmation. No snackbar, no silent route to sign-in — the user
      // must verify email first.
      expect(find.text('Check Your Inbox'), findsOneWidget);
      expect(find.textContaining('verification link'), findsOneWidget);
      expect(find.text('Continue to Sign In'), findsOneWidget);
      expect(find.textContaining('Verification code sent'), findsNothing);
      expect(find.text('Welcome Back'), findsNothing);
      // The form itself is gone.
      expect(find.text('Create Account'), findsNothing);
    },
  );

  testWidgets(
    'tapping Continue to Sign In from the check-inbox state routes to sign-in',
    (tester) async {
      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      await fillValidForm(tester);

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      button.onPressed!();
      await tester.pumpAndSettle();

      // We are still on the sign-up route showing the confirmation.
      expect(find.text('Check Your Inbox'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);

      // The explicit action routes to sign-in.
      await tester.tap(find.text('Continue to Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    },
  );

  testWidgets(
    'renders the ViewStateView error surface when the gateway fails',
    (tester) async {
      // Register a failing gateway implementing the real contract.
      const AppError failure = AppError(
        code: 'sign_up_failed',
        userMessage: 'Sign up failed',
      );
      await serviceLocator.reset();
      serviceLocator.registerSingleton<SignUpGateway>(
        _AlwaysFailsSignUpGateway(failure),
      );

      await tester.pumpWidget(pumpScreen());
      await tester.pumpAndSettle();

      await fillValidForm(tester);

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      button.onPressed!();
      await tester.pumpAndSettle();

      // The error surface from ViewStateView carries the AppError userMessage.
      expect(find.text('Sign up failed'), findsOneWidget);
      // A retry affordance is rendered by ViewStateView on error.
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}

class _CapturingSignUpGateway implements SignUpGateway {
  SignUpRequest? received;

  @override
  Future<Result<void>> submit(SignUpRequest request) async {
    received = request;
    return Result<void>.success(null);
  }
}

class _AlwaysFailsSignUpGateway implements SignUpGateway {
  _AlwaysFailsSignUpGateway(this.error);

  final AppError error;

  @override
  Future<Result<void>> submit(SignUpRequest request) async =>
      Result<void>.failure(error);
}
