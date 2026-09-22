part of 'message_thread_detail_screen.dart';

/// The insert-only composer (D-LV1): a single message field + send button.
///
/// The button is disabled while the field is empty or a send is in flight;
/// a failed send shows [MessageThreadDetailState.sendError] inline and keeps
/// the draft so the user can retry. The author name is the session's stored
/// display name (the D-RT4 convention) when the app-scoped [AuthCubit] is
/// available, else null (the seam falls back to a neutral generic). There is
/// deliberately **no edit/delete/attachment affordance** anywhere on this
/// surface.
class _Composer extends StatefulWidget {
  const _Composer({required this.threadId});

  final String threadId;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _sessionDisplayName() {
    // The app-scoped AuthCubit may be absent in tests that only register the
    // messaging seams — guard the lookup so the composer never throws.
    if (!serviceLocator.isRegistered<AuthCubit>()) {
      return null;
    }
    return serviceLocator<AuthCubit>().state.session?.displayName;
  }

  void _send(BuildContext context) {
    final String body = _controller.text.trim();
    if (body.isEmpty) {
      return;
    }
    context.read<MessageThreadDetailCubit>().send(
      widget.threadId,
      body,
      authorDisplayName: _sessionDisplayName(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocBuilder<MessageThreadDetailCubit, MessageThreadDetailState>(
      // The empty-draft signal is scoped to the send button via a
      // ValueListenableBuilder on the controller (audit 2026-09-21, P4) —
      // the composer chrome no longer rebuilds the whole bloc subtree on
      // every keystroke, and there is no setState/onChange coupling at all.
      buildWhen:
          (
            MessageThreadDetailState previous,
            MessageThreadDetailState current,
          ) {
            return previous.sending != current.sending ||
                previous.sendError != current.sendError;
          },
      builder: (BuildContext context, MessageThreadDetailState state) {
        return Material(
          color: scheme.surfaceContainerLowest,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: LegalHubTheme.marginMobile,
              end: LegalHubTheme.marginMobile,
              top: LegalHubTheme.spaceSm,
              bottom: LegalHubTheme.spaceSm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: l10n.messageComposerHint,
                          border: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(LegalHubTheme.radiusLg),
                            ),
                          ),
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                            horizontal: LegalHubTheme.spaceMd,
                            vertical: LegalHubTheme.spaceSm,
                          ),
                        ),
                        onSubmitted: (_) => _send(context),
                      ),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceSm),
                    // Only the send affordance listens to the draft text:
                    // typing rebuilds this button, not the composer or the
                    // thread list.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder:
                          (
                            BuildContext context,
                            TextEditingValue value,
                            Widget? child,
                          ) {
                            final bool canSend =
                                value.text.trim().isNotEmpty && !state.sending;
                            return IconButton.filled(
                              onPressed: canSend ? () => _send(context) : null,
                              tooltip: l10n.messageSend,
                              icon: state.sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            );
                          },
                    ),
                  ],
                ),
                if (state.sendError != null) ...<Widget>[
                  const SizedBox(height: LegalHubTheme.spaceSm),
                  Text(
                    state.sendError!,
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
