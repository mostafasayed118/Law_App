import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/view_state_view.dart';

void main() {
  Widget pumpViewState<T>(
    ViewState<T> state, {
    VoidCallback? onRetry,
    String? errorFallback,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ViewStateView<T>(
          state: state,
          onRetry: onRetry,
          errorFallback: errorFallback,
        ),
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

    testWidgets('keyed error renders the localized pilot copy and retry', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        pumpViewState<String>(
          ViewError<String>(
            const AppError(
              code: 'task_read_failed',
              userMessage: 'Unable to load tasks. Please try again.',
              messageKey: AppMessageKey.errUnableToLoadTasksPleaseTryAgain,
            ),
          ),
          onRetry: () => retried = true,
        ),
      );

      expect(
        find.text('Unable to load tasks. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // The retry affordance is localized and wired to onRetry.
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('unkeyed error renders the generic localized copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpViewState<String>(
          ViewError<String>(
            const AppError(code: 'load_failed', userMessage: 'Something broke'),
          ),
        ),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Something broke'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('unkeyed error renders the caller-provided fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpViewState<String>(
          const ViewError<String>(
            AppError(code: 'x', userMessage: 'raw producer text'),
          ),
          errorFallback: 'Localized screen copy',
        ),
      );

      expect(find.text('Localized screen copy'), findsOneWidget);
      expect(find.text('raw producer text'), findsNothing);
    });

    testWidgets('keyed error renders localized copy in Arabic', (tester) async {
      await tester.pumpWidget(
        pumpViewState<String>(
          const ViewError<String>(
            AppError(
              code: 'task_read_failed',
              userMessage: 'Unable to load tasks. Please try again.',
              messageKey: AppMessageKey.errUnableToLoadTasksPleaseTryAgain,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );

      expect(
        find.text('تعذر تحميل المهام. يرجى المحاولة مرة أخرى.'),
        findsOneWidget,
      );
    });

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
