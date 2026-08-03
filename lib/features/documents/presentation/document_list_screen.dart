import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';
import '../domain/document_gateway.dart';
import 'document_cubit.dart';
import 'document_labels.dart';
import 'document_state.dart';
import 'document_type_chip.dart';

/// Document-vault list surface (Phase 8, slice 8.1).
///
/// A `/vault` route that loads the document-metadata list from the
/// [DocumentGateway] seam (the dev fake in env-less runs, owner decision
/// D-V2). **Metadata only** — rows render the three D-V4 fields (title,
/// type, created date) and nothing else: no body, no preview, no download,
/// no open action, and no details route (D-V1). Rows are deliberately NOT
/// tap targets. All copy is local-only — the synthetic list must never read
/// as real files (R1/D-V4).
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DocumentCubit>(
      create: (BuildContext context) =>
          DocumentCubit(serviceLocator<DocumentGateway>()),
      child: const _ListSurface(),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface();

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic metadata list on open (matches the discovery/matter
    // pattern): the cubit's initial state is already loading, and the fake
    // resolves immediately, so the first frame settles straight into the
    // list.
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultTitle)),
      body: SafeArea(
        child: BlocBuilder<DocumentCubit, DocumentState>(
          builder: (BuildContext context, DocumentState state) {
            return ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                _resultsView(context, state, l10n, text, scheme),
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.vaultLocalOnlyNote,
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
    DocumentState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final DocumentCubit cubit = context.read<DocumentCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.vaultEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return switch (state.documents) {
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
              l10n.vaultError,
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
            TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
          ],
        ),
      ),
      // The sealed ViewState set also carries offline/unauthorized variants
      // (shared vocabulary); a synthetic list has neither state, so both
      // render the same empty copy rather than a distinct offline surface.
      ViewOffline() || ViewUnauthorized() => empty,
      ViewSuccess<List<Document>>(data: final List<Document> documents) =>
        documents.isEmpty
            ? empty
            : Column(
                children: <Widget>[
                  for (final Document document in documents) ...<Widget>[
                    _DocumentTile(document: document),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                ],
              ),
    };
  }
}

/// A read-only metadata row. Carries **no onTap, no InkWell, no chevron,
/// and no trailing action** — the vault has no details route and rows must
/// not read as tappable (D-V1 metadata-only line). The AC-2 pin asserts
/// these absences structurally.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // Same localized date shape as the matter details surface (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(document.createdAt);
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
                ],
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceSm),
            DocumentTypeChip(label: documentTypeLabel(l10n, document.type)),
          ],
        ),
      ),
    );
  }
}
