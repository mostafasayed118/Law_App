import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'message_count_chip.dart';
import 'message_cubit.dart';
import 'message_state.dart';

part 'message_thread_tile.dart';

/// Thread-list surface (Phase 9, slice 9.1; Phase 12, slice 12.1).
///
/// A `/messages` route that loads the thread-metadata list from the
/// [MessageGateway] seam (the dev fake in env-less runs, owner decision
/// D-MSG2). Rows render the five D-MSG4 fields (title, matter reference,
/// participants, last-activity date, message count) and nothing else — no
/// message body, no preview, no send/reply (D-MSG1/D-MSG3). Phase 12 adds
/// the **reverse cross-link** (D-C1): a row whose provider query embedded
/// the matter title renders the compact "View matter" chip (D-C2), gated by
/// the `canViewMatters` nav hint (D-C4). The realtime slice (D-RT5) adds the
/// **thread-open affordance**: the whole row is tappable and opens the
/// read-only thread-detail surface (the first place message bodies appear —
/// the D-MSG1 consummation scoped to the real read path; no composer/send/
/// reply). The link target is the row's own `matter_id` (the embed carries
/// the title), so the screen no longer loads the full matter list just to
/// resolve `matterRef`; a row without the embed stays metadata-only (the
/// safe fallback). All copy is local-only — the synthetic list must never
/// read as real case communications (R1/D-MSG4).
class MessageListScreen extends StatelessWidget {
  const MessageListScreen({required this.capabilities, super.key});

  /// UX-only capability projection for the reverse cross-link (D-C4): the
  /// "View matter" chip renders only under [RoleCapability.canViewMatters].
  /// Navigation hint only — never authorization (the D-W5 posture).
  final RoleCapability capabilities;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageCubit>(
      create: (BuildContext context) =>
          MessageCubit(serviceLocator<MessageGateway>()),
      child: _ListSurface(capabilities: capabilities),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface({required this.capabilities});

  final RoleCapability capabilities;

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  @override
  void initState() {
    super.initState();
    // The cubit's initial state is already loading and the fake resolves
    // immediately, so the first frame settles straight into the list.
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
            return _resultsView(context, state, l10n, text, scheme);
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
    final bool localOnly = backendIsLocalOnly;
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.messagesEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    // Lazy list surface (audit 2026-09-21, M-20): the success arm used to be a
    // Column of every tile nested in a non-lazy ListView, so row culling never
    // applied. ViewStateList builds rows through SliverChildBuilderDelegate and
    // carries the local-only note itself, which is why it replaces the outer
    // ListView rather than nesting inside it.
    return ViewStateList<MessageThread>(
      state: state.threads,
      onRetry: cubit.load,
      tileBuilder: (BuildContext context, MessageThread thread) =>
          _MessageThreadTile(
            thread: thread,
            localOnly: localOnly,
            // E2E BUG-1 fix: list → thread detail is a forward navigation.
            onOpenThread: () => context.push(
              AppRoutes.messageThreadDetailFor(thread.id),
              extra: thread.title,
            ),
            onViewMatter: _matterTap(context, thread),
          ),
      empty: empty,
      errorCopy: l10n.messagesError,
      localOnlyNote: localOnly ? l10n.messagesLocalOnlyNote : '',
      listPadding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
    );
  }

  /// The reverse cross-link target for a row, or null when the row renders
  /// no affordance: the provider query must have returned both the matter id
  /// and its embedded title (the safe fallback when the embed is absent),
  /// AND the `canViewMatters` nav hint must be granted (D-C4).
  VoidCallback? _matterTap(BuildContext context, MessageThread thread) {
    if (!widget.capabilities.canViewMatters) {
      return null;
    }
    final String? matterId = thread.matterId;
    final String? matterTitle = thread.matterTitle;
    if (matterId == null || matterTitle == null) {
      return null;
    }
    // E2E BUG-1 fix: reverse cross-link is a forward navigation.
    return () => context.push(AppRoutes.matterDetail(matterId));
  }
}
