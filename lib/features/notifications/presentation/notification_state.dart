import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/notification.dart';

/// Immutable state of the notification-feed surface (notification-feed
/// slice, D-N1).
///
/// [notifications] holds the org-scoped metadata load lifecycle using the
/// shared [ViewState] vocabulary (loading / success / empty / error+retry) —
/// the smallest surface that satisfies the read-only line (no delivery, no
/// read-flag mutation; D-N2/D-N6).
class NotificationState extends Equatable {
  const NotificationState({
    this.notifications = const ViewLoading<List<Notification>>(),
  });

  final ViewState<List<Notification>> notifications;

  NotificationState copyWith({ViewState<List<Notification>>? notifications}) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  List<Object?> get props => <Object?>[notifications];
}
