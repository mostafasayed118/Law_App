import 'dart:async';

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
    return switch (state.results) {
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
              l10n.searchError,
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
            TextButton(
              onPressed: () => cubit.search(state.query),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      // The sealed ViewState set also carries offline/unauthorized variants
      // (shared vocabulary); a synthetic search has neither state, so both
      // render the same empty copy rather than a distinct offline surface.
      ViewOffline() || ViewUnauthorized() => empty,
      ViewSuccess<SearchResults>(data: final SearchResults results) => _grouped(
        context,
        results,
        l10n,
        empty,
      ),
    };
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
        _GroupSection(
          title: l10n.matterTitle,
          children: <Widget>[
            for (final Matter matter in results.matters) ...<Widget>[
              _MatterResultTile(
                matter: matter,
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
        _GroupSection(
          title: l10n.vaultTitle,
          children: <Widget>[
            for (final Document document in results.documents) ...<Widget>[
              _DocumentResultTile(
                document: document,
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
        _GroupSection(
          title: l10n.messagesTitle,
          children: <Widget>[
            for (final MessageThread thread in results.threads) ...<Widget>[
              _ThreadResultTile(
                thread: thread,
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
        _GroupSection(
          title: l10n.discoveryTitle,
          children: <Widget>[
            for (final Attorney attorney in results.attorneys) ...<Widget>[
              _AttorneyResultTile(
                attorney: attorney,
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

/// One capability-gated result group: a header plus its metadata rows.
class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        ...children,
      ],
    );
  }
}

/// A matter result row — a navigation hint into the read-only details route
/// (D-S3); renders the same D-M4 metadata fields as the matter list surface.
class _MatterResultTile extends StatelessWidget {
  const _MatterResultTile({required this.matter, required this.onTap});

  final Matter matter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.folder_outlined,
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
                      matter.title,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${practiceAreaLabel(l10n, matter.practiceArea)} · ${matter.assignedAttorneyName}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    // The chip wraps beneath the metadata line (the roster
                    // pattern) so the row never overflows at narrow widths;
                    // the chevron stays as the trailing navigation
                    // affordance.
                    Wrap(
                      spacing: LegalHubTheme.spaceSm,
                      runSpacing: LegalHubTheme.spaceSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        MatterStatusChip(
                          label: matterStatusLabel(l10n, matter.status),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceSm),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// A document-metadata result row — a navigation hint into the read-only
/// vault route (D-S3); renders the same D-V4 fields as the vault surface,
/// never a body or preview.
class _DocumentResultTile extends StatelessWidget {
  const _DocumentResultTile({required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String date = formatMediumDate(l10n, document.createdAt);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.folder_outlined,
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
                      document.title,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${documentTypeLabel(l10n, document.type)} · $date',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    // The chip wraps beneath the metadata line (the roster
                    // pattern) so the row never overflows at narrow widths;
                    // the chevron stays as the trailing navigation
                    // affordance.
                    Wrap(
                      spacing: LegalHubTheme.spaceSm,
                      runSpacing: LegalHubTheme.spaceSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        DocumentTypeChip(
                          label: documentTypeLabel(l10n, document.type),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceSm),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thread-metadata result row — a navigation hint into the read-only
/// messages route (D-S3); renders the same D-MSG4 fields as the messages
/// surface, never a message body or preview.
class _ThreadResultTile extends StatelessWidget {
  const _ThreadResultTile({required this.thread, required this.onTap});

  final MessageThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String date = formatMediumDate(l10n, thread.lastActivityAt);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    // The chip wraps beneath the metadata line (the roster
                    // pattern) so the row never overflows at narrow widths;
                    // the chevron stays as the trailing navigation
                    // affordance.
                    Wrap(
                      spacing: LegalHubTheme.spaceSm,
                      runSpacing: LegalHubTheme.spaceSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        MessageCountChip(
                          label: l10n.messagesMessageCount(thread.messageCount),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceSm),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// An attorney result row — a navigation hint into the read-only profile
/// route (D-S3); renders the same D-A4 fields as the discovery surface.
class _AttorneyResultTile extends StatelessWidget {
  const _AttorneyResultTile({required this.attorney, required this.onTap});

  final Attorney attorney;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  attorney.name.isEmpty
                      ? '?'
                      : attorney.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      attorney.name,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${practiceAreaLabel(l10n, attorney.practiceArea)} · ${attorney.locale}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
