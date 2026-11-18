import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/home/presentation/home_screen.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';
import 'package:legalhub/features/notifications/presentation/notification_badge_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart' hide Notification;

/// The unread badge is a derived count, not a second source of truth: it reads
/// the existing org-scoped notification list (no new RPC) and keeps its last
/// known value when that read fails, because a decorative hint must never
/// break Home.
void main() {
  Notification row(String id, bool read) => Notification(
    id: id,
    category: NotificationCategory.system,
    type: 'system_maintenance',
    summary: 'demo',
    serverTimestamp: DateTime.utc(2026, 1, 1),
    isRead: read,
  );

  AuthCubit auth() => AuthCubit(
    FakeAuthGateway(),
    InMemoryErrorReporter(),
    FakeMembershipRepository(),
    FakeOrganizationGateway(),
  );

  Widget pumpHome(NotificationBadgeCubit? badge, Locale locale) {
    final Widget child = MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: auth()),
        if (badge != null)
          BlocProvider<NotificationBadgeCubit>.value(value: badge),
      ],
      child: child,
    );
  }

  group('NotificationBadgeCubit', () {
    test('counts only unread rows', () async {
      final _StubGateway gateway = _StubGateway(<Notification>[
        row('1', false),
        row('2', true),
        row('3', false),
      ]);
      final NotificationBadgeCubit cubit = NotificationBadgeCubit(gateway);
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state, 2);
    });

    test('a failed refresh keeps the last count', () async {
      final _StubGateway gateway = _StubGateway(<Notification>[
        row('1', false),
      ]);
      final NotificationBadgeCubit cubit = NotificationBadgeCubit(gateway);
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state, 1);

      gateway.fail = true;
      await cubit.refresh();
      expect(cubit.state, 1);

      gateway.fail = false;
      gateway.rows = <Notification>[];
      await cubit.refresh();
      expect(cubit.state, 0);

      gateway.fail = true;
      await cubit.refresh();
      expect(cubit.state, 0);
    });

    test('no gateway means no count, not a crash', () async {
      final NotificationBadgeCubit cubit = NotificationBadgeCubit(null);
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state, 0);
    });
  });

  testWidgets('the bell shows a capped, labelled badge in RTL', (tester) async {
    final NotificationBadgeCubit badge = NotificationBadgeCubit(
      _StubGateway(
        List<Notification>.generate(120, (int i) => row('$i', false)),
      ),
    );
    addTearDown(badge.close);
    await badge.refresh();
    expect(badge.state, 120);

    await tester.pumpWidget(pumpHome(badge, const Locale('ar')));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(HomeScreen)),
    );
    expect(find.text('99+'), findsOneWidget);
    // Badge/IconButton semantics may merge with the outer node, so match the
    // localized label as a substring rather than requiring an exact node.
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape(l10n.notificationsUnreadBadge(120))),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a standalone Home renders a plain bell', (tester) async {
    await tester.pumpWidget(pumpHome(null, const Locale('en')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero unread shows no badge', (tester) async {
    final NotificationBadgeCubit badge = NotificationBadgeCubit(
      _StubGateway(<Notification>[]),
    );
    addTearDown(badge.close);
    await badge.refresh();

    await tester.pumpWidget(pumpHome(badge, const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsNothing);
  });
}

class _StubGateway implements NotificationGateway {
  _StubGateway(this.rows) : fail = false;

  List<Notification> rows;
  bool fail;

  @override
  Future<Result<List<Notification>>> fetchNotifications() async => fail
      ? const Result<List<Notification>>.failure(
          AppError(code: 'unavailable', userMessage: 'x'),
        )
      : Result<List<Notification>>.success(rows);

  @override
  Future<Result<int>> markNotificationsRead(List<String> ids) async =>
      Result<int>.success(ids.length);
}
