import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/library/domain/legal_article.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_document_cubit.dart';
import 'package:legalhub/features/library/presentation/library_document_state.dart';
import 'package:legalhub/features/library/presentation/library_labels.dart';
import 'package:legalhub/features/library/presentation/sample_badge.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// The document reader: header plus the article list (ADR-0009).
///
/// [embedded] renders the same body without its own scaffold chrome, so an
/// expanded window can show it in the second pane of a [TwoPane] beside the
/// index.
class LibraryDocumentScreen extends StatelessWidget {
  const LibraryDocumentScreen({
    required this.documentId,
    this.embedded = false,
    super.key,
  });

  final String documentId;

  /// True when hosted inside a two-pane detail slot.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryDocumentCubit>(
      create: (BuildContext context) =>
          LibraryDocumentCubit(serviceLocator<LibraryGateway>())
            ..load(documentId),
      child: _LibraryDocumentBody(embedded: embedded, documentId: documentId),
    );
  }
}

class _LibraryDocumentBody extends StatelessWidget {
  const _LibraryDocumentBody({
    required this.embedded,
    required this.documentId,
  });

  final bool embedded;
  final String documentId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<LibraryDocumentCubit, LibraryDocumentState>(
      builder: (BuildContext context, LibraryDocumentState state) {
        final Widget content = switch (state.detail) {
          ViewSuccess<LegalDocumentDetail>(
            data: final LegalDocumentDetail detail,
          ) =>
            _DocumentDetail(detail: detail),
          final ViewState<LegalDocumentDetail> other => Center(
            child: SingleChildScrollView(
              child: ViewStateView<LegalDocumentDetail>(
                state: other,
                errorFallback: l10n.libraryDocumentError,
                onRetry: other is ViewError<LegalDocumentDetail>
                    ? () =>
                          context.read<LibraryDocumentCubit>().load(documentId)
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

class _DocumentDetail extends StatelessWidget {
  const _DocumentDetail({required this.detail});

  final LegalDocumentDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final LegalDocument document = detail.document;

    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(document.titleAr, style: text.headlineSmall)),
            if (document.isSample) ...<Widget>[
              const SizedBox(width: LegalHubTheme.spaceXs),
              const SampleBadge(),
            ],
          ],
        ),
        if (document.titleEn != null) ...<Widget>[
          const SizedBox(height: LegalHubTheme.space2xs),
          Text(
            document.titleEn!,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: LegalHubTheme.spaceSm),
        Wrap(
          spacing: LegalHubTheme.spaceXs,
          runSpacing: LegalHubTheme.spaceXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            LabelChip(
              label: libraryStatusLabel(l10n, document.status),
              background: scheme.surfaceContainerHighest,
              foreground: scheme.onSurfaceVariant,
            ),
            LabelChip(
              label: libraryCategoryLabel(l10n, document.category),
              background: scheme.surfaceContainerHighest,
              foreground: scheme.onSurfaceVariant,
            ),
            if (document.officialNumber != null)
              LabelChip(
                label: document.officialNumber!,
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
            if (document.year != null)
              LabelChip(
                label: '${document.year}',
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
          ],
        ),
        if (document.summaryAr != null) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(document.summaryAr!, style: text.bodyMedium),
        ],
        const LegalDisclaimerLine(),
        const Divider(),
        Text(l10n.libraryDocumentArticles, style: text.titleMedium),
        const SizedBox(height: LegalHubTheme.spaceSm),
        if (detail.articles.isEmpty)
          AppCenteredMessage(text: l10n.libraryDocumentEmpty)
        else
          for (final LegalArticle article in detail.articles)
            _ArticleRow(article: article),
      ],
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({required this.article});

  final LegalArticle article;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: ListTile(
        title: Text(
          l10n.libraryArticleNumberLabel(article.articleNumber),
          style: text.titleSmall,
        ),
        subtitle: Text(
          article.headingAr ?? article.bodyAr,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.libraryArticleFor(article.id)),
      ),
    );
  }
}
