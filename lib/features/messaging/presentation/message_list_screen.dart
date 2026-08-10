import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../../matters/domain/matter_title_resolver.dart';
import '../../matters/presentation/matter_cubit.dart';
import '../../matters/presentation/matter_link_chip.dart';
import '../../matters/presentation/matter_state.dart';
import '../domain/message_gateway.dart';
import '../domain/message_thread.dart';
import 'message_count_chip.dart';
import 'message_cubit.dart';
import 'message_state.dart';

/// Thread-list surface (Phase 9, slice 9.1; Phase 12, slice 12.1).
///
/// A `/messages` route that loads the thread-metadata list from the
/// [MessageGateway] seam (the dev fake in env-less runs, owner decision
/// D-MSG2). Rows render the five D-MSG4 fields (title, matter reference,
/// participants, last-activity date, message count) and nothing else — no
/// message body, no preview, no send/reply (D-MSG1/D-MSG3). Phase 12 adds
/// the **reverse cross-link** (D-C1): a row whose `matterRef` resolves to a
/// known synthetic matter renders the compact "View matter" chip (D-C2),
/// gated by the `canViewMatters` nav hint (D-C4). The realtime slice (D-RT5)
/// adds the **thread-open affordance**: the whole row is tappable and opens
/// the read-only thread-detail surface (the first place message bodies
/// appear — the D-MSG1 consummation scoped to the real read path; no
/// composer/send/reply). Resolution is title-keyed and client-side against
/// the loaded synthetic matter list (D-C3, the D-M5 discipline in reverse);
/// rows whose `matterRef` does not resolve stay metadata-only. All copy is
/// local-only — the synthetic list must never read as real case
/// communications (R1/D-MSG4).
class MessageListScreen extends StatelessWidget {
  const MessageListScreen({required this.capabilities, super.key});

  /// UX-only capability projection for the reverse cross-link (D-C4): the
  /// "View matter" chip renders only under [RoleCapability.canViewMatters].
  /// Navigation hint only — never authorization (the D-W5 posture).
  final RoleCapability capabilities;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<MessageCubit>(
          create: (BuildContext context) =>
              MessageCubit(serviceLocator<MessageGateway>()),
        ),
        // Loads the synthetic matter list alongside the threads so each
        // row's matterRef can be resolved client-side (D-C3).
        BlocProvider<MatterCubit>(
          create: (BuildContext context) =>
              MatterCubit(serviceLocator<MatterGateway>()),
        ),
      ],
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
    // Load both synthetic lists on open (matches the discovery/matter
    // pattern): the cubits' initial states are already loading, and the
    // fakes resolve immediately, so the first frame settles straight into
    // the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessageCubit>().load();
      context.read<MatterCubit>().load();
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
            return BlocBuilder<MatterCubit, MatterState>(
              builder: (BuildContext context, MatterState matterState) {
                // The loaded matter list feeds the title-keyed resolution
                // (D-C3); empty until the matter list loads, so tiles render
                // without a chip until then (the fakes resolve immediately).
                // Deliberate degradation: if the matter load ever fails, the
                // messages list still renders its threads and the reverse
                // link simply disappears — a nav hint, not a second error
                // state.
                final List<Matter> matters = switch (matterState.matters) {
                  ViewSuccess<List<Matter>>(data: final List<Matter> list) =>
                    list,
                  ViewLoading() ||
                  ViewEmpty() ||
                  ViewError() ||
                  ViewOffline() ||
                  ViewUnauthorized() => const <Matter>[],
                };
                return ListView(
                  padding: const EdgeInsetsDirectional.all(
                    LegalHubTheme.marginMobile,
                  ),
                  children: <Widget>[
                    _resultsView(context, state, matters, l10n, text, scheme),
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
            );
          },
        ),
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    MessageState state,
    List<Matter> matters,
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
    return ViewStateSwitch<List<MessageThread>>(
      state: state.threads,
      onRetry: cubit.load,
      builder: (BuildContext context, List<MessageThread> threads) =>
          threads.isEmpty
          ? empty
          : Column(
              children: <Widget>[
                for (final MessageThread thread in threads) ...<Widget>[
                  _MessageThreadTile(
                    thread: thread,
                    onOpenThread: () => context.go(
                      AppRoutes.messageThreadDetailFor(thread.id),
                      extra: thread.title,
                    ),
                    onViewMatter: _matterTap(context, thread, matters),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceSm),
                ],
              ],
            ),
      empty: empty,
      errorCopy: l10n.messagesError,
    );
  }

  /// The reverse cross-link target for a row, or null when the row renders
  /// no affordance: the `matterRef` must resolve to a known synthetic matter
  /// (D-C3) AND the `canViewMatters` nav hint must be granted (D-C4).
  VoidCallback? _matterTap(
    BuildContext context,
    MessageThread thread,
    List<Matter> matters,
  ) {
    if (!widget.capabilities.canViewMatters) {
      return null;
    }
    final Matter? matter = resolveMatterByTitle(matters, thread.matterRef);
    if (matter == null) {
      return null;
    }
    return () => context.go(AppRoutes.matterDetail(matter.id));
  }
}

/// A read-only metadata row with **exactly two tap targets**: the whole-row
/// thread-open affordance (the first thread-open in the app, D-RT5 — tap a
/// thread row → the read-only detail surface) and, on resolved rows under
/// the `canViewMatters` hint, the compact `MatterLinkChip` reverse
/// cross-link (D-C2/D-C4). No chevron and no other trailing action — the
/// row stays metadata-only otherwise (D-MSG1).
class _MessageThreadTile extends StatelessWidget {
  const _MessageThreadTile({
    required this.thread,
    required this.onOpenThread,
    required this.onViewMatter,
  });

  final MessageThread thread;

  /// The whole-row thread-open tap → the read-only thread-detail surface
  /// (D-RT5). Always non-null for a listed row.
  final VoidCallback onOpenThread;

  /// The reverse cross-link tap, or null when the row renders no chip
  /// (unresolved `matterRef` or the nav hint not granted, D-C2/D-C4).
  ///
  /// Null-checked with a `case` pattern below: public final fields do not
  /// promote in Dart 3.2, so a plain `!= null` check would not narrow the
  /// type here.
  final VoidCallback? onViewMatter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Same localized date shape as the vault/details surfaces (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = formatMediumDate(l10n, thread.lastActivityAt);
    return AppTile(
      icon: Icons.forum_outlined,
      title: thread.title,
      subtitles: <String>['${thread.participants.join(', ')} · $date'],
      // The chips wrap beneath the metadata line (the roster pattern); the
      // link chip stays a secondary tap target in the row (D-C2). The row
      // stays chevron-free (D-MSG1).
      trailing: Wrap(
        spacing: LegalHubTheme.spaceSm,
        runSpacing: LegalHubTheme.spaceSm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          MessageCountChip(
            label: l10n.messagesMessageCount(thread.messageCount),
          ),
          if (onViewMatter case final VoidCallback tap)
            MatterLinkChip(onTap: tap),
        ],
      ),
      onTap: onOpenThread,
      showChevron: false,
    );
  }
}
