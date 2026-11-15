import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/responsive/breakpoints.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'message_count_chip.dart';
import 'message_cubit.dart';
import 'message_state.dart';
import 'message_thread_detail_screen.dart';

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
/// reply on the phone; the detail's composer remains insert-only).
///
/// On expanded windows (≥840dp) the screen is a two-pane master/detail: the
/// thread list stays on the left and the selected transcript + composer
/// render on the right. Compact/medium windows keep push navigation.
class MessageListScreen extends StatefulWidget {
  const MessageListScreen({
    required this.capabilities,
    this.initialSelectedThreadId,
    this.initialSelectedThreadTitle,
    super.key,
  });

  /// UX-only capability projection for the reverse cross-link (D-C4): the
  /// "View matter" chip renders only under [RoleCapability.canViewMatters].
  /// Navigation hint only — never authorization (the D-W5 posture).
  final RoleCapability capabilities;

  /// Deep-link projection: `/messages/:id` on an expanded window opens the
  /// two-pane with this thread selected.
  final String? initialSelectedThreadId;

  /// The deep-linked thread's title (route `extra` when present).
  final String? initialSelectedThreadTitle;

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  String? _selectedThreadId;
  String? _selectedThreadTitle;

  @override
  void initState() {
    super.initState();
    _selectedThreadId = widget.initialSelectedThreadId;
    _selectedThreadTitle = widget.initialSelectedThreadTitle;
  }

  @override
  void didUpdateWidget(MessageListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedThreadId != oldWidget.initialSelectedThreadId) {
      _selectedThreadId = widget.initialSelectedThreadId;
      _selectedThreadTitle = widget.initialSelectedThreadTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Device-class decision on the WINDOW width, not the capped content
    // width: at 1024 with a text-scaled rail the content column is ~812,
    // which would otherwise flip the two-pane off on a desktop window.
    final bool twoPane =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return BlocProvider<MessageCubit>(
      create: (BuildContext context) =>
          MessageCubit(serviceLocator<MessageGateway>()),
      child: twoPane
          ? _buildTwoPane(context, l10n)
          : _ListSurface(capabilities: widget.capabilities),
    );
  }

  Widget _buildTwoPane(BuildContext context, AppLocalizations l10n) {
    final String? selectedId = _selectedThreadId;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: SafeArea(
        child: TwoPane(
          list: _ListSurface(
            embedded: true,
            capabilities: widget.capabilities,
            selectedThreadId: selectedId,
            onSelectThread: (String id, String title) => setState(() {
              _selectedThreadId = id;
              _selectedThreadTitle = title;
            }),
          ),
          detail: selectedId == null
              ? AppCenteredMessage(text: l10n.messageThreadDetailTitle)
              : MessageThreadDetailScreen(
                  key: ValueKey<String>(selectedId),
                  threadId: selectedId,
                  threadTitle: _selectedThreadTitle,
                  embedded: true,
                ),
        ),
      ),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface({
    required this.capabilities,
    this.embedded = false,
    this.selectedThreadId,
    this.onSelectThread,
  });

  final RoleCapability capabilities;

  /// True inside the two-pane: the pane owns no Scaffold/AppBar.
  final bool embedded;

  /// The thread rendered by the detail pane (two-pane only).
  final String? selectedThreadId;

  /// Selection callback for two-pane. Null restores push navigation.
  final void Function(String id, String title)? onSelectThread;

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  /// Guards the one-time auto-selection of the first loaded thread.
  bool _autoSelected = false;

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
    final Widget body = SafeArea(
      child: BlocBuilder<MessageCubit, MessageState>(
        builder: (BuildContext context, MessageState state) {
          _maybeAutoSelect(state);
          return _resultsView(context, state, l10n, text, scheme);
        },
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: body,
    );
  }

  /// Auto-selects the first loaded thread once per list mount.
  void _maybeAutoSelect(MessageState state) {
    if (_autoSelected ||
        widget.onSelectThread == null ||
        widget.selectedThreadId != null) {
      return;
    }
    if (state.threads case ViewSuccess<List<MessageThread>>(
      data: final List<MessageThread> threads,
    ) when threads.isNotEmpty) {
      _autoSelected = true;
      final MessageThread first = threads.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSelectThread!(first.id, first.title);
        }
      });
    }
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
            // Two-pane: select in place. Compact/medium: forward navigation
            // (E2E BUG-1 fix).
            onOpenThread: widget.onSelectThread == null
                ? () => context.push(
                    AppRoutes.messageThreadDetailFor(thread.id),
                    extra: thread.title,
                  )
                : () => widget.onSelectThread!(thread.id, thread.title),
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
