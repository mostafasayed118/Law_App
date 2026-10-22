part of 'video_consultation_screen.dart';

/// One session row: status + schedule, with the permitted actions.
///
/// Join is shown for scheduled/live rows; End only when the caller is the
/// creator or a partner. Both calls re-assert the server gates — a refusal is
/// rendered as the typed failure, never a silent success.
class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.canEnd,
    required this.onJoin,
    required this.onEnd,
  });

  final VideoSession session;
  final bool canEnd;
  final VoidCallback onJoin;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? when = session.scheduledAt ?? session.startedAt;
    return AppTile(
      icon: _iconFor(session.status),
      title: l10n.videoSessionTitle,
      subtitles: <String>[
        videoStatusLabel(l10n, session.status),
        if (when != null) formatMediumDateTime(l10n, when.toLocal()),
      ],
      showChevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (session.isJoinable)
            FilledButton.tonal(onPressed: onJoin, child: Text(l10n.videoJoin)),
          if (canEnd)
            TextButton(
              onPressed: onEnd,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.videoEnd),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(VideoSessionStatus status) => switch (status) {
    VideoSessionStatus.live => Icons.videocam,
    VideoSessionStatus.scheduled => Icons.videocam_outlined,
    VideoSessionStatus.ended ||
    VideoSessionStatus.cancelled => Icons.videocam_off_outlined,
  };
}
