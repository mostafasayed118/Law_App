import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/consultation_session.dart';
import '../domain/video_gateway.dart';
import 'video_cubit.dart';
import 'video_state.dart';

part 'video_session_tile.dart';
part 'video_call_surface.dart';

/// Video-consultation demo screen (spec §6 `video_consultation`, D-15;
/// the surface the `docs/video_scope_decision_2026-08-11.md` posture
/// describes: a synthetic [VideoGateway] seam, zero real media, zero
/// writes).
///
/// Two modes, owned by [VideoState.inCall]:
/// - the **session list** — read-only demo rows with a "Join demo call"
///   affordance per scheduled session; and
/// - the **synthetic call surface** — participant tiles, demo-only
///   mic/camera toggles (local UI state; no permission is ever requested),
///   an elapsed-time readout, and a leave action. A persistent note states
///   the demo posture on both modes.
///
/// One cubit instance is provided here and shared by both modes, so the
/// screen keeps its own shell instead of the shared [CubitListSurface]
/// (which scopes a cubit to the list only — the same "doesn't fit" case as
/// the document/message list screens).
class VideoConsultationScreen extends StatelessWidget {
  const VideoConsultationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoTitle)),
      body: BlocProvider<VideoCubit>(
        create: (BuildContext context) =>
            VideoCubit(serviceLocator<VideoGateway>()),
        child: const _VideoBody(),
      ),
    );
  }
}

class _VideoBody extends StatefulWidget {
  const _VideoBody();

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  @override
  void initState() {
    super.initState();
    // First load on open (the discovery/document pattern): the cubit's
    // initial state is already loading and the fake resolves immediately,
    // so the first frame settles straight into the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<VideoCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: BlocBuilder<VideoCubit, VideoState>(
        builder: (BuildContext context, VideoState state) {
          // Call mode resolves the joined session from the loaded list (the
          // cubit's join() only accepts known ids, so the lookup hits). If
          // it somehow misses — a defensive guard, not a designed state —
          // the body falls through to the list mode instead of rendering a
          // fabricated session.
          if (state.inCall) {
            final ConsultationSession? joined = switch (state.sessions) {
              ViewSuccess<List<ConsultationSession>>(
                data: final List<ConsultationSession> sessions,
              ) =>
                sessions
                    .where(
                      (ConsultationSession s) => s.id == state.joinedSessionId,
                    )
                    .firstOrNull,
              ViewLoading() ||
              ViewEmpty() ||
              ViewError() ||
              ViewOffline() ||
              ViewUnauthorized() => null,
            };
            if (joined != null) {
              return _CallSurface(session: joined);
            }
          }
          final VideoCubit cubit = context.read<VideoCubit>();
          return ViewStateList<ConsultationSession>(
            state: state.sessions,
            onRetry: cubit.load,
            tileBuilder: (BuildContext context, ConsultationSession session) =>
                _SessionTile(session: session),
            empty: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: LegalHubTheme.spaceMd,
              ),
              child: Text(
                l10n.videoEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            errorCopy: l10n.videoError,
            localOnlyNote: l10n.videoLocalOnlyNote,
          );
        },
      ),
    );
  }
}
