import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/service_locator.dart';
import '../../../features/messaging/domain/message_gateway.dart';
import '../../../features/messaging/domain/message_thread.dart';
import '../../../features/messaging/presentation/message_cubit.dart';
import '../../../features/messaging/presentation/message_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';

/// Per-matter Messages section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Provides its own [MessageCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the synthetic thread list whose
/// [MessageThread.matterRef] equals [matterRef] — a client-side view over the
/// fake list (the D-M5 pattern; there is no per-matter fetch). **Thread
/// metadata only**: each row renders the D-MSG4 title/participants/date
/// fields and nothing else — no message body, no preview, no thread-open
/// affordance, no composer (D-W4 body-less line). An empty per-matter subset
/// renders the localized empty copy (AC-3).
class MatterMessagesSection extends StatelessWidget {
  const MatterMessagesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [MessageThread.matterRef],
  /// D-MSG4/D-W2).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageCubit>(
      create: (BuildContext context) =>
          MessageCubit(serviceLocator<MessageGateway>()),
      child: _MessagesSectionBody(matterRef: matterRef),
    );
  }
}

class _MessagesSectionBody extends StatefulWidget {
  const _MessagesSectionBody({required this.matterRef});

  final String matterRef;

  @override
  State<_MessagesSectionBody> createState() => _MessagesSectionBodyState();
}

class _MessagesSectionBodyState extends State<_MessagesSectionBody> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (same pattern as the standalone
    // messages surface); the per-matter subset is filtered client-side
    // below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessageCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<MessageCubit, MessageState>(
      builder: (BuildContext context, MessageState state) {
        return WorkspaceSection<MessageThread>(
          state: state.threads,
          onRetry: () => context.read<MessageCubit>().load(),
          errorCopy: l10n.messagesError,
          emptyCopy: l10n.matterWorkspaceMessagesEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (MessageThread thread) => thread.matterRef,
          itemBuilder: (BuildContext context, MessageThread thread) => AppTile(
            title: thread.title,
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
