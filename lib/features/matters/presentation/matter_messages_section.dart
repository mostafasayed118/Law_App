import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../../messaging/domain/message_thread.dart';
import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Messages section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) instead of a foreign feature's presentation cubit
/// (audit: matters god-feature) and renders the subset of the thread list
/// whose [MessageThread.matterRef] equals [matterRef] — a client-side view
/// over the gateway list (the D-M5 pattern; there is no per-matter fetch).
/// **Thread metadata only**: each row renders the D-MSG4
/// title/participants/date fields and nothing else — no message body, no
/// preview, no thread-open affordance, no composer (D-W4 body-less line).
/// An empty per-matter subset renders the localized empty copy (AC-3).
class MatterMessagesSection extends StatefulWidget {
  const MatterMessagesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [MessageThread.matterRef],
  /// D-MSG4/D-W2).
  final String matterRef;

  @override
  State<MatterMessagesSection> createState() => _MatterMessagesSectionState();
}

class _MatterMessagesSectionState extends State<MatterMessagesSection> {
  @override
  void initState() {
    super.initState();
    // Load the thread list on open (same pattern as the standalone
    // messages surface); the per-matter subset is filtered client-side
    // below. Only this list loads — sibling sections trigger their own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MatterWorkspaceCubit>().loadThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<MatterWorkspaceCubit, MatterWorkspaceState>(
      buildWhen:
          (MatterWorkspaceState previous, MatterWorkspaceState current) =>
              previous.threads != current.threads,
      builder: (BuildContext context, MatterWorkspaceState state) {
        return WorkspaceSection<MessageThread>(
          state: state.threads,
          onRetry: () => context.read<MatterWorkspaceCubit>().loadThreads(),
          errorCopy: l10n.messagesError,
          emptyCopy: l10n.matterWorkspaceMessagesEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (MessageThread thread) => thread.matterRef,
          itemBuilder: (BuildContext context, MessageThread thread) => AppTile(
            title: demoThreadTitle(l10n, thread.title),
            subtitles: <String>[
              '${thread.participants.join(', ')} · '
                  '${formatMediumDate(l10n, thread.lastActivityAt)}',
            ],
          ),
        );
      },
    );
  }
}
