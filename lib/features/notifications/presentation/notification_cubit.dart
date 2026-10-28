import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs_store.dart';
import 'package:legalhub/features/notifications/domain/visible_notifications.dart';
import 'notification_state.dart';

/// Owns the notification-feed list surface (notification-feed slice, D-N1).
///
/// [load] fetches the org-scoped metadata list on screen open (the screen
/// wires it after first frame, matching the roster/discovery/billing
/// pattern). The **D-N5 prefs filter (D-PF1)** hides rows whose category is
/// disabled in the device-local `NotificationPrefs` — a presentation-only
/// concern resolved through the registered store at each load (D-PF2);
/// the server read path is untouched. The **D-N6 write** (`markRead`) is
/// the surface's single mutation. Widgets render [NotificationState] and
/// dispatch intents; they never call the gateway or the store directly.
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit(this._gateway, [this._prefsStore])
    : super(const NotificationState());

  final NotificationGateway _gateway;

  /// The device-local prefs store (D-N5/D-PF2) — read-only here; null keeps
  /// the defaults (all categories enabled), which pins AC-4.
  final NotificationPrefsStore? _prefsStore;

  /// The visibility rule (D-N5/D-PF2/D-PF3) as a domain use case —
  /// the first consumer of the `core/use_cases` layer (§4.1).
  late final LoadVisibleNotifications _visibleNotifications =
      LoadVisibleNotifications(_prefsStore);

  /// In-flight guard. The initial state IS loading (like [BillingCubit.load]'s
  /// contract), so the flag — not a state check — distinguishes "loading in
  /// flight" from "not loaded yet"; duplicate calls while a load is in
  /// flight are ignored.
  bool _loading = false;

  /// Loads the org-scoped metadata list. The initial state is already
  /// loading, so the first open never re-emits a redundant loading frame; a
  /// retry after an error re-enters loading. An empty list maps to
  /// [ViewEmpty]; a failure to [ViewError]. The **D-N5 filter (D-PF1)**
  /// hides rows whose category the device-local toggles disabled; when rows
  /// existed but every row was hidden, [NotificationState.allMuted] is set
  /// so the screen renders the honest muted note (D-PF3).
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.notifications is! ViewLoading<List<Notification>> ||
        state.actionError != null) {
      emit(
        state.copyWith(
          notifications: const ViewLoading<List<Notification>>(),
          actionError: null,
        ),
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
        // D-N5/D-PF2/D-PF3: the visibility rule lives in the use case — one
        // store read per load (the inlined version read it once per toggle
        // while claiming a single read) and the allMuted distinction owned
        // there rather than reconstructed here.
        //
        // This is a SECOND await: the store read may still be pending when
        // the cubit closes, and emitting afterwards throws
        // `StateError: Cannot emit new states after calling close`
        // (audit 2026-10-27, F12). Re-check `isClosed` on the resolved local.
        final Result<NotificationVisibility> visibilityResult =
            await _visibleNotifications(list);
        if (isClosed) {
          return;
        }
        switch (visibilityResult) {
          case Success<NotificationVisibility>(
            value: final NotificationVisibility visibility,
          ):
            emit(
              state.copyWith(
                notifications: visibility.visible.isEmpty
                    ? const ViewEmpty<List<Notification>>()
                    : ViewSuccess<List<Notification>>(visibility.visible),
                allMuted: visibility.allMuted,
              ),
            );
          case Failure<NotificationVisibility>(error: final AppError error):
            emit(
              state.copyWith(
                notifications: viewStateForFailure<List<Notification>>(error),
                allMuted: false,
              ),
            );
        }
      case Failure<List<Notification>>(error: final AppError error):
        emit(
          state.copyWith(
            notifications: viewStateForFailure<List<Notification>>(error),
            allMuted: false,
          ),
        );
    }
  }

  /// Marks one notification read (D-N6 write slice, D-F6): on success
  /// applies an **optimistic local flip** — the row's `isRead` flips in
  /// place and the unread affordance reflects it immediately, with NO full
  /// feed reload (audit: the reload re-fetched the whole capped list for a
  /// single-flag change). List order is untouched (the server flip carries
  /// no reorder signal). A failure leaves the loaded list on screen and sets
  /// [NotificationState.actionError] instead of replacing it with an error
  /// arm; the next mark-read or load clears it.
  Future<void> markRead(String id) async {
    if (isClosed || _loading || id.isEmpty) {
      return;
    }
    _loading = true;
    if (state.actionError != null) {
      emit(state.copyWith(actionError: null));
    }
    final Result<int> result = await _gateway.markNotificationsRead(<String>[
      id,
    ]);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<int>():
        _flipReadLocal(id);
      case Failure<int>(error: final AppError error):
        emit(state.copyWith(actionError: error));
    }
  }

  /// Flips one row's `isRead` in place on the current success state. A
  /// no-op when the feed is not in success (nothing to flip) or the id is
  /// absent (the server flipped a row outside the visible page — the next
  /// load picks it up).
  void _flipReadLocal(String id) {
    final ViewState<List<Notification>> current = state.notifications;
    if (current is! ViewSuccess<List<Notification>>) {
      return;
    }
    bool changed = false;
    final List<Notification> flipped = current.data
        .map((Notification notification) {
          if (notification.id == id && !notification.isRead) {
            changed = true;
            return Notification(
              id: notification.id,
              category: notification.category,
              type: notification.type,
              summary: notification.summary,
              serverTimestamp: notification.serverTimestamp,
              isRead: true,
            );
          }
          return notification;
        })
        .toList(growable: false);
    if (changed) {
      emit(
        state.copyWith(notifications: ViewSuccess<List<Notification>>(flipped)),
      );
    }
  }
}
