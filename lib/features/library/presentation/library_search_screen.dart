import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';
import 'package:legalhub/features/library/presentation/library_labels.dart';
import 'package:legalhub/features/library/presentation/library_search_cubit.dart';
import 'package:legalhub/features/library/presentation/library_search_state.dart';
import 'package:legalhub/features/library/presentation/sample_badge.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Full-text search over the library (ADR-0009).
///
/// Three distinct "nothing here" states, deliberately not collapsed: no query
/// yet, no match, and a failed read. Collapsing them into one message would
/// tell a reader with a typo the same thing as a reader with a dead connection.
class LibrarySearchScreen extends StatelessWidget {
  const LibrarySearchScreen({this.initialQuery = '', super.key});

  /// The `q` query param; a non-blank value seeds the first search on open.
  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibrarySearchCubit>(
      create: (BuildContext context) {
        final LibrarySearchCubit cubit = LibrarySearchCubit(
          serviceLocator<LibraryGateway>(),
        );
        if (initialQuery.trim().isNotEmpty) {
          cubit.updateQuery(initialQuery);
        }
        return cubit;
      },
      child: _LibrarySearchSurface(initialQuery: initialQuery),
    );
  }
}

class _LibrarySearchSurface extends StatefulWidget {
  const _LibrarySearchSurface({required this.initialQuery});

  final String initialQuery;

  @override
  State<_LibrarySearchSurface> createState() => _LibrarySearchSurfaceState();
}

class _LibrarySearchSurfaceState extends State<_LibrarySearchSurface> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LibrarySearchCubit cubit = context.read<LibrarySearchCubit>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.librarySearchHint,
            border: InputBorder.none,
          ),
          onChanged: cubit.updateQuery,
          onSubmitted: (_) => cubit.submit(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.librarySearchHint,
            icon: const Icon(Icons.search),
            onPressed: cubit.submit,
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<LibrarySearchCubit, LibrarySearchState>(
          builder: (BuildContext context, LibrarySearchState state) {
            if (!state.hasQuery) {
              return AppCenteredMessage(text: l10n.librarySearchNoQuery);
            }
            return ViewStateList<LegalSearchHit>(
              state: state.results,
              onRetry: cubit.submit,
              errorCopy: l10n.librarySearchError,
              localOnlyNote: l10n.libraryLocalOnlyNote,
              empty: AppCenteredMessage(text: l10n.librarySearchNoResults),
              tileBuilder: (BuildContext context, LegalSearchHit hit) =>
                  _SearchHitTile(hit: hit),
            );
          },
        ),
      ),
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit});

  final LegalSearchHit hit;

  /// Renders the server's `[[`/`]]` delimiters as an emphasized span without a
  /// second matching pass: the server already decided what matched.
  TextSpan _snippetSpan(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle? base = Theme.of(context).textTheme.bodySmall;
    final TextSpan highlight = TextSpan(
      style: base?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      text: '',
    );
    final List<TextSpan> spans = <TextSpan>[];
    final List<String> parts = hit.snippet.split('[[');
    if (parts.isNotEmpty) {
      spans.add(TextSpan(text: parts.first, style: base));
    }
    for (int i = 1; i < parts.length; i++) {
      final String part = parts[i];
      final int close = part.indexOf(']]');
      if (close < 0) {
        spans.add(TextSpan(text: part, style: base));
        continue;
      }
      spans.add(
        TextSpan(text: part.substring(0, close), style: highlight.style),
      );
      spans.add(TextSpan(text: part.substring(close + 2), style: base));
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${hit.documentTitleAr} · '
              '${l10n.libraryArticleNumberLabel(hit.articleNumber)}',
              style: text.titleSmall,
            ),
            if (hit.isSample)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: LegalHubTheme.space2xs,
                ),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SampleBadge(),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: LegalHubTheme.space2xs),
            // ArB: the snippet carries the server's highlight delimiters.
            Text.rich(_snippetSpan(context)),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Wrap(
              spacing: LegalHubTheme.spaceXs,
              runSpacing: LegalHubTheme.spaceXs,
              children: <Widget>[
                LabelChip(
                  label: libraryCategoryLabel(l10n, hit.category),
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                if (hit.year != null)
                  LabelChip(
                    label: '${hit.year}',
                    background: scheme.surfaceContainerHighest,
                    foreground: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ],
        ),
        onTap: () => context.push(AppRoutes.libraryArticleFor(hit.articleId)),
      ),
    );
  }
}
