import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/domain/library_user_data_gateway.dart';
import 'package:legalhub/features/library/presentation/article_user_data_cubit.dart';
import 'package:legalhub/features/library/presentation/article_user_data_state.dart';
import 'package:legalhub/features/library/presentation/highlight_editor_sheet.dart';
import 'package:legalhub/features/library/presentation/highlighted_body.dart';
import 'package:legalhub/features/library/presentation/library_article_cubit.dart';
import 'package:legalhub/features/library/presentation/library_article_state.dart';
import 'package:legalhub/features/library/presentation/sample_badge.dart';
import 'package:legalhub/l10n/app_error_label.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The article reader (ADR-0009, ADR-0010).
///
/// Reads the article through [LibraryArticleCubit] and the reader's own data
/// (bookmark + highlights) through [ArticleUserDataCubit]. Two cubits rather than
/// one: the article is global and identical for everyone, the reader's marks are
/// not, and a single cubit would have to reload the article every time a
/// highlight was added.
class LibraryArticleScreen extends StatelessWidget {
  const LibraryArticleScreen({
    required this.articleId,
    this.embedded = false,
    super.key,
  });

  final String articleId;

  /// True when hosted inside a two-pane detail slot.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LibraryArticleCubit>(
          create: (BuildContext context) =>
              LibraryArticleCubit(serviceLocator<LibraryGateway>())
                ..load(articleId),
        ),
        BlocProvider<ArticleUserDataCubit>(
          create: (BuildContext context) =>
              ArticleUserDataCubit(serviceLocator<LibraryUserDataGateway>())
                ..load(articleId),
        ),
      ],
      child: _LibraryArticleBody(articleId: articleId, embedded: embedded),
    );
  }
}

class _LibraryArticleBody extends StatefulWidget {
  const _LibraryArticleBody({required this.articleId, required this.embedded});

  final String articleId;
  final bool embedded;

  @override
  State<_LibraryArticleBody> createState() => _LibraryArticleBodyState();
}

class _LibraryArticleBodyState extends State<_LibraryArticleBody> {
  /// One history write per article view, not one per rebuild.
  bool _recorded = false;

  void _recordIfNeeded() {
    if (_recorded) {
      return;
    }
    _recorded = true;
    // Silent by design: a failed history write must never interrupt reading.
    context.read<ArticleUserDataCubit>().recordReading();
  }

  void _showError(AppError error) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appErrorLabel(l10n, error, fallback: error.userMessage)),
      ),
    );
    context.read<ArticleUserDataCubit>().acknowledgeError();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<ArticleUserDataCubit, ArticleUserDataState>(
          listenWhen: (ArticleUserDataState a, ArticleUserDataState b) =>
              b.lastError != null && a.lastError != b.lastError,
          listener: (BuildContext context, ArticleUserDataState state) {
            final AppError? error = state.lastError;
            if (error != null) {
              _showError(error);
            }
          },
        ),
        BlocListener<LibraryArticleCubit, LibraryArticleState>(
          listenWhen: (LibraryArticleState a, LibraryArticleState b) =>
              a.detail is! ViewSuccess && b.detail is ViewSuccess,
          listener: (BuildContext context, LibraryArticleState state) {
            _recordIfNeeded();
          },
        ),
      ],
      child: BlocBuilder<LibraryArticleCubit, LibraryArticleState>(
        builder: (BuildContext context, LibraryArticleState state) {
          final Widget content = switch (state.detail) {
            ViewSuccess<LegalArticleDetail>(
              data: final LegalArticleDetail detail,
            ) =>
              _ArticleReader(detail: detail, embedded: widget.embedded),
            final ViewState<LegalArticleDetail> other => Center(
              child: SingleChildScrollView(
                child: ViewStateView<LegalArticleDetail>(
                  state: other,
                  errorFallback: l10n.libraryArticleMissing,
                  onRetry: other is ViewError<LegalArticleDetail>
                      ? () => context.read<LibraryArticleCubit>().load(
                          widget.articleId,
                        )
                      : null,
                ),
              ),
            ),
          };

          if (widget.embedded) {
            return content;
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.libraryTitle),
              actions: <Widget>[_BookmarkAction()],
            ),
            body: SafeArea(child: content),
          );
        },
      ),
    );
  }
}

/// The app-bar bookmark toggle.
///
/// Optimistic: the icon flips on tap and is put back by the cubit if the server
/// refuses. Disabled while a toggle is in flight, because two racing toggles
/// would settle in whichever order the responses arrived.
class _BookmarkAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<ArticleUserDataCubit, ArticleUserDataState>(
      builder: (BuildContext context, ArticleUserDataState state) {
        return IconButton(
          tooltip: state.bookmarked
              ? l10n.libraryBookmarkRemove
              : l10n.libraryBookmarkAdd,
          onPressed: state.bookmarkBusy
              ? null
              : () => context.read<ArticleUserDataCubit>().toggleBookmark(),
          icon: Icon(state.bookmarked ? Icons.bookmark : Icons.bookmark_border),
        );
      },
    );
  }
}

