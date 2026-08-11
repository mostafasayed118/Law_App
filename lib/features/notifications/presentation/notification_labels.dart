import '../../../l10n/app_localizations.dart';
import '../domain/notification.dart';

/// Localized label for a [NotificationCategory], rendered as the feed row's
/// status chip (notification-feed slice, D-N4 — the three generic
/// categories the prefs already use; `documentTypeLabel` pattern).
String notificationCategoryLabel(
  AppLocalizations l10n,
  NotificationCategory category,
) => switch (category) {
  NotificationCategory.appointment => l10n.notificationCategoryAppointment,
  NotificationCategory.activity => l10n.notificationCategoryActivity,
  NotificationCategory.system => l10n.notificationCategorySystem,
};
