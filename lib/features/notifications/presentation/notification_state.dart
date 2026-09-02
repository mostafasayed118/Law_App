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
///
/// **D-N5 prefs filtering (D-PF3):** [allMuted] is true only when the
/// fetch returned rows but **every** row was hidden by the device-local
/// category toggles — the screen renders the distinct muted note in that
/// case, never the plain "No notifications" copy (which would be false).
/// A genuinely empty fetch keeps [allMuted] false.
class NotificationState extends Equatable {
  const NotificationState({
    this.notifications = const ViewLoading<List<Notification>>(),
    this.allMuted = false,
  });

  final ViewState<List<Notification>> notifications;

  /// Rows existed but every category toggle hid them (D-PF3).
  final bool allMuted;

  NotificationState copyWith({
    ViewState<List<Notification>>? notifications,
    bool? allMuted,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      allMuted: allMuted ?? this.allMuted,
    );
  }

  @override
  List<Object?> get props => <Object?>[notifications, allMuted];
}
