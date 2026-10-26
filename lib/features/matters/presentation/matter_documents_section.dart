import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/presentation/document_labels.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Documents section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) instead of a foreign feature's presentation cubit
/// (audit: matters god-feature). The cubit scopes the gateway read to the
/// open matter server-side, so the list here is already the matter's subset;
/// no client-side title filtering runs.
/// **Metadata only**: each row renders the D-V4 title/type/date fields and
/// nothing else — no preview, no download, no open action, no tap
/// affordance (D-W4). An empty per-matter subset renders the localized
/// empty copy (AC-3).
class MatterDocumentsSection extends StatefulWidget {
  const MatterDocumentsSection({super.key});

  @override
  State<MatterDocumentsSection> createState() => _MatterDocumentsSectionState();
}

class _MatterDocumentsSectionState extends State<MatterDocumentsSection> {
  @override
  void initState() {
    super.initState();
    // Load the matter-scoped document list on open. Only this list loads —
    // sibling sections trigger their own.
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
    final DemoLabels labels = DemoLabels(l10n, localOnly: backendIsLocalOnly);
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
          itemBuilder: (BuildContext context, Document document) => AppTile(
            title: labels.documentTitle(document.title),
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
