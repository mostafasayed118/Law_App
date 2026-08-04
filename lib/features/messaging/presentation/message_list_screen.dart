import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/message_gateway.dart';
import '../domain/message_thread.dart';
import 'message_count_chip.dart';
import 'message_cubit.dart';
import 'message_state.dart';

/// Thread-list surface (Phase 9, slice 9.1).
///
/// A `/messages` route that loads the thread-metadata list from the
/// [MessageGateway] seam (the dev fake in env-less runs, owner decision
/// D-MSG2). **Thread metadata only** — rows render the five D-MSG4 fields
/// (title, matter reference, participants, last-activity date, message
/// count) and nothing else: no message body, no preview, no send/reply, no
/// thread-open affordance, and no detail route (D-MSG1/D-MSG3). Rows are
/// deliberately NOT tap targets. All copy is local-only — the synthetic list
/// must never read as real case communications (R1/D-MSG4).
class MessageListScreen extends StatelessWidget {
  const MessageListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageCubit>(
      create: (BuildContext context) =>
          MessageCubit(serviceLocator<MessageGateway>()),
      child: const _ListSurface(),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface();

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic metadata list on open (matches the vault/matter
    // pattern): the cubit's initial state is already loading, and the fake
    // resolves immediately, so the first frame settles straight into the
    // list.
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: SafeArea(
        child: BlocBuilder<MessageCubit, MessageState>(
          builder: (BuildContext context, MessageState state) {
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
    MessageState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final MessageCubit cubit = context.read<MessageCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.messagesEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return switch (state.threads) {
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
              l10n.messagesError,
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
            TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
          ],
        ),
      ),
      // The sealed ViewState set also carries offline/unauthorized variants
      // (shared vocabulary); a synthetic list has neither state, so both
      // render the same empty copy rather than a distinct offline surface.
      ViewOffline() || ViewUnauthorized() => empty,
      ViewSuccess<List<MessageThread>>(
        data: final List<MessageThread> threads,
      ) =>
        threads.isEmpty
            ? empty
            : Column(
                children: <Widget>[
                  for (final MessageThread thread in threads) ...<Widget>[
                    _MessageThreadTile(thread: thread),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                ],
              ),
    };
  }
}

/// A read-only metadata row. Carries **no onTap, no InkWell, no chevron,
/// and no trailing action** — there is no thread-detail route and rows must
/// not read as tappable (D-MSG1/D-MSG3 body-less line). The AC-2 pin asserts
/// these absences structurally.
class _MessageThreadTile extends StatelessWidget {
  const _MessageThreadTile({required this.thread});

  final MessageThread thread;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // Same localized date shape as the vault/details surfaces (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(thread.lastActivityAt);
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
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.forum_outlined,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    thread.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${thread.participants.join(', ')} · $date',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceSm),
            MessageCountChip(
              label: l10n.messagesMessageCount(thread.messageCount),
            ),
          ],
        ),
      ),
    );
  }
}
