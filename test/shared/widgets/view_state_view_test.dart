import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/view_state_view.dart';

void main() {
  Widget pumpViewState<T>(ViewState<T> state, {VoidCallback? onRetry}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ViewStateView<T>(state: state, onRetry: onRetry),
      ),
    );
  }

  group('ViewStateView', () {
    testWidgets('loading branch renders the spinner and localized label', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpViewState<String>(const ViewLoading<String>()),
      );

      expect(find.text('Loading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('success branch renders the ready label', (tester) async {
      await tester.pumpWidget(
        pumpViewState<String>(const ViewSuccess<String>('data')),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('empty branch renders the empty label', (tester) async {
      await tester.pumpWidget(pumpViewState<String>(const ViewEmpty<String>()));

      expect(find.text('Nothing to show'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('error branch renders the user message and a retry action', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        pumpViewState<String>(
          ViewError<String>(
            const AppError(code: 'load_failed', userMessage: 'Something broke'),
          ),
          onRetry: () => retried = true,
        ),
      );

      // The error surface carries the AppError.userMessage, not a generic
      // label — this is what distinguishes it from the other branches.
      expect(find.text('Something broke'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // The retry affordance is localized and wired to onRetry.
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets(
      'error branch renders no retry affordance when onRetry is null',
      (tester) async {
        await tester.pumpWidget(
          pumpViewState<String>(
            ViewError<String>(
              const AppError(
                code: 'load_failed',
                userMessage: 'Something broke',
              ),
            ),
          ),
        );

        expect(find.text('Something broke'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('offline branch renders the offline label', (tester) async {
      await tester.pumpWidget(
        pumpViewState<String>(const ViewOffline<String>()),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('unauthorized branch renders the access label', (tester) async {
      await tester.pumpWidget(
        pumpViewState<String>(const ViewUnauthorized<String>()),
      );

      expect(find.text('Access not available'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });
}
