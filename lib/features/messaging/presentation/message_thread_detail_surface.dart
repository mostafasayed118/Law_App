part of 'message_thread_detail_screen.dart';

class _DetailSurface extends StatefulWidget {
  const _DetailSurface({required this.threadId, this.threadTitle});

  final String threadId;
  final String? threadTitle;

  @override
  State<_DetailSurface> createState() => _DetailSurfaceState();
}

class _DetailSurfaceState extends State<_DetailSurface> {
  @override
  void initState() {
    super.initState();
    // Load the thread's messages + open the live subscription on first
    // frame (matches the list/matter pattern; the cubit's initial state is
    // already loading, and the fake resolves immediately, so the first
    // frame settles straight into the list). D-LV4: the subscription is a
    // screen-lifetime concern — the cubit's close cancels it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final MessageThreadDetailCubit cubit = context
          .read<MessageThreadDetailCubit>();
      cubit.load(widget.threadId);
      unawaited(cubit.subscribe(widget.threadId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.threadTitle ?? l10n.messageThreadDetailTitle),
      ),
      body: SafeArea(
        // Column + Expanded (audit 2026-09-21, P4): the transcript is a
        // lazily-built ListView inside the remaining height, not an eager
        // Column inside an outer ListView — long threads only build the
        // visible viewport and the composer keeps its fixed footer slot.
        child: Column(
          children: <Widget>[
            Expanded(
              child:
                  BlocBuilder<
                    MessageThreadDetailCubit,
                    MessageThreadDetailState
                  >(builder: _bodyFor),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: LegalHubTheme.spaceSm,
              ),
              child: Text(
                l10n.messagesLocalOnlyNote,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
      // D-LV1: the insert-only composer — a message field + send. No edit,
      // no delete, no attachments (the write-path creep guard).
      bottomNavigationBar: SafeArea(
        child: _Composer(threadId: widget.threadId),
      ),
    );
  }

  Widget _bodyFor(BuildContext context, MessageThreadDetailState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: _resultsView(context, state, l10n, text, scheme),
    );
  }

  Widget _resultsView(
    BuildContext context,
    MessageThreadDetailState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final MessageThreadDetailCubit cubit = context
        .read<MessageThreadDetailCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.messagesDetailEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return ViewStateSwitch<List<Message>>(
      state: state.messages,
      onRetry: () => cubit.load(widget.threadId),
      builder: (BuildContext context, List<Message> messages) =>
          messages.isEmpty
          ? empty
          // Lazy transcript (audit 2026-09-21, P4): rows are constructed
          // on demand, preserving the tile + `spaceSm` gap rhythm of the
          // previous eager Column.
          : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                final Message message = messages[index];
                final Widget tile = _MessageTile(message: message);
                if (index == messages.length - 1) {
                  return tile;
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    tile,
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                );
              },
            ),
      empty: empty,
      errorCopy: l10n.messagesDetailError,
    );
  }
}
