import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/notification.dart';
import '../domain/notification_gateway.dart';
import 'notification_state.dart';

/// Owns the notification-feed list surface (notification-feed slice, D-N1).
///
/// [load] fetches the org-scoped metadata list on screen open (the screen
/// wires it after first frame, matching the roster/discovery/billing
/// pattern). Read-only — nothing but the D-N3 metadata surface ever crosses
/// the [NotificationGateway] boundary (D-N2: no push/delivery; D-N6: no
/// read-flag write). Widgets render [NotificationState] and dispatch
/// intents; they never call the gateway directly.
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit(this._gateway) : super(const NotificationState());

  final NotificationGateway _gateway;

  /// In-flight guard. The initial state IS loading (like [BillingCubit.load]'s
  /// contract), so the flag — not a state check — distinguishes "loading in
  /// flight" from "not loaded yet"; duplicate calls while a load is in
  /// flight are ignored.
  bool _loading = false;

  /// Loads the org-scoped metadata list. The initial state is already
  /// loading, so the first open never re-emits a redundant loading frame; a
  /// retry after an error re-enters loading. An empty list maps to
  /// [ViewEmpty]; a failure to [ViewError].
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.notifications is! ViewLoading<List<Notification>>) {
      emit(
        state.copyWith(notifications: const ViewLoading<List<Notification>>()),
      );
    }
    final Result<List<Notification>> result = await _gateway
        .fetchNotifications();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<Notification>>(value: final List<Notification> list):
        emit(
          state.copyWith(
            notifications: list.isEmpty
                ? const ViewEmpty<List<Notification>>()
                : ViewSuccess<List<Notification>>(list),
          ),
        );
      case Failure<List<Notification>>(error: final AppError error):
        emit(
          state.copyWith(notifications: ViewError<List<Notification>>(error)),
        );
    }
  }
}
