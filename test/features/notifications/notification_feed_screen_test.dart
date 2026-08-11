import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/notifications/data/fake_notification_gateway.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';
import 'package:legalhub/features/notifications/presentation/notification_feed_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpFeed(WidgetTester tester) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationFeedScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

  group('notification feed screen (notification-feed slice D-N1)', () {
    testWidgets('lists the synthetic metadata from the fake, newest-first', (
      tester,
    ) async {
      await pumpFeed(tester);

      expect(find.text('Notification feed'), findsOneWidget);
      for (final Notification notification
          in FakeNotificationGateway.syntheticNotifications) {
        expect(find.text(notification.type), findsOneWidget);
        expect(find.text(notification.summary), findsOneWidget);
      }
      // Category chips render the localized D-N4 labels.
      expect(find.text('System'), findsNWidgets(2));
      expect(find.text('Activity'), findsNWidgets(2));
      expect(find.text('Appointment'), findsOneWidget);
      // The newest row renders first.
      final List<Notification> rows =
          FakeNotificationGateway.syntheticNotifications;
      expect(find.text(rows.first.type), findsOneWidget);
    });

    testWidgets('renders read-only metadata — no tap affordance, no actions', (
      tester,
    ) async {
      await pumpFeed(tester);

      // D-C2 read-only rows: no InkWell, no chevron, no button — the rows
      // must not read as tappable (D-N2/D-N6: no delivery, no read-flag
      // mutation).
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('renders the local-only demo note (D-N7)', (tester) async {
      await pumpFeed(tester);

      expect(
        find.text(
          'Demo mode — synthetic notification metadata only. No push or '
          'delivery is shown.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty list renders the localized empty state', (tester) async {
      await _registerStub(<Result<List<Notification>>>[
        Result<List<Notification>>.success(const <Notification>[]),
      ]);
      await pumpFeed(tester);

      expect(find.text('No notifications are available.'), findsOneWidget);
      expect(find.text('invoice_status'), findsNothing);
    });

    testWidgets('failure renders the error state with a working retry', (
      tester,
    ) async {
      await _registerStub(<Result<List<Notification>>>[
        Result<List<Notification>>.failure(_loadFailure),
        Result<List<Notification>>.success(
          FakeNotificationGateway.syntheticNotifications,
        ),
      ]);
      await pumpFeed(tester);

      expect(find.text('Unable to load notifications.'), findsOneWidget);
      expect(find.text('invoice_status'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load notifications.'), findsNothing);
      expect(find.text('invoice_status'), findsOneWidget);
    });

    testWidgets('rows render the server timestamp via the shared date helper', (
      tester,
    ) async {
      await pumpFeed(tester);

      final Notification newest =
          FakeNotificationGateway.syntheticNotifications.first;
      expect(find.text(dateLabel(newest.serverTimestamp)), findsWidgets);
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'notifications_failed',
  userMessage: 'Could not load notifications',
);

/// Registers a stub notification gateway in the locator so the screen
/// resolves the queued results instead of the dev fake.
Future<void> _registerStub(List<Result<List<Notification>>> results) async {
  await resetServiceLocator();
  serviceLocator.registerLazySingleton<NotificationGateway>(
    () => _StubNotificationGateway(results),
  );
}

/// Hand-rolled gateway stub: a queue of results (mirrors the billing screen
/// test's stub — timing-independent immediate resolution).
class _StubNotificationGateway implements NotificationGateway {
  _StubNotificationGateway(this._results);

  final List<Result<List<Notification>>> _results;

  @override
  Future<Result<List<Notification>>> fetchNotifications() async {
    return _results.length == 1 ? _results.first : _results.removeAt(0);
  }
}
