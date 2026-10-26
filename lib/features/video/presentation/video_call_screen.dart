import 'dart:async';

import 'package:flutter/material.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:livekit_client/livekit_client.dart';

/// Connects a room the screen created. Injected by tests so the pre-connect
/// UI can be exercised without native WebRTC.
typedef VideoRoomConnector =
    Future<void> Function(Room room, String url, String token);

/// Tears a room down. Injected by tests in place of the real LiveKit calls.
typedef VideoRoomTeardown = Future<void> Function(Room room);

Room _createRoom() => Room();

Future<void> _connectRoom(Room room, String url, String token) =>
    room.connect(url, token);

/// Disconnects then disposes [room]. Both steps are individually guarded:
/// a connection that is already gone must not prevent the object release.
Future<void> teardownVideoRoom(Room room) async {
  try {
    await room.disconnect();
  } on Object {
    // The local connection is already gone; disposal must still run.
  }
  try {
    await room.dispose();
  } on Object {
    // A twice-disposed room is not a teardown failure.
  }
}

/// The real in-call surface (design §6; plan Task 7).
///
/// Connects with the server-minted room token, enables the camera and
/// microphone after the connection (the OS permission prompt happens inside
/// LiveKit's native capture), renders every participant's video track, and
/// disconnects on leave. The creator or a partner also ends the persisted
/// session when they leave. Nothing is recorded or transcribed.
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    required this.session,
    required this.token,
    required this.gateway,
    this.canEnd = false,
    this.connector,
    this.teardown,
    this.roomFactory,
    super.key,
  });

  final VideoSession session;
  final VideoToken token;
  final VideoGateway gateway;
  final bool canEnd;
  final VideoRoomConnector? connector;
  final VideoRoomTeardown? teardown;

  /// Creates the room the screen owns. Injected by tests so no native
  /// WebRTC engine is constructed.
  final Room Function()? roomFactory;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;
  bool _connecting = true;
  bool _failed = false;
  bool _leaving = false;
  bool _mediaWarning = false;
  bool _micOn = true;
  bool _cameraOn = true;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void dispose() {
    final Room? room = _room;
    _room = null;
    if (room != null) {
      unawaited((widget.teardown ?? teardownVideoRoom)(room));
    }
    super.dispose();
  }

  VideoRoomTeardown get _teardownRoom => widget.teardown ?? teardownVideoRoom;

  Future<void> _teardown(Room room) async {
    if (identical(_room, room)) {
      _room = null;
    }
    await _teardownRoom(room);
  }

  Future<void> _connect() async {
    if (_connecting && _room != null) {
      return;
    }
    setState(() {
      _connecting = true;
      _failed = false;
    });
    final Room room = _room ?? (widget.roomFactory ?? _createRoom)();
    _room = room;
    try {
      await (widget.connector ?? _connectRoom)(
        room,
        widget.token.url,
        widget.token.token,
      );
      if (!mounted) {
        await _teardown(room);
        return;
      }
      setState(() {
        _connecting = false;
      });
      await _enableMedia(room);
      unawaited(_markLive());
    } on Object {
      await _teardown(room);
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _failed = true;
      });
    }
  }

  Future<void> _enableMedia(Room room) async {
    final LocalParticipant? local = room.localParticipant;
    if (local == null) {
      return;
    }
    try {
      await local.setCameraEnabled(true);
      await local.setMicrophoneEnabled(true);
    } on Object {
      if (mounted) {
        setState(() => _mediaWarning = true);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _micOn = local.isMicrophoneEnabled();
      _cameraOn = local.isCameraEnabled();
    });
  }

  Future<void> _markLive() async {
    if (widget.session.status != VideoSessionStatus.scheduled) {
      return;
    }
    await widget.gateway.markLive(widget.session.id);
  }

  Future<void> _toggleMic() async {
    final LocalParticipant? local = _room?.localParticipant;
    if (local == null) {
      return;
    }
    final bool next = !_micOn;
    setState(() => _micOn = next);
    try {
      await local.setMicrophoneEnabled(next);
    } on Object {
      if (mounted) {
        setState(() => _micOn = !next);
      }
    }
  }

  Future<void> _toggleCamera() async {
    final LocalParticipant? local = _room?.localParticipant;
    if (local == null) {
      return;
    }
    final bool next = !_cameraOn;
    setState(() => _cameraOn = next);
    try {
      await local.setCameraEnabled(next);
    } on Object {
      if (mounted) {
        setState(() => _cameraOn = !next);
      }
    }
  }

  Future<void> _leave() async {
    if (_leaving) {
      return;
    }
    setState(() => _leaving = true);
    final Room? room = _room;
    if (room != null) {
      _room = null;
      await _teardownRoom(room);
      if (widget.canEnd) {
        await widget.gateway.end(widget.session.id);
      }
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_leave());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.videoSessionTitle),
        ),
        body: _body(l10n),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_connecting) {
      return _connectingBody(l10n);
    }
    if (_failed) {
      return _failedBody(l10n);
    }
    final Room? room = _room;
    if (room == null) {
      return _failedBody(l10n);
    }
    return _connectedBody(l10n, room);
  }

  Widget _connectingBody(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(l10n.videoCallConnecting),
          const SizedBox(height: LegalHubTheme.spaceSm),
          TextButton(
            onPressed: _leaving ? null : _leave,
            child: Text(l10n.videoLeave),
          ),
        ],
      ),
    );
  }

  Widget _failedBody(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.videoCallFailed),
          const SizedBox(height: LegalHubTheme.spaceMd),
          FilledButton(onPressed: _connect, child: Text(l10n.retry)),
          const SizedBox(height: LegalHubTheme.spaceSm),
          TextButton(
            onPressed: _leaving ? null : _leave,
            child: Text(l10n.videoLeave),
          ),
        ],
      ),
    );
  }

  Widget _connectedBody(AppLocalizations l10n, Room room) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            slivers: <Widget>[
              if (_mediaWarning)
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    LegalHubTheme.marginMobile,
                    LegalHubTheme.marginMobile,
                    LegalHubTheme.marginMobile,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: LegalHubTheme.spaceMd,
                      ),
                      child: Text(
                        l10n.videoCallMediaWarning,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ),
                ),
              _ParticipantsGrid(
                l10n: l10n,
                room: room,
                topPadding: _mediaWarning ? 0 : LegalHubTheme.marginMobile,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LegalHubTheme.marginMobile,
              0,
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: _micOn ? l10n.videoMicOn : l10n.videoMicMuted,
                  onPressed: _toggleMic,
                  icon: Icon(_micOn ? Icons.mic : Icons.mic_off),
                ),
                const SizedBox(width: LegalHubTheme.spaceLg),
                IconButton.filledTonal(
                  tooltip: _cameraOn ? l10n.videoCameraOn : l10n.videoCameraOff,
                  onPressed: _toggleCamera,
                  icon: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off),
                ),
                const SizedBox(width: LegalHubTheme.spaceLg),
                FilledButton.icon(
                  onPressed: _leaving ? null : _leave,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  icon: const Icon(Icons.call_end),
                  label: Text(l10n.videoLeave),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The room-driven participant grid. Only this sliver listens to the room, so
/// a participant/track event rebuilds the tiles instead of the whole call
/// screen (the controls and app bar stay untouched).
class _ParticipantsGrid extends StatelessWidget {
  const _ParticipantsGrid({
    required this.l10n,
    required this.room,
    required this.topPadding,
  });

  final AppLocalizations l10n;
  final Room room;

  /// Zero when the media warning already supplies the gap above the grid.
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (BuildContext context, Widget? child) {
        final LocalParticipant? local = room.localParticipant;
        final List<Widget> tiles = <Widget>[
          if (local != null)
            _ParticipantTile(
              label: l10n.videoCallYou,
              track: _videoTrackOf(local),
              mirror: true,
            ),
          for (final RemoteParticipant remote in room.remoteParticipants.values)
            _ParticipantTile(
              label: remote.name.isEmpty ? remote.identity : remote.name,
              track: _videoTrackOf(remote),
            ),
        ];
        return SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            LegalHubTheme.marginMobile,
            topPadding,
            LegalHubTheme.marginMobile,
            LegalHubTheme.marginMobile,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: tiles.length > 1 ? 2 : 1,
              childAspectRatio: 3 / 4,
              mainAxisSpacing: LegalHubTheme.spaceSm,
              crossAxisSpacing: LegalHubTheme.spaceSm,
            ),
            itemCount: tiles.length,
            itemBuilder: (BuildContext context, int index) =>
                RepaintBoundary(child: tiles[index]),
          ),
        );
      },
    );
  }

  VideoTrack? _videoTrackOf<T extends TrackPublication<Track>>(
    Participant<T> participant,
  ) {
    for (final TrackPublication<Track> publication
        in participant.videoTrackPublications) {
      final Track? track = publication.track;
      if (track is VideoTrack && !publication.muted) {
        return track;
      }
    }
    return null;
  }
}

/// One participant tile: the live video track when published, otherwise an
/// initial avatar, with the display name pinned to the corner.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.label,
    required this.track,
    this.mirror = false,
  });

  final String label;
  final VideoTrack? track;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String initial = label.isEmpty ? '?' : label.substring(0, 1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(LegalHubTheme.radiusXl),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (track != null)
              VideoTrackRenderer(
                track!,
                fit: VideoViewFit.cover,
                mirrorMode: mirror
                    ? VideoViewMirrorMode.mirror
                    : VideoViewMirrorMode.off,
              )
            else
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    initial.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              start: LegalHubTheme.spaceSm,
              bottom: LegalHubTheme.spaceSm,
              end: LegalHubTheme.spaceSm,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: LegalHubTheme.spaceSm,
                  vertical: LegalHubTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(LegalHubTheme.radiusMd),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
