part of 'matter_messages_section.dart';

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
