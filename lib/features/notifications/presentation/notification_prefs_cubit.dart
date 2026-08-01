import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notification_prefs.dart';
import '../domain/notification_prefs_store.dart';

class NotificationPrefsState extends Equatable {
  const NotificationPrefsState(this.prefs);

  final NotificationPrefs prefs;

  @override
  List<Object?> get props => <Object?>[prefs];
}

/// Holds the device-local notification preferences.
///
/// Mirrors `LocaleCubit`: [load] reads the persisted value once (defaults
/// until then), and each setter writes through the store before emitting, so
/// the screen never shows a preference that was not persisted. There is no
/// error state at this scope — a write failure surfaces as an unhandled
/// async error, exactly like the locale store path (residual risk, noted in
/// the slice walkthrough).
///
/// The cubit is intentionally screen-scoped (created per screen, never
/// registered in the service locator): no widget outside the settings
/// surface observes these preferences yet, so an app-scoped instance would
/// be speculative. The store, by contrast, is a lazy singleton — the v1
/// delivery layer will read preferences app-wide.
class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit(this._store)
    : super(const NotificationPrefsState(NotificationPrefs.defaults()));

  final NotificationPrefsStore _store;

  Future<void> load() async {
    final NotificationPrefs? saved = await _store.read();
    if (saved != null && !isClosed) {
      emit(NotificationPrefsState(saved));
    }
  }

  Future<void> setAppointmentReminders(bool enabled) async {
    await _persist(state.prefs.copyWith(appointmentReminders: enabled));
  }

  Future<void> setActivityUpdates(bool enabled) async {
    await _persist(state.prefs.copyWith(activityUpdates: enabled));
  }

  Future<void> setSystemAlerts(bool enabled) async {
    await _persist(state.prefs.copyWith(systemAlerts: enabled));
  }

  Future<void> _persist(NotificationPrefs prefs) async {
    await _store.write(prefs);
    if (!isClosed) {
      emit(NotificationPrefsState(prefs));
    }
  }
}
