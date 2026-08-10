import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../features/documents/domain/document.dart';
import '../../../features/documents/domain/document_gateway.dart';
import '../../../features/documents/presentation/document_cubit.dart';
import '../../../features/documents/presentation/document_labels.dart';
import '../../../features/documents/presentation/document_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';

/// Per-matter Documents section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Provides its own [DocumentCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the synthetic document list
/// whose [Document.matterRef] equals [matterRef] — a client-side view over
/// the fake list (the D-M5 pattern; there is no per-matter fetch). **Metadata
/// only**: each row renders the D-V4 title/type/date fields and nothing else
/// — no preview, no download, no open action, no tap affordance (D-W4). An
/// empty per-matter subset renders the localized empty copy (AC-3).
class MatterDocumentsSection extends StatelessWidget {
  const MatterDocumentsSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [Document.matterRef], D-W2).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DocumentCubit>(
      create: (BuildContext context) =>
          DocumentCubit(serviceLocator<DocumentGateway>()),
      child: _DocumentsSectionBody(matterRef: matterRef),
    );
  }
}

class _DocumentsSectionBody extends StatefulWidget {
  const _DocumentsSectionBody({required this.matterRef});

  final String matterRef;

  @override
  State<_DocumentsSectionBody> createState() => _DocumentsSectionBodyState();
}

class _DocumentsSectionBodyState extends State<_DocumentsSectionBody> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (same pattern as the standalone vault
    // surface); the per-matter subset is filtered client-side below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DocumentCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocBuilder<DocumentCubit, DocumentState>(
      builder: (BuildContext context, DocumentState state) {
        return ViewStateSwitch<List<Document>>(
          state: state.documents,
          onRetry: () => context.read<DocumentCubit>().load(),
          builder: (BuildContext context, List<Document> documents) =>
              _rows(context, documents, l10n, text, scheme),
          empty: _empty(l10n, text, scheme),
          errorCopy: l10n.vaultError,
          loadingPadding: const EdgeInsetsDirectional.all(
            LegalHubTheme.spaceMd,
          ),
          errorPadding: EdgeInsets.zero,
          errorTextStyle: text.bodySmall?.copyWith(color: scheme.error),
        );
      },
    );
  }

  Widget _rows(
    BuildContext context,
    List<Document> documents,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final List<Document> matched = documents
        .where((Document d) => d.matterRef == widget.matterRef)
        .toList();
    if (matched.isEmpty) {
      return _empty(l10n, text, scheme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Document document in matched) ...<Widget>[
          _DocumentRow(document: document),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
      ],
    );
  }

  Widget _empty(AppLocalizations l10n, TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        l10n.matterWorkspaceDocumentsEmpty,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// A read-only metadata row. Carries **no onTap, no InkWell, no chevron,
/// and no trailing action** — the per-matter view keeps the D-V1 metadata-only
/// line (D-W4), so rows must not read as tappable.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final Document document;

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
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              document.title,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${documentTypeLabel(l10n, document.type)} · $date',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
