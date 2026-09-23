import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the video-consultation demo (`/video`, spec
/// D-15 demo-posture). Navigation hint only.
///
/// The visual shell is the shared [AppEntryCard] (the approvals E1
/// wrapper pattern); this class keeps the feature's icon + localized copy
/// and the public name the home screen and tests construct by type.
class VideoEntryCard extends StatelessWidget {
  const VideoEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.video_call_outlined,
      title: l10n.videoEntryTitle,
      subtitle: l10n.videoEntrySubtitle,
      onTap: onTap,
    );
  }
}
