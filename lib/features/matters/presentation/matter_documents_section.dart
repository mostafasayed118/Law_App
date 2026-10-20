import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../../documents/domain/document.dart';
import '../../documents/presentation/document_labels.dart';
import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Documents section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) instead of a foreign feature's presentation cubit
/// (audit: matters god-feature) and renders the subset of the document list
/// whose [Document.matterRef] equals [matterRef] — a client-side view over
/// the gateway list (the D-M5 pattern; there is no per-matter fetch).
/// **Metadata only**: each row renders the D-V4 title/type/date fields and
/// nothing else — no preview, no download, no open action, no tap
/// affordance (D-W4). An empty per-matter subset renders the localized
/// empty copy (AC-3).
class MatterDocumentsSection extends StatefulWidget {
  const MatterDocumentsSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [Document.matterRef], D-W2).
  final String matterRef;

  @override
  State<MatterDocumentsSection> createState() => _MatterDocumentsSectionState();
}

class _MatterDocumentsSectionState extends State<MatterDocumentsSection> {
  @override
  void initState() {
    super.initState();
    // Load the document list on open (same pattern as the standalone vault
    // surface); the per-matter subset is filtered client-side below. Only
    // this list loads — sibling sections trigger their own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MatterWorkspaceCubit>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<MatterWorkspaceCubit, MatterWorkspaceState>(
      buildWhen:
          (MatterWorkspaceState previous, MatterWorkspaceState current) =>
              previous.documents != current.documents,
      builder: (BuildContext context, MatterWorkspaceState state) {
        return WorkspaceSection<Document>(
          state: state.documents,
          onRetry: () => context.read<MatterWorkspaceCubit>().loadDocuments(),
          errorCopy: l10n.vaultError,
          emptyCopy: l10n.matterWorkspaceDocumentsEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (Document document) => document.matterRef,
          itemBuilder: (BuildContext context, Document document) => AppTile(
            title: demoDocumentTitle(l10n, document.title),
            subtitles: <String>[
              '${documentTypeLabel(l10n, document.type)} · '
                  '${formatMediumDate(l10n, document.createdAt)}',
            ],
          ),
        );
      },
    );
  }
}
