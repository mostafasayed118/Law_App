import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/result.dart';

import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';

/// Unread count for the Home bell badge (ADR-0011).
///
/// The application already fetches the org-scoped notification list through
/// [NotificationGateway.fetchNotifications]; deriving the count from that list
/// is cheap and needs no new RPC. The cubit is provided once above the router,
/// so the badge and the feed share one source of truth: after a mark-read the
/// feed calls [refresh] and the Home badge updates on the next rebuild.
///
/// A failed count is deliberately NOT surfaced as an error — the badge is a
/// navigation hint, not a security boundary, and a flaky read must not break
/// the Home screen. The previous count is kept.
class NotificationBadgeCubit extends Cubit<int> {
  NotificationBadgeCubit(this._gateway) : super(0);

  /// Null when no gateway is registered (e.g. a widget test that pumps Home
  /// without the composition root): the badge stays hidden rather than
  /// crashing the whole app for a decorative hint.
  final NotificationGateway? _gateway;

  Future<void> refresh() async {
    final NotificationGateway? gateway = _gateway;
    if (isClosed || gateway == null) {
      return;
    }
    final result = await gateway.fetchNotifications();
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Notification>>(value: final List<Notification> rows):
        final int count = rows.where((Notification row) => !row.isRead).length;
        if (!isClosed && count != state) {
          emit(count);
        }
      case Failure<List<Notification>>():
        // Keep the last known count; a badge is a hint, never an error state.
        break;
    }
  }
}
