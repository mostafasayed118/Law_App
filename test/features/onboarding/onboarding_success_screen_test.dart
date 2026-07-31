import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/onboarding/presentation/onboarding_success_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// Direct render contract for OnboardingSuccessScreen. The routing contract
// ("Continue to Sign In" navigating to /sign-in) is pinned in
// onboarding_screen_test.dart's 'onboarding success screen' group, which
// drives the screen through the real router; this file covers the isolated
// surface so the screen has its own home.
void main() {
  Widget pumpScreen() {
    return const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OnboardingSuccessScreen(),
    );
  }

  testWidgets('renders the success title, body, and CTA label', (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.text("You're All Set"), findsOneWidget);
    expect(
      find.text('Your secure legal workstation is ready. Sign in to begin.'),
      findsOneWidget,
    );
    expect(find.text('Continue to Sign In'), findsOneWidget);
  });

  testWidgets('renders the check hero badge', (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('renders an enabled CTA affordance', (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    final ElevatedButton cta = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue to Sign In'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(cta.onPressed, isNotNull);
  });
}
