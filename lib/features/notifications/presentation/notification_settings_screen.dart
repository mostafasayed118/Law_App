import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/notification_prefs.dart';
import '../domain/notification_prefs_store.dart';
import 'notification_prefs_cubit.dart';

part 'notification_settings_body.dart';

/// User-level notification preferences (foundation scope).
///
/// Local-only UX preferences: three toggles persisted on this device via the
/// [NotificationPrefsStore] seam, mirroring how the locale is persisted.
/// Delivery of notifications is a v1 capability and is explicitly labeled as
/// such on the screen (§1.3 no-false-assurance) — nothing here is sent to a
/// server.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationPrefsCubit>(
      create: (BuildContext context) =>
          NotificationPrefsCubit(serviceLocator<NotificationPrefsStore>())
            ..load(),
      child: const _NotificationSettingsBody(),
    );
  }
}
