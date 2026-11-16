import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_bookmark.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/domain/reading_history_entry.dart';
import 'package:legalhub/features/library/presentation/highlight_palette.dart';
import 'package:legalhub/features/library/presentation/library_bookmarks_cubit.dart';
import 'package:legalhub/features/library/presentation/library_bookmarks_state.dart';
import 'package:legalhub/features/library/presentation/library_highlights_cubit.dart';
import 'package:legalhub/features/library/presentation/library_highlights_state.dart';
import 'package:legalhub/features/library/presentation/library_history_cubit.dart';
import 'package:legalhub/features/library/presentation/library_history_state.dart';
import 'package:legalhub/features/library/presentation/sample_badge.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// Everything the signed-in reader has saved (ADR-0010): bookmarks, highlights
/// and recent reading, in three tabs.
///
/// The tabs share one scaffold because they are three views of the same thing —
/// "my library" — and a separate route per tab would make the back stack lie
/// about where the reader is.
class LibrarySavedScreen extends StatelessWidget {
  const LibrarySavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.librarySavedTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.librarySavedBookmarks),
              Tab(text: l10n.librarySavedHighlights),
              Tab(text: l10n.librarySavedHistory),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: <Widget>[
              _BookmarksTab(),
              _HighlightsTab(),
              _HistoryTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CubitListSurface<
      LibraryBookmarksCubit,
      LibraryBookmarksState,
      LegalBookmark
    >(
      createCubit: () =>
          LibraryBookmarksCubit(serviceLocator<LibraryUserDataGateway>()),
      project: (LibraryBookmarksState state) => state.bookmarks,
      load: (LibraryBookmarksCubit cubit) => cubit.load(),
      errorCopy: l10n.libraryError,
      localOnlyNote: l10n.libraryLocalOnlyNote,
      empty: (BuildContext context, LibraryBookmarksState state) =>
          AppCenteredMessage(text: l10n.librarySavedEmptyBookmarks),
      tileBuilder: (BuildContext context, LegalBookmark bookmark) => _SavedTile(
        title: bookmark.documentTitleAr,
        subtitle: l10n.libraryArticleNumberLabel(bookmark.articleNumber),
        trailingNote: bookmark.note,
        isSample: bookmark.isSample,
        onTap: () =>
            context.push(AppRoutes.libraryArticleFor(bookmark.articleId)),
      ),
    );
  }
}

class _HighlightsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CubitListSurface<
      LibraryHighlightsCubit,
      LibraryHighlightsState,
      LegalHighlight
    >(
      createCubit: () =>
          LibraryHighlightsCubit(serviceLocator<LibraryUserDataGateway>()),
      project: (LibraryHighlightsState state) => state.highlights,
      load: (LibraryHighlightsCubit cubit) => cubit.load(),
      errorCopy: l10n.libraryError,
      localOnlyNote: l10n.libraryLocalOnlyNote,
      empty: (BuildContext context, LibraryHighlightsState state) =>
          AppCenteredMessage(text: l10n.librarySavedEmptyHighlights),
      tileBuilder: (BuildContext context, LegalHighlight highlight) =>
          _HighlightTile(highlight: highlight),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocProvider<LibraryHistoryCubit>(
      create: (BuildContext context) =>
          LibraryHistoryCubit(serviceLocator<LibraryUserDataGateway>()),
      child: BlocConsumer<LibraryHistoryCubit, LibraryHistoryState>(
        listenWhen: (LibraryHistoryState a, LibraryHistoryState b) =>
            b.lastError != null && a.lastError != b.lastError,
        listener: (BuildContext context, LibraryHistoryState state) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.libraryError)));
          context.read<LibraryHistoryCubit>().acknowledgeError();
        },
        builder: (BuildContext context, LibraryHistoryState state) {
          final bool hasRows =
              state.history is ViewSuccess<List<ReadingHistoryEntry>> &&
              (state.history as ViewSuccess<List<ReadingHistoryEntry>>)
                  .data
                  .isNotEmpty;
          return Column(
            children: <Widget>[
              if (hasRows)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      LegalHubTheme.marginMobile,
                      LegalHubTheme.spaceSm,
                      LegalHubTheme.marginMobile,
                      0,
                    ),
                    child: TextButton.icon(
                      onPressed: state.clearing
                          ? null
                          : () => _confirmClear(context),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(l10n.librarySavedClearHistory),
                    ),
                  ),
                ),
              Expanded(child: _HistoryList(state: state)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LibraryHistoryCubit cubit = context.read<LibraryHistoryCubit>();
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.librarySavedClearHistory,
      content: Text(l10n.librarySavedClearHistoryConfirm),
      confirmLabel: l10n.librarySavedClearHistory,
    );
    if (confirmed == true) {
      await cubit.clear();
    }
  }
}

/// The history list itself, kept separate so the clear button can sit above it
/// without duplicating the four state arms.
class _HistoryList extends StatefulWidget {
  const _HistoryList({required this.state});

  final LibraryHistoryState state;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LibraryHistoryCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ViewStateList<ReadingHistoryEntry>(
      state: widget.state.history,
      onRetry: () => context.read<LibraryHistoryCubit>().load(),
      errorCopy: l10n.libraryError,
      localOnlyNote: l10n.libraryLocalOnlyNote,
      empty: AppCenteredMessage(text: l10n.librarySavedEmptyHistory),
      tileBuilder: (BuildContext context, ReadingHistoryEntry entry) =>
          _SavedTile(
            title: entry.documentTitleAr,
            subtitle: l10n.libraryArticleNumberLabel(entry.articleNumber),
            trailingNote: null,
            isSample: entry.isSample,
            leading: LabelChip(
              label: '${entry.readCount}',
              background: Theme.of(context).colorScheme.surfaceContainerHighest,
              foreground: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () =>
                context.push(AppRoutes.libraryArticleFor(entry.articleId)),
          ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.highlight});

  final LegalHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.libraryArticleFor(highlight.articleId)),
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${highlight.documentTitleAr} · '
                '${l10n.libraryArticleNumberLabel(highlight.articleNumber)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: LegalHubTheme.spaceXs),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: LegalHubTheme.spaceSm,
                  vertical: LegalHubTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: HighlightPalette.background(context, highlight.color),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(LegalHubTheme.radiusSm),
                  ),
                ),
                child: Text(
                  '“${highlight.quote}”',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                ),
              ),
              if (highlight.isStale) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  l10n.libraryHighlightStaleTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.error),
                ),
              ],
              if (highlight.note != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  highlight.note!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (highlight.isSample) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SampleBadge(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.title,
    required this.subtitle,
    required this.trailingNote,
    required this.isSample,
    required this.onTap,
    this.leading,
  });

  final String title;
  final String subtitle;
  final String? trailingNote;
  final bool isSample;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    const SizedBox(width: LegalHubTheme.spaceSm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LegalHubTheme.space2xs),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (trailingNote != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  trailingNote!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (isSample) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SampleBadge(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
