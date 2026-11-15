part of 'message_thread_detail_screen.dart';

class _DetailSurface extends StatefulWidget {
  const _DetailSurface({
    required this.threadId,
    this.threadTitle,
    required this.embedded,
  });

  final String threadId;
  final String? threadTitle;
  final bool embedded;

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
    final bool localOnly = backendIsLocalOnly;
    final DemoLabels labels = DemoLabels(l10n, localOnly: localOnly);
    final Widget body = SafeArea(
      // The demo note travels INSIDE the scrollable transcript (below):
      // as a fixed sibling of the Expanded transcript it consumed more
      // height than a short viewport had at text scale 2.0, overflowing
      // the body Column by 96px on a 320px-wide phone.
      child: BlocBuilder<MessageThreadDetailCubit, MessageThreadDetailState>(
        builder: _bodyFor,
      ),
    );
    // D-LV1: the insert-only composer — a message field + send. No edit,
    // no delete, no attachments (the write-path creep guard).
    final Widget composer = SafeArea(
      child: _Composer(threadId: widget.threadId),
    );
    if (widget.embedded) {
      final TextTheme text = Theme.of(context).textTheme;
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return Column(
        children: <Widget>[
          // No AppBar in the pane, so the selected thread keeps its name at
          // the top of the transcript.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceSm,
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceSm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                widget.threadTitle == null
                    ? l10n.messageThreadDetailTitle
                    : labels.threadTitle(widget.threadTitle!),
                style: text.titleMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
          composer,
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.threadTitle == null
              ? l10n.messageThreadDetailTitle
              : labels.threadTitle(widget.threadTitle!),
        ),
      ),
      body: body,
      bottomNavigationBar: composer,
    );
  }

  Widget _bodyFor(BuildContext context, MessageThreadDetailState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: _resultsView(
        context,
        state,
        l10n,
        text,
        scheme,
        localOnly: backendIsLocalOnly,
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    MessageThreadDetailState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme, {
    required bool localOnly,
  }) {
    final MessageThreadDetailCubit cubit = context
        .read<MessageThreadDetailCubit>();
    final Widget? note = localOnly
        ? Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: LegalHubTheme.spaceSm,
            ),
            child: Text(
              l10n.messagesLocalOnlyNote,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        : null;
    final Widget empty = ListView(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      children: <Widget>[
        ?note,
        Text(
          l10n.messagesDetailEmpty,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
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
              // The demo note (when present) is item 0 so it scrolls with
              // the transcript instead of stealing fixed body height.
              itemCount: messages.length + (note == null ? 0 : 1),
              itemBuilder: (BuildContext context, int index) {
                if (note != null && index == 0) {
                  return note;
                }
                final int messageIndex = note == null ? index : index - 1;
                final Message message = messages[messageIndex];
                final Widget tile = _MessageTile(
                  message: message,
                  localOnly: localOnly,
                );
                if (messageIndex == messages.length - 1) {
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
