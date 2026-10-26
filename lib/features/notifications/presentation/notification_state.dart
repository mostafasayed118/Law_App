import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';

/// Sentinel so [NotificationState.copyWith] can distinguish "leave
/// [actionError] unchanged" from "clear it".
const Object _unsetActionError = Object();

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
    this.actionError,
  });

  final ViewState<List<Notification>> notifications;

  /// Rows existed but every category toggle hid them (D-PF3).
  final bool allMuted;

  /// The last mark-read failure, surfaced as an inline banner while the
  /// loaded [notifications] list stays on screen. Cleared by the next
  /// mark-read or load.
  final AppError? actionError;

  NotificationState copyWith({
    ViewState<List<Notification>>? notifications,
    bool? allMuted,
    Object? actionError = _unsetActionError,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      allMuted: allMuted ?? this.allMuted,
      actionError: identical(actionError, _unsetActionError)
          ? this.actionError
          : actionError as AppError?,
    );
  }

  @override
  List<Object?> get props => <Object?>[notifications, allMuted, actionError];
}
