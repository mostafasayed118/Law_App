import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../features/auth/presentation/auth_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/message.dart';
import '../domain/message_gateway.dart';
import 'message_thread_detail_cubit.dart';
import 'message_thread_detail_state.dart';

/// Thread-detail surface (sixth §14 un-deferral, realtime slice D-RT5;
/// realtime push slice D-LV1/D-LV4).
///
/// The **first thread-open affordance**: tapping a thread row in the list
/// opens this screen, which loads that thread's message rows from the
/// [MessageGateway] seam (the dev fake in env-less runs, the env-gated
/// Supabase implementation in configured builds), subscribes to live INSERT
/// delivery (D-LV4), and renders them. This is the surface where message
/// **bodies** first appear — the D-MSG1 consummation, scoped to the real
/// read path. The **composer is the write surface (D-LV1) — insert-only**: a
/// single message field + send; there is deliberately **no edit, no delete,
/// no attachment affordance** (no edit/delete/attachments/read-receipts),
/// and the local-only demo note keeps the synthetic list honest (R1).
class MessageThreadDetailScreen extends StatelessWidget {
  const MessageThreadDetailScreen({
    required this.threadId,
    this.threadTitle,
    super.key,
  });

  final String threadId;

  /// The tapped row's title, passed by the list route (D-RT5/Q3: the title
  /// is already client-side — no embed is needed). Falls back to the
  /// localized generic title when absent (e.g. a deep link with no extra).
  final String? threadTitle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageThreadDetailCubit>(
      create: (BuildContext context) =>
          MessageThreadDetailCubit(serviceLocator<MessageGateway>()),
      child: _DetailSurface(threadId: threadId, threadTitle: threadTitle),
    );
  }
}

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
        child: BlocBuilder<MessageThreadDetailCubit, MessageThreadDetailState>(
          builder: (BuildContext context, MessageThreadDetailState state) {
            return ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                _resultsView(context, state, l10n, text, scheme),
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.messagesLocalOnlyNote,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // D-LV1: the insert-only composer — a message field + send. No edit,
      // no delete, no attachments (the write-path creep guard).
      bottomNavigationBar: SafeArea(
        child: _Composer(threadId: widget.threadId),
      ),
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
    return switch (state.messages) {
      ViewLoading() => const Padding(
        padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewEmpty() => empty,
      ViewError() => Padding(
        padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.messagesDetailError,
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
            TextButton(
              onPressed: () => cubit.load(widget.threadId),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      ViewOffline() || ViewUnauthorized() => empty,
      ViewSuccess<List<Message>>(data: final List<Message> messages) =>
        messages.isEmpty
            ? empty
            : Column(
                children: <Widget>[
                  for (final Message message in messages) ...<Widget>[
                    _MessageTile(message: message),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                ],
              ),
    };
  }
}

/// A read-only message row: author + sent date + body. **No tap affordance
/// and no trailing action** — the surface is read-only (D-RT5: no reply, no
/// forward, no delete in this slice).
class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // Same localized date shape as the list/vault surfaces (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(message.sentAt);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    message.authorDisplayName,
                    style: text.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  date,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(message.body, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

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
      builder: (BuildContext context, MessageThreadDetailState state) {
        final String draft = _controller.text.trim();
        final bool canSend = draft.isNotEmpty && !state.sending;
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
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(context),
                      ),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceSm),
                    IconButton.filled(
                      onPressed: canSend ? () => _send(context) : null,
                      tooltip: l10n.messageSend,
                      icon: state.sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
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
