import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_article_cubit.dart';
import 'package:legalhub/features/library/presentation/library_article_state.dart';
import 'package:legalhub/features/library/presentation/sample_badge.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// The article reader (ADR-0009).
///
/// Arabic body text uses the theme's Noto Naskh Arabic at the body style's line
/// height; the reader adds breathing room rather than overriding the family, so
/// the typography decision stays in the one token source.
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
    return BlocProvider<LibraryArticleCubit>(
      create: (BuildContext context) =>
          LibraryArticleCubit(serviceLocator<LibraryGateway>())
            ..load(articleId),
      child: _LibraryArticleBody(articleId: articleId, embedded: embedded),
    );
  }
}

class _LibraryArticleBody extends StatelessWidget {
  const _LibraryArticleBody({required this.articleId, required this.embedded});

  final String articleId;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<LibraryArticleCubit, LibraryArticleState>(
      builder: (BuildContext context, LibraryArticleState state) {
        final Widget content = switch (state.detail) {
          ViewSuccess<LegalArticleDetail>(
            data: final LegalArticleDetail detail,
          ) =>
            _ArticleReader(detail: detail),
          final ViewState<LegalArticleDetail> other => Center(
            child: SingleChildScrollView(
              child: ViewStateView<LegalArticleDetail>(
                state: other,
                errorFallback: l10n.libraryArticleMissing,
                onRetry: other is ViewError<LegalArticleDetail>
                    ? () => context.read<LibraryArticleCubit>().load(articleId)
                    : null,
              ),
            ),
          ),
        };

        if (embedded) {
          return content;
        }
        return Scaffold(
          appBar: AppBar(title: Text(l10n.libraryTitle)),
          body: SafeArea(child: content),
        );
      },
    );
  }
}

class _ArticleReader extends StatelessWidget {
  const _ArticleReader({required this.detail});

  final LegalArticleDetail detail;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      detail.documentTitleAr,
                      style: text.titleMedium,
                    ),
                  ),
                  if (detail.isSample) ...<Widget>[
                    const SizedBox(width: LegalHubTheme.spaceXs),
                    const SampleBadge(),
                  ],
                ],
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
              // Arabic body: the theme already selects Noto Naskh Arabic for an
              // ar locale, and the 1.7 line height below is what makes a long
              // article readable without changing the family.
              Text(
                detail.article.bodyAr,
                style: text.bodyLarge?.copyWith(height: 1.7),
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
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: detail.previousArticleId == null
                        ? null
                        : cubit.openPrevious,
                    icon: const Icon(Icons.chevron_left),
                    label: Text(l10n.libraryPreviousArticle),
                  ),
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: detail.nextArticleId == null
                        ? null
                        : cubit.openNext,
                    icon: const Icon(Icons.chevron_right),
                    label: Text(l10n.libraryNextArticle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
