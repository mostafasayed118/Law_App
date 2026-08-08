import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/message.dart';
import '../domain/message_gateway.dart';
import 'message_thread_detail_cubit.dart';
import 'message_thread_detail_state.dart';

/// Read-only thread-detail surface (sixth §14 un-deferral, realtime slice
/// D-RT5).
///
/// The **first thread-open affordance**: tapping a thread row in the list
/// opens this screen, which loads that thread's message rows from the
/// [MessageGateway] seam (the dev fake in env-less runs, the env-gated
/// Supabase implementation in configured builds) and renders them read-only.
/// This is the surface where message **bodies** first appear — the D-MSG1
/// consummation, scoped to the real read path. There is deliberately **no
/// composer, no send/reply, no attachment affordance** (D-RT5 — the slice
/// has no write grant), and the local-only demo note keeps the synthetic
/// list honest (R1).
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
    // Load the thread's messages on open (matches the list/matter pattern);
    // the cubit's initial state is already loading, and the fake resolves
    // immediately, so the first frame settles straight into the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessageThreadDetailCubit>().load(widget.threadId);
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
