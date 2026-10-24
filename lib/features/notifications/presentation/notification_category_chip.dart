import 'package:flutter/material.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/label_chip.dart';

import 'notification_labels.dart';

/// Small colored chip rendering a notification row's category
/// (notification-feed slice, D-N4 — the three generic categories the prefs
/// already use).
///
/// The label text is always rendered (never color alone — INSTRUCTIONS
/// §4.5), so the tones below only distinguish the categories: appointment =
/// the informational token, activity = the neutral secondary container,
/// system = the tertiary container (the matter/document chip tones). The
/// colors come from the theme's semantic tokens / ColorScheme — never
/// hardcoded. Display-only — the chip has no tap affordance, consistent
/// with the feed's read-only posture (D-N2).
class NotificationCategoryChip extends StatelessWidget {
  const NotificationCategoryChip({required this.category, super.key});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (category) {
      NotificationCategory.appointment => (scheme.info, scheme.onInfo),
      NotificationCategory.activity => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      NotificationCategory.system => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return LabelChip(
      label: notificationCategoryLabel(AppLocalizations.of(context), category),
      background: background,
      foreground: foreground,
    );
  }
}
