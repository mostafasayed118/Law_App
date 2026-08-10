import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/widgets/app_centered_retry.dart';

// AppCenteredRetry is the E9 extraction: the attorney-profile and
// matter-details error arms (previously duplicated Center → Column → error
// text + retry button) now delegate here. These tests pin the shared
// contract — message render with the error color, the retry callback, the
// localized retry label, and the centered layout.
void main() {
  Widget pumpCenteredRetry({
    String message = 'Could not load',
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
  }) {
    return MaterialApp(
      theme: LegalHubTheme.light,
      home: Scaffold(
        body: AppCenteredRetry(
          message: message,
          onRetry: onRetry ?? () {},
          retryLabel: retryLabel,
        ),
      ),
    );
  }

  testWidgets('renders the message in the error color with the retry label', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpCenteredRetry(message: 'Matter failed to load', retryLabel: 'Retry'),
    );

    final Text message = tester.widget<Text>(
      find.text('Matter failed to load'),
    );
    expect(message.textAlign, TextAlign.center);
    expect(message.style?.color, LegalHubTheme.light.colorScheme.error);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('fires onRetry when the retry button is tapped', (tester) async {
    int retries = 0;
    await tester.pumpWidget(pumpCenteredRetry(onRetry: () => retries++));

    await tester.tap(find.byType(TextButton));
    expect(retries, 1);
  });

  testWidgets('centers the column in the available space', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 600)),
        child: pumpCenteredRetry(),
      ),
    );

    expect(find.byType(Center), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders under RTL at 320px without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LegalHubTheme.light,
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 320,
              child: AppCenteredRetry(
                message: 'تعذّر تحميل البيانات',
                onRetry: () {},
                retryLabel: 'إعادة المحاولة',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppCenteredRetry), findsOneWidget);
  });
}
