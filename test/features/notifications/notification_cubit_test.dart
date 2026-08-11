import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';
import 'package:legalhub/features/notifications/presentation/notification_cubit.dart';
import 'package:legalhub/features/notifications/presentation/notification_state.dart';

void main() {
  late _StubNotificationGateway gateway;

  setUp(() {
    gateway = _StubNotificationGateway();
  });

  group('NotificationCubit (notification-feed slice D-N1)', () {
    test('starts loading with no rows', () {
      final NotificationCubit cubit = NotificationCubit(gateway);
      addTearDown(cubit.close);

      expect(
        cubit.state.notifications,
        const ViewLoading<List<Notification>>(),
      );
    });

    blocTest<NotificationCubit, NotificationState>(
      'load resolves to the notification-metadata list',
      build: () => NotificationCubit(gateway),
      act: (NotificationCubit cubit) => cubit.load(),
      expect: () => <NotificationState>[
        NotificationState(
          notifications: ViewSuccess<List<Notification>>(_notifications),
        ),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<NotificationCubit, NotificationState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubNotificationGateway(
        results: <Result<List<Notification>>>[
          Result<List<Notification>>.success(const <Notification>[]),
        ],
      ),
      build: () => NotificationCubit(gateway),
      act: (NotificationCubit cubit) => cubit.load(),
      expect: () => <NotificationState>[
        const NotificationState(notifications: ViewEmpty<List<Notification>>()),
      ],
    );

    blocTest<NotificationCubit, NotificationState>(
      'load maps a failure to ViewError',
      setUp: () => gateway = _StubNotificationGateway(
        results: <Result<List<Notification>>>[
          Result<List<Notification>>.failure(_loadFailure),
        ],
      ),
      build: () => NotificationCubit(gateway),
      act: (NotificationCubit cubit) => cubit.load(),
      expect: () => <NotificationState>[
        NotificationState(
          notifications: ViewError<List<Notification>>(_loadFailure),
        ),
      ],
    );

    blocTest<NotificationCubit, NotificationState>(
      'retry after an error re-enters loading and resolves',
      setUp: () => gateway = _StubNotificationGateway(
        results: <Result<List<Notification>>>[
          Result<List<Notification>>.failure(_loadFailure),
          Result<List<Notification>>.success(_notifications),
        ],
      ),
      build: () => NotificationCubit(gateway),
      act: (NotificationCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <NotificationState>[
        NotificationState(
          notifications: ViewError<List<Notification>>(_loadFailure),
        ),
        const NotificationState(
          notifications: ViewLoading<List<Notification>>(),
        ),
        NotificationState(
          notifications: ViewSuccess<List<Notification>>(_notifications),
        ),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );
  });
}

final AppError _loadFailure = AppError(
  code: 'notifications_failed',
  userMessage: 'Could not load notifications',
);

final List<Notification> _notifications = <Notification>[
  Notification(
    id: 'n1',
    category: NotificationCategory.system,
    type: 'invoice_status',
    summary: 'Demo notification — invoice issued',
    serverTimestamp: DateTime.utc(2026, 7, 20, 9, 30),
    isRead: false,
  ),
  Notification(
    id: 'n2',
    category: NotificationCategory.activity,
    type: 'matter_updated',
    summary: 'Demo notification — matter status update',
    serverTimestamp: DateTime.utc(2026, 7, 18, 14, 5),
    isRead: false,
  ),
];

/// Hand-rolled gateway stub: a queue of results (mirrors the billing cubit
/// test's stub — timing-independent immediate resolution).
class _StubNotificationGateway implements NotificationGateway {
  _StubNotificationGateway({List<Result<List<Notification>>>? results})
    : _queue = results == null
          ? <Result<List<Notification>>>[
              Result<List<Notification>>.success(_notifications),
            ]
          : List<Result<List<Notification>>>.of(results);

  final List<Result<List<Notification>>> _queue;
  int fetchCalls = 0;

  @override
  Future<Result<List<Notification>>> fetchNotifications() async {
    fetchCalls++;
    return _queue.length == 1 ? _queue.first : _queue.removeAt(0);
  }
}
