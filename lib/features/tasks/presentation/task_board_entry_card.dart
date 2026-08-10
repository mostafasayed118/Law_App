import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the task board (`/tasks`, v1 queue 2026-08-09).
/// Navigation hint only.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class TaskBoardEntryCard extends StatelessWidget {
  const TaskBoardEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.checklist_outlined,
      title: l10n.tasksEntryTitle,
      subtitle: l10n.tasksEntrySubtitle,
      onTap: onTap,
    );
  }
}
