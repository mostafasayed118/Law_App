part of 'video_consultation_screen.dart';

/// The synthetic in-call surface (demo-posture C-2/C-3).
///
/// Everything here is **local UI state**: participant tiles are static
/// avatars, the mic/camera buttons flip icons only (no permission dialog,
/// no capture, no stream anywhere), and the elapsed readout ticks a plain
/// [Timer] that dies with the widget. Leaving returns to the session list
/// and records nothing.
class _CallSurface extends StatefulWidget {
  const _CallSurface({required this.session});

  final ConsultationSession session;

  @override
  State<_CallSurface> createState() => _CallSurfaceState();
}

class _CallSurfaceState extends State<_CallSurface> {
  int _elapsedSeconds = 0;
  Timer? _ticker;
  bool _micMuted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    // 1-second elapsed readout, driven by a tick counter rather than a
    // wall-clock delta — the counter is deterministic under the test zone's
    // fake async (a real-clock difference would not advance with pumped
    // time) and identical for a user.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds += 1);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _elapsed {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(_elapsedSeconds ~/ 60)}:${two(_elapsedSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        children: <Widget>[
          // The live badge + elapsed readout. The badge is a label, not a
          // recording indicator — nothing is captured (C-3).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _DemoBadge(label: l10n.videoCallLiveBadge),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Text(
                l10n.videoCallElapsed(_elapsed),
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          Text(
            l10n.videoCallWith(widget.session.participantName),
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          // Participant tiles: static demo avatars, never a video feed.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _ParticipantTile(icon: Icons.person, label: l10n.videoCallYou),
              const SizedBox(width: LegalHubTheme.spaceLg),
              _ParticipantTile(
                icon: Icons.person_outline,
                label: widget.session.participantName,
              ),
            ],
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          // Demo-only toggles: they flip local icons and nothing else.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton.filledTonal(
                tooltip: _micMuted ? l10n.videoMicMuted : l10n.videoMicOn,
                onPressed: () => setState(() => _micMuted = !_micMuted),
                icon: Icon(_micMuted ? Icons.mic_off : Icons.mic),
              ),
              const SizedBox(width: LegalHubTheme.spaceLg),
              IconButton.filledTonal(
                tooltip: _cameraOff ? l10n.videoCameraOff : l10n.videoCameraOn,
                onPressed: () => setState(() => _cameraOff = !_cameraOff),
                icon: Icon(_cameraOff ? Icons.videocam_off : Icons.videocam),
              ),
            ],
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          Text(
            l10n.videoCallNote,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          FilledButton.icon(
            icon: const Icon(Icons.call_end),
            label: Text(l10n.videoLeave),
            onPressed: () => context.read<VideoCubit>().leave(),
          ),
        ],
      ),
    );
  }
}

/// The small "live" pill above the call. A stateless label — the color is
/// the theme's secondary container, not a status semantics.
class _DemoBadge extends StatelessWidget {
  const _DemoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceMd,
        vertical: LegalHubTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One static participant tile (avatar + display name). Deliberately dumb:
/// there is no feed behind it to render.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: 36,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
