part of 'video_consultation_screen.dart';

/// A read-only session row: participant, topic, and scheduled time, with a
/// "Join demo call" affordance. The join is a client-side demo transition —
/// it never requests media (C-2) and never records anything (C-3).
class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final ConsultationSession session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VideoCubit cubit = context.read<VideoCubit>();
    final String date = formatMediumDate(l10n, session.scheduledAt);
    return AppTile(
      icon: Icons.videocam_outlined,
      title: session.participantName,
      subtitles: <String>['${session.topic} · $date'],
      showChevron: false,
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceSm),
        child: FilledButton.tonal(
          onPressed: () => cubit.join(session.id),
          child: Text(l10n.videoJoin),
        ),
      ),
    );
  }
}
