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

    testWidgets(
      'unread rows are tappable; read rows stay non-interactive (D-F6 re-scope)',
      (tester) async {
        await pumpFeed(tester);

        // D-F6 re-scope (2026-09-02): unread rows carry the mark-read tap
        // (InkWell, chevron-free via the D-MSG1 opt-out); read rows keep the
        // D-C2 non-interactive shape. The static fake has 3 unread rows
        // (notification-1/2/5) and 2 read rows (notification-3/4).
        expect(find.byType(InkWell), findsNWidgets(3));
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        // No chevron anywhere — the ripple is the affordance, never a
        // navigation chevron (the D-MSG1 opt-out on every row).
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      'tapping an unread row marks it read and reloads the feed (D-F6)',
      (tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await _registerMarkStub();
        await pumpFeed(tester);

        // The first row (notification-1, unread) — tap marks it read.
        await tester.tap(find.text('invoice_status').first);
        await tester.pumpAndSettle();

        expect(_markStub!.markCallIds, <String>['notification-1']);
        // The cubit reloads after the mark: two fetch rounds total.
        expect(_markStub!.fetchCalls, 2);
        // After the reload the row renders read: exactly the two remaining
        // unread rows carry the Semantics label (checked on the widget tree
        // shape/affordance, never color alone).
        final Finder unreadSemantics = find.byWidgetPredicate(
          (Widget w) =>
              w is Semantics &&
              w.properties.label == 'Unread notification. Tap to mark as read.',
        );
        expect(unreadSemantics, findsNWidgets(2));
        semantics.dispose();
      },
    );

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

/// Registers a stub that records mark-read calls (the D-F6 screen pin).
_StubNotificationGateway? _markStub;

Future<void> _registerMarkStub() async {
  await resetServiceLocator();
  // The reloaded feed reflects the server flip deterministically: the
  // second fetch returns the list with notification-1 read (the D-F5 fake
  // mirror contract, staged here).
  final List<Notification> reloaded = FakeNotificationGateway
      .syntheticNotifications
      .map(
        (Notification n) => n.id == 'notification-1'
            ? Notification(
                id: n.id,
                category: n.category,
                type: n.type,
                summary: n.summary,
                serverTimestamp: n.serverTimestamp,
                isRead: true,
              )
            : n,
      )
      .toList(growable: false);
  _markStub = _StubNotificationGateway(<Result<List<Notification>>>[
    Result<List<Notification>>.success(
      FakeNotificationGateway.syntheticNotifications,
    ),
    Result<List<Notification>>.success(
      List<Notification>.unmodifiable(reloaded),
    ),
  ]);
  serviceLocator.registerLazySingleton<NotificationGateway>(() => _markStub!);
}

/// Hand-rolled gateway stub: a queue of results (mirrors the billing screen
/// test's stub — timing-independent immediate resolution).
class _StubNotificationGateway implements NotificationGateway {
  _StubNotificationGateway(this._results);

  final List<Result<List<Notification>>> _results;
  int fetchCalls = 0;
  List<String>? markCallIds;
  Result<int> markResult = const Result<int>.success(1);

  @override
  Future<Result<List<Notification>>> fetchNotifications() async {
    fetchCalls++;
    final Result<List<Notification>> result = _results.length == 1
        ? _results.first
        : _results.removeAt(0);
    return result;
  }

  @override
  Future<Result<int>> markNotificationsRead(List<String> ids) async {
    markCallIds = ids;
    return markResult;
  }
}
