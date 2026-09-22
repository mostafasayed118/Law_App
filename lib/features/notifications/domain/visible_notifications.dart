import 'package:equatable/equatable.dart';

import '../../../core/errors/result.dart';
import '../../../core/use_cases/use_case.dart';
import 'notification.dart';
import 'notification_prefs.dart';
import 'notification_prefs_store.dart';

/// What the feed should render: the rows the category toggles leave visible,
/// and whether those toggles hid **every** row.
///
/// The second field is the honest-empty distinction (D-PF3): rows existed but
/// every category was muted is a different fact from "there are no
/// notifications", and it must read differently.
class NotificationVisibility extends Equatable {
  const NotificationVisibility({required this.visible, required this.allMuted});

  final List<Notification> visible;
  final bool allMuted;

  @override
  List<Object?> get props => <Object?>[visible, allMuted];
}

/// The feed's visibility decision (D-N5 / D-PF2 / D-PF3) as a focused domain
/// operation — and the first consumer of the `core/use_cases` layer that
/// `INSTRUCTIONS.md` §4.1 declares (owner decision OI-D5.1, 2026-09-22).
///
/// Extracting it did more than move code: the rule was inlined in
/// `NotificationCubit.load`, where it read the prefs store **once per toggle**
/// (three reads per load) while its own comment claimed D-PF2's "the store is
/// read once per load". The contract is now the implementation, and it is
/// pinned by a test that counts the reads.
///
/// A null store means the env-less/default case: every category is enabled
/// (AC-4), so the rows pass through unchanged.
class LoadVisibleNotifications
    implements UseCase<NotificationVisibility, List<Notification>> {
  const LoadVisibleNotifications(this._prefsStore);

  final NotificationPrefsStore? _prefsStore;

  @override
  Future<Result<NotificationVisibility>> call(List<Notification> rows) async {
    // D-PF2: one read per call, whatever the number of toggles.
    final NotificationPrefs? prefs = await _prefsStore?.read();
    final List<Notification> visible = prefs == null
        ? rows
        : rows
              .where((Notification row) => prefs.isEnabled(row.category))
              .toList(growable: false);
    return Success<NotificationVisibility>(
      NotificationVisibility(
        visible: visible,
        allMuted: rows.isNotEmpty && visible.isEmpty,
      ),
    );
  }
}