class _ArticleReader extends StatelessWidget {
  const _ArticleReader({required this.detail, required this.embedded});

  final LegalArticleDetail detail;
  final bool embedded;

  Future<void> _createHighlight(
    BuildContext context,
    int startUtf16,
    int endUtf16,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HighlightEditorResult? result = await showHighlightEditor(
      context: context,
      title: l10n.libraryHighlightSheetTitle,
    );
    if (result is! HighlightSaved || !context.mounted) {
      return;
    }
    await context.read<ArticleUserDataCubit>().createHighlight(
      body: detail.article.bodyAr,
      startUtf16: startUtf16,
      endUtf16: endUtf16,
      color: result.color,
      note: result.note,
    );
  }

  Future<void> _editHighlight(
    BuildContext context,
    LegalHighlight highlight,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HighlightEditorResult? result = await showHighlightEditor(
      context: context,
      title: l10n.libraryHighlightEditTitle,
      initialColor: highlight.color,
      initialNote: highlight.note,
      allowDelete: true,
    );
    if (!context.mounted) {
      return;
    }
    if (result is HighlightDeleted) {
      await context.read<ArticleUserDataCubit>().deleteHighlight(highlight.id);
    } else if (result is HighlightSaved) {
      await context.read<ArticleUserDataCubit>().updateHighlight(
        highlight.id,
        color: result.color,
        note: result.note ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final LibraryArticleCubit cubit = context.read<LibraryArticleCubit>();

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(
              LegalHubTheme.marginMobile,
            ),
            children: <Widget>[
              Text(detail.documentTitleAr, style: text.titleMedium),
              if (detail.isSample)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: LegalHubTheme.spaceXs,
                  ),
                  child: const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SampleBadge(),
                  ),
                ),
              if (embedded)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _BookmarkAction(),
                ),
              const SizedBox(height: LegalHubTheme.space2xs),
              Text(
                l10n.libraryArticlePosition(
                  detail.article.ordinal,
                  detail.articleTotal,
                ),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              Text(
                l10n.libraryArticleNumberLabel(detail.article.articleNumber),
                style: text.headlineSmall,
              ),
              if (detail.article.headingAr != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(detail.article.headingAr!, style: text.titleMedium),
              ],
              const SizedBox(height: LegalHubTheme.spaceMd),
              BlocBuilder<ArticleUserDataCubit, ArticleUserDataState>(
                builder: (BuildContext context, ArticleUserDataState state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (state.staleHighlights.isNotEmpty)
                        _StaleNotice(highlights: state.staleHighlights),
                      HighlightedBody(
                        body: detail.article.bodyAr,
                        highlights: state.drawableHighlights,
                        // The Library corpus is Arabic source text even when
                        // the UI locale is English. Using the Latin family as
                        // the primary font splits the span into per-word
                        // fallback runs, which makes a single highlight paint
                        // as separate boxes. Pin the Arabic family so the
                        // highlight is one continuous span.
                        textStyle: text.bodyLarge?.copyWith(
                          height: 1.7,
                          fontFamily: 'NotoNaskhArabic',
                          fontFamilyFallback: const <String>['NotoSans'],
                        ),
                        onSelectionHighlight: (int start, int end) =>
                            _createHighlight(context, start, end),
                        onHighlightTapped: (LegalHighlight highlight) =>
                            _editHighlight(context, highlight),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              const LegalDisclaimerLine(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LegalHubTheme.marginMobile,
              0,
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceSm,
            ),
            child: Wrap(
              spacing: LegalHubTheme.spaceSm,
              runSpacing: LegalHubTheme.spaceXs,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: detail.previousArticleId == null
                      ? null
                      : cubit.openPrevious,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l10n.libraryPreviousArticle),
                ),
                OutlinedButton.icon(
                  onPressed: detail.nextArticleId == null
                      ? null
                      : cubit.openNext,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(l10n.libraryNextArticle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when the article was amended after the reader marked it.
///
/// The quotes are listed rather than drawn: the offsets point at words that have
/// since moved, so painting them would underline the wrong sentence. Showing the
/// saved quote is the honest alternative — the reader still sees what they chose.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.highlights});

  final List<LegalHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceMd),
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusMd),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: LegalHubTheme.spaceXs),
              Expanded(
                child: Text(
                  l10n.libraryHighlightStaleTitle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: LegalHubTheme.space2xs),
          Text(
            l10n.libraryHighlightStaleBody,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          for (final LegalHighlight highlight in highlights)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: LegalHubTheme.space2xs,
              ),
              child: Text(
                '“${highlight.quote}”',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
