import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/notification.dart';
import '../domain/notification_gateway.dart';
import '../domain/notification_prefs_store.dart';
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
        // D-PF2: the store is read once per load; null store → defaults
        // (all enabled — AC-4). Each toggle hides its own category.
        final Set<NotificationCategory> muted = <NotificationCategory>{
          if (!(await _readAppointmentToggle()))
            NotificationCategory.appointment,
          if (!(await _readActivityToggle())) NotificationCategory.activity,
          if (!(await _readSystemToggle())) NotificationCategory.system,
        };
        final List<Notification> visible = muted.isEmpty
            ? list
            : list
                  .where((Notification n) => !muted.contains(n.category))
                  .toList(growable: false);
        emit(
          state.copyWith(
            notifications: visible.isEmpty
                ? const ViewEmpty<List<Notification>>()
                : ViewSuccess<List<Notification>>(visible),
            allMuted: list.isNotEmpty && visible.isEmpty,
          ),
        );
      case Failure<List<Notification>>(error: final AppError error):
        emit(
          state.copyWith(
            notifications: ViewError<List<Notification>>(error),
            allMuted: false,
          ),
        );
    }
  }

  Future<bool> _readAppointmentToggle() async {
    final store = _prefsStore;
    if (store == null) {
      return true;
    }
    return (await store.read())?.appointmentReminders ?? true;
  }

  Future<bool> _readActivityToggle() async {
    final store = _prefsStore;
    if (store == null) {
      return true;
    }
    return (await store.read())?.activityUpdates ?? true;
  }

  Future<bool> _readSystemToggle() async {
    final store = _prefsStore;
    if (store == null) {
      return true;
    }
    return (await store.read())?.systemAlerts ?? true;
  }

  /// Marks one notification read (D-N6 write slice, D-F6): calls the
  /// gateway's mark and **reloads** the feed on success — the honest
  /// refetch re-sorts newest-first and reflects the server's flip (the
  /// count is informational, never surfaced). A failure renders the
  /// ViewError arm (the load-failure posture); no optimistic local flip.
  Future<void> markRead(String id) async {
    if (isClosed || _loading || id.isEmpty) {
      return;
    }
    _loading = true;
    final Result<int> result = await _gateway.markNotificationsRead(<String>[
      id,
    ]);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<int>():
        await load();
      case Failure<int>(error: final AppError error):
        emit(
          state.copyWith(notifications: ViewError<List<Notification>>(error)),
        );
    }
  }
}
