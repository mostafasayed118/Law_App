import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/app_centered_message.dart';

// AppCenteredMessage is the Candidate-A extraction: the attorney-profile
// and matter-details _message helpers (previously duplicated the centered,
// spaceLg-padded, onSurfaceVariant plain-message shape) now delegate here.
// These tests pin the shared contract — center + padding + centered
// secondary text, and RTL at narrow width.
void main() {
  Widget pumpCenteredMessage({String text = 'Not found'}) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      home: Scaffold(body: AppCenteredMessage(text: text)),
    );
  }

  testWidgets('renders the message centered with secondary color', (
    tester,
  ) async {
    await tester.pumpWidget(pumpCenteredMessage(text: 'Profile not found'));

    final Text text = tester.widget<Text>(find.text('Profile not found'));
    expect(text.textAlign, TextAlign.center);
    expect(text.style?.color, LegalHubTheme.light.colorScheme.onSurfaceVariant);
    expect(find.byType(Center), findsOneWidget);
  });

  testWidgets('wraps in spaceLg padding', (tester) async {
    await tester.pumpWidget(pumpCenteredMessage());

    final Padding padding = tester.widget<Padding>(
      find.descendant(of: find.byType(Center), matching: find.byType(Padding)),
    );
    expect(
      padding.padding,
      const EdgeInsetsDirectional.all(LegalHubTheme.spaceLg),
    );
  });

  testWidgets('no overflow at 320px under RTL with long Arabic copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LegalHubTheme.light,
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 320,
              child: AppCenteredMessage(
                text: 'لم يتم العثور على هذا الملف الشخصي في القائمة المحلية',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppCenteredMessage), findsOneWidget);
  });
}
