import 'dart:async';

import 'package:flutter/material.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'join_gate.dart';
import 'video_call_screen.dart';
import 'video_create_sheet.dart';
import 'video_cubit.dart';
import 'video_error_messages.dart';
import 'video_state.dart';

part 'video_session_tile.dart';

/// Video-consultation list (design §6).
///
/// Shows the active organization's persisted sessions ordered live →
/// scheduled → ended → cancelled. Scheduling is offered to partners and
/// attorneys; joining fetches a room token from `video-token`; ending is
/// offered to the creator or a partner. Every gate is re-asserted server-side
/// — these flags are navigation hints, never authorization grants.
class VideoConsultationScreen extends StatefulWidget {
  const VideoConsultationScreen({
    super.key,
    this.canCreate = false,
    this.canEndAny = false,
    this.currentUserId,
  });

  final bool canCreate;
  final bool canEndAny;
  final String? currentUserId;

  @override
  State<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  late final VideoGateway _gateway = serviceLocator<VideoGateway>();
  late final VideoCubit _cubit = VideoCubit(
    _gateway,
    serviceLocator<MatterGateway>(),
  );

  /// One Join at a time: a double tap must not stack progress dialogs or push
  /// two call screens (audit 2026-10-27, F16).
  final JoinGate _joinGate = JoinGate();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoTitle)),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.video_call),
              label: Text(l10n.videoCreateFab),
            )
          : null,
      body: CubitListSurface<VideoCubit, VideoState, VideoSession>(
        createCubit: () => _cubit,
        project: (VideoState state) => state.sessions,
        load: (VideoCubit cubit) => cubit.load(),
        tileBuilder: (BuildContext context, VideoSession session) =>
            _SessionTile(
              session: session,
              canEnd: _canEnd(session),
              onJoin: () => _join(session),
              onEnd: () => _end(session),
            ),
        empty: (BuildContext context, VideoState state) => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
          child: Text(
            l10n.videoEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        errorCopy: l10n.videoError,
        localOnlyNote: backendIsLocalOnly
            ? l10n.videoLocalOnlyNote
            : l10n.videoStoredNote,
      ),
    );
  }

  bool _canEnd(VideoSession session) =>
      session.isJoinable &&
      (widget.canEndAny || session.createdBy == widget.currentUserId);

  Future<void> _openCreate() async {
    final bool? created = await showVideoCreateSheet(context, cubit: _cubit);
    if (!mounted || created != true) {
      return;
    }
    _showSnack(AppLocalizations.of(context).videoCreateSuccess);
  }

  Future<void> _join(VideoSession session) async {
    if (!_joinGate.tryBegin()) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    // Push an explicit route and keep the handle: the dismissal below must
    // close exactly this dialog, never whatever happens to be topmost when
    // the token call settles (audit 2026-10-27, F16).
    final DialogRoute<void> progressRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (BuildContext dialogContext) => const _JoinProgressDialog(),
    );
    unawaited(navigator.push<void>(progressRoute));
    final Result<VideoToken> result;
    try {
      result = await _cubit.fetchToken(session.id);
    } finally {
      _joinGate.end();
      // The progress dialog belongs to the root navigator; close it even when
      // the token call throws or the list route unmounts mid-flight.
      if (navigator.mounted && progressRoute.isActive) {
        navigator.removeRoute(progressRoute);
      }
    }
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success<VideoToken>(value: final VideoToken token):
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => VideoCallScreen(
              session: session,
              token: token,
              gateway: _gateway,
              canEnd: _canEnd(session),
            ),
          ),
        );
        if (mounted) {
          await _cubit.load();
        }
      case Failure<VideoToken>(error: final AppError error):
        await _showJoinError(error);
    }
  }

  Future<void> _showJoinError(AppError error) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.videoJoinUnavailableTitle),
        content: Text(videoErrorMessage(l10n, error)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  Future<void> _end(VideoSession session) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.videoEndConfirmTitle,
      content: Text(l10n.videoEndConfirmBody),
      confirmLabel: l10n.videoEndConfirm,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final AppError? error = await _cubit.end(session.id);
    if (!mounted) {
      return;
    }
    _showSnack(
      error == null
          ? AppLocalizations.of(context).videoEndSuccess
          : videoErrorMessage(AppLocalizations.of(context), error),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The blocking "fetching a room token" dialog. It has no actions on purpose:
/// the caller always dismisses it once the token call settles.
class _JoinProgressDialog extends StatelessWidget {
  const _JoinProgressDialog();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // The caller always dismisses this dialog once the token call settles;
    // system back must not pop it early and strand the join in flight.
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(child: Text(l10n.videoCallConnecting)),
          ],
        ),
      ),
    );
  }
}
