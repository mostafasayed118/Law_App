import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../../discovery/domain/attorney.dart';
import '../../discovery/domain/attorney_gateway.dart';
import '../../documents/domain/document.dart';
import '../../documents/domain/document_gateway.dart';
import '../../documents/presentation/document_labels.dart';
import '../../documents/presentation/document_type_chip.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../../matters/presentation/matter_labels.dart' show matterStatusLabel;
import '../../matters/presentation/matter_status_chip.dart';
import '../../messaging/domain/message_gateway.dart';
import '../../messaging/domain/message_thread.dart';
import '../../messaging/presentation/message_count_chip.dart';
import '../domain/search_results.dart';
import 'search_cubit.dart';
import 'search_state.dart';

/// Unified-search surface (Phase 11, slice 11.1, owner decisions D-S2/D-S3/D-S4).
///
/// A `/search?q=…` route that seeds the [SearchCubit] with the `q` query
/// param and lets the user refine with a debounced field. Results render as
/// capability-gated groups (D-S2 — nav hints only, never authorization) and
/// every row navigates to an **existing read-only route** (D-S3): matter →
/// `/matters/:id`, document → `/vault`, thread → `/messages`, attorney →
/// `/discovery/:id`. **Metadata only**: rows render the same non-PII fields
/// as the standalone surfaces — never a document body, message text,
/// thread-open affordance, preview, or send/reply (the Phase 8/9 AC-2
/// absence lines, D-S3). An empty query shows the no-query state, not
/// results (D-S4), and the surface carries the local-only demo note (D-S5).
class SearchScreen extends StatelessWidget {
  const SearchScreen({
    required this.capabilities,
    this.initialQuery = '',
    super.key,
  });

  /// UX-only capability projection (the D-W5 posture) injected by the router
  /// from the session role; a group renders only when its capability is
  /// granted.
  final RoleCapability capabilities;

  /// The `q` query param; a non-blank value seeds the first search on open.
  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    // Feature-scoped cubit composed from the four gateway seams (slice 11.0);
    // the surface below reads it via BlocBuilder.
    return BlocProvider<SearchCubit>(
      create: (BuildContext context) => SearchCubit(
        serviceLocator<MatterGateway>(),
        serviceLocator<DocumentGateway>(),
        serviceLocator<MessageGateway>(),
        serviceLocator<AttorneyGateway>(),
      ),
      child: _SearchSurface(
        capabilities: capabilities,
        initialQuery: initialQuery,
      ),
    );
  }
}

/// The interactive surface — a child of the [SearchCubit] provider so its
/// state can read the cubit on open (the vault/matters pattern).
class _SearchSurface extends StatefulWidget {
  const _SearchSurface({
    required this.capabilities,
    required this.initialQuery,
  });

  final RoleCapability capabilities;
  final String initialQuery;

  @override
  State<_SearchSurface> createState() => _SearchSurfaceState();
}

class _SearchSurfaceState extends State<_SearchSurface> {
  late final TextEditingController _queryController = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Seed the first search from the `q` query param after the first frame
    // (the vault/matters pattern); a blank param stays in the no-query state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.initialQuery.trim().isNotEmpty) {
        context.read<SearchCubit>().search(widget.initialQuery);
      }
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<SearchCubit>().search(value);
      }
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    context.read<SearchCubit>().search(value);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: SafeArea(
        child: BlocBuilder<SearchCubit, SearchState>(
          builder: (BuildContext context, SearchState state) {
            return ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                LegalHubTextField(
                  controller: _queryController,
                  hint: l10n.searchPlaceholder,
                  prefixIcon: Icons.search,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                ),
                const SizedBox(height: LegalHubTheme.spaceLg),
                _resultsView(context, state, l10n, text, scheme),
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.searchLocalOnlyNote,
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
    SearchState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final SearchCubit cubit = context.read<SearchCubit>();
    final Widget noQuery = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.searchNoQuery,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.searchEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    // A blank/whitespace query shows the no-query state, not results (D-S4).
    if (state.isNoQuery) {
      return noQuery;
    }
    return ViewStateSwitch<SearchResults>(
      state: state.results,
      onRetry: () => cubit.search(state.query),
      builder: (BuildContext context, SearchResults results) =>
          _grouped(context, results, l10n, empty),
      empty: empty,
      errorCopy: l10n.searchError,
    );
  }

  Widget _grouped(
    BuildContext context,
    SearchResults results,
    AppLocalizations l10n,
    Widget empty,
  ) {
    final List<Widget> sections = <Widget>[];
    if (widget.capabilities.canViewMatters && results.matters.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.matterTitle,
          children: <Widget>[
            for (final Matter matter in results.matters) ...<Widget>[
              AppTile(
                icon: Icons.folder_outlined,
                title: matter.title,
                subtitles: <String>[
                  '${practiceAreaLabel(l10n, matter.practiceArea)} · ${matter.assignedAttorneyName}',
                ],
                trailing: Wrap(
                  spacing: LegalHubTheme.spaceSm,
                  runSpacing: LegalHubTheme.spaceSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    MatterStatusChip(
                      label: matterStatusLabel(l10n, matter.status),
                    ),
                  ],
                ),
                onTap: () => context.go(AppRoutes.matterDetail(matter.id)),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    if (widget.capabilities.canViewDocuments && results.documents.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.vaultTitle,
          children: <Widget>[
            for (final Document document in results.documents) ...<Widget>[
              AppTile(
                icon: Icons.folder_outlined,
                title: document.title,
                subtitles: <String>[
                  '${documentTypeLabel(l10n, document.type)} · ${formatMediumDate(l10n, document.createdAt)}',
                ],
                trailing: Wrap(
                  spacing: LegalHubTheme.spaceSm,
                  runSpacing: LegalHubTheme.spaceSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    DocumentTypeChip(
                      label: documentTypeLabel(l10n, document.type),
                    ),
                  ],
                ),
                onTap: () => context.go(AppRoutes.vault),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    if (widget.capabilities.canViewMessages && results.threads.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.messagesTitle,
          children: <Widget>[
            for (final MessageThread thread in results.threads) ...<Widget>[
              AppTile(
                icon: Icons.forum_outlined,
                title: thread.title,
                subtitles: <String>[
                  '${thread.participants.join(', ')} · ${formatMediumDate(l10n, thread.lastActivityAt)}',
                ],
                trailing: Wrap(
                  spacing: LegalHubTheme.spaceSm,
                  runSpacing: LegalHubTheme.spaceSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    MessageCountChip(
                      label: l10n.messagesMessageCount(thread.messageCount),
                    ),
                  ],
                ),
                onTap: () => context.go(AppRoutes.messages),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    if (widget.capabilities.canViewAttorneyDiscovery &&
        results.attorneys.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.discoveryTitle,
          children: <Widget>[
            for (final Attorney attorney in results.attorneys) ...<Widget>[
              AppTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    attorney.name.isEmpty
                        ? '?'
                        : attorney.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: attorney.name,
                subtitles: <String>[
                  '${practiceAreaLabel(l10n, attorney.practiceArea)} · ${attorney.locale}',
                ],
                onTap: () => context.go(AppRoutes.attorneyProfile(attorney.id)),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    // Every group hidden by capability (or every subset empty) renders the
    // same localized empty copy rather than a blank surface.
    if (sections.isEmpty) {
      return empty;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < sections.length; i++) ...<Widget>[
          sections[i],
          if (i < sections.length - 1)
            const SizedBox(height: LegalHubTheme.spaceLg),
        ],
      ],
    );
  }
}
