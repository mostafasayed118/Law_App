import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/auth/presentation/widgets/auth_buttons.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  Widget pumpButton(Widget button) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: button)),
    );
  }

  group('SocialButton', () {
    testWidgets('renders the label and icon and fires onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        pumpButton(
          SocialButton(
            label: 'Google',
            icon: Icons.g_mobiledata,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Google'), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);

      await tester.tap(find.byType(SocialButton));
      expect(tapped, isTrue);
    });
  });

  group('LoadingElevatedButton', () {
    testWidgets('renders the label and is enabled when not loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpButton(LoadingElevatedButton(onPressed: () {}, label: 'Sign In')),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows a spinner and disables the button while loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpButton(
          LoadingElevatedButton(
            onPressed: () {},
            label: 'Sign In',
            loading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('renders the trailing icon when provided', (tester) async {
      await tester.pumpWidget(
        pumpButton(
          LoadingElevatedButton(
            onPressed: () {},
            label: 'Sign In',
            icon: Icons.arrow_forward,
          ),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });

  group('EditorialDivider', () {
    testWidgets('renders the centered label', (tester) async {
      await tester.pumpWidget(
        pumpButton(const EditorialDivider(label: 'OR CONTINUE WITH')),
      );

      expect(find.text('OR CONTINUE WITH'), findsOneWidget);
    });
  });
}
