import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/auth/presentation/sign_in_screen.dart';
import 'package:legalhub/features/auth/presentation/widgets/social_button.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;

  setUp(() {
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    // The forgot-password link test navigates to the recovery email screen,
    // which builds a PasswordRecoveryCubit from the DI-registered dev fake
    // (P3.1). configureDependencies() is idempotent and registers the fake.
    configureDependencies();
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  // The sign-in screen pumps SignInScreen directly (no router) for the
  // isolated widget interactions, since the SignInScreen only needs the
  // AuthCubit provider above it.
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

  testWidgets('renders the welcome copy and brand-remediated label', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    // D-01 remediation: the old "Lexis" wordmark must not appear.
    expect(find.textContaining('Lexis'), findsNothing);
    expect(find.textContaining('LegalHub'), findsWidgets);
  });

  testWidgets('form validation blocks submit with empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    // Invoke the primary submit callback directly. The form is empty, so
    // validation fails and startDemoSession must NOT be called.
    final Finder buttonFinder = find.byType(ElevatedButton).last;
    final ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pump();

    // No demo session started; still unauthenticated.
    expect(authCubit.state.status, AuthStatus.unauthenticated);
  });

  testWidgets('the demo shortcut starts the session without credentials '
      '(startDemoSession path)', (tester) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    // The shortcut is the OutlinedButton rendered above the Sign In
    // button; it calls startDemoSession directly — no form validation,
    // no credentials (the live-device walk found the form gates empty
    // submits, so this is the credential-free demo path).
    expect(find.text('Continue with demo session'), findsOneWidget);
    expect(find.text('Development-only demo session'), findsOneWidget);
    final Finder demoFinder = find.widgetWithText(
      OutlinedButton,
      'Continue with demo session',
    );
    await tester.tap(demoFinder);
    await tester.pumpAndSettle();

    expect(authCubit.state.isAuthenticated, isTrue);
    expect(authCubit.state.session?.userId, 'demo-user');
  });

  testWidgets('hides the demo shortcut when the seam cannot mint one '
      '(audit 2026-09-21, H-5)', (tester) async {
    // A configured provider's startDemoSession always denies, so the seam
    // reports the unsupported posture and the screen must not render a
    // primary-looking demo button that can only ever fail.
    final FakeAuthGateway unsupportedGateway = FakeAuthGateway(
      supportsDemoSession: false,
    );
    final AuthCubit unsupportedCubit = AuthCubit(
      unsupportedGateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    addTearDown(() async {
      await unsupportedCubit.close();
      await unsupportedGateway.dispose();
    });

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: unsupportedCubit,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.science_outlined), findsNothing);
    expect(find.text('Continue with demo session'), findsNothing);
    expect(find.text('Development-only demo session'), findsNothing);
    // The real sign-in form is unaffected.
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('valid form submit starts the demo session via the cubit', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'amira@example.com');
    await tester.enterText(find.byType(TextField).last, 'any-password');

    // Invoke the submit callback directly to avoid hit-test fragility in the
    // scrollable auth form; the goal is to verify the validated form routes
    // through to AuthCubit.signIn (which the dev fake resolves to the demo
    // session).
    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).last,
    );
    button.onPressed!();
    await tester.pumpAndSettle();

    expect(authCubit.state.isAuthenticated, isTrue);
    expect(authCubit.state.session?.userId, 'demo-user');
  });

  // Audit U-2: the compact "Forgot Password?" trailing action used
  // `minimumSize: Size.zero` + `tapTargetSize: shrinkWrap`, leaving a ~19px
  // tall hit area — far below the 48x48 minimum.
  testWidgets('the forgot-password action has a 48px tap target (U-2)', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    final Finder link = find.ancestor(
      of: find.text('Forgot Password?'),
      matching: find.byType(TextButton),
    );
    final Size size = tester.getSize(link);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('forgot-password link routes to the forgot-password screen', (
    tester,
  ) async {
    final router = createAppRouter(authCubit);
    addTearDown(router.dispose);

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

    // The "Forgot Password?" trailing TextButton. Invoke its onPressed
    // directly to avoid hit-test fragility in the scrollable auth form.
    final Finder linkFinder = find.text('Forgot Password?');
    expect(linkFinder, findsOneWidget);
    final TextButton link = tester.widget<TextButton>(
      find.ancestor(of: linkFinder, matching: find.byType(TextButton)),
    );
    expect(link.onPressed, isNotNull);
    link.onPressed!();
    await tester.pumpAndSettle();

    // Navigation landed on the forgot-password email step, whose title is
    // "Recover Password" and which shows the lock-reset hero badge.
    expect(find.text('Recover Password'), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset_outlined), findsOneWidget);
  });

  // E2E BUG-2 regression (2026-09-24): both social buttons were wired
  // `onTap: () => context.go(AppRoutes.signUp)`, so tapping "Continue with
  // Google/Apple" silently opened the Create Account form. A provider button
  // may only ever start its own provider flow or be disabled.
  testWidgets('Google starts its provider flow; Apple stays disabled', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    final List<SocialButton> socials = tester
        .widgetList<SocialButton>(find.byType(SocialButton))
        .toList();
    expect(socials, isNotEmpty, reason: 'both social buttons should render');

    final SocialButton google = socials.firstWhere(
      (SocialButton button) => button.icon == Icons.g_mobiledata_outlined,
    );
    final SocialButton apple = socials.firstWhere(
      (SocialButton button) => button.icon == Icons.apple,
    );
    expect(
      google.onTap,
      isNotNull,
      reason: 'Google is wired to the OAuth browser hand-off.',
    );
    expect(
      apple.onTap,
      isNull,
      reason:
          'Apple has no provider wired, so it must be disabled — it must '
          'never navigate to the sign-up form (E2E BUG-2).',
    );

    // The honest disclosure explains the still-disabled Apple button.
    expect(
      find.text(
        'Apple sign-in is not available yet. Use Google, email, or the demo '
        'session.',
      ),
      findsOneWidget,
    );
  });

  // The dev fake has no browser flow: it reports "not launched", so the
  // surface must show the sign-in error instead of pretending consent opened.
  testWidgets('a failed Google launch surfaces the sign-in error', (
    tester,
  ) async {
    await tester.pumpWidget(pumpIsolated());
    await tester.pumpAndSettle();

    final SocialButton google = tester
        .widgetList<SocialButton>(find.byType(SocialButton))
        .firstWhere(
          (SocialButton button) => button.icon == Icons.g_mobiledata_outlined,
        );
    google.onTap!();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to sign in. Please check your credentials and try again.',
      ),
      findsOneWidget,
    );
  });
}
