import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/responsive/breakpoints.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'document_cubit.dart';
import 'document_details_screen.dart';
import 'document_labels.dart';
import 'document_state.dart';
import 'document_type_chip.dart';

part 'document_list_tile.dart';

/// Document-vault list surface (Phase 8, slice 8.1; Phase 12, slice 12.0).
///
/// A `/vault` route that loads the document-metadata list from the
/// [DocumentGateway] seam (the dev fake in env-less runs, owner decision
/// D-V2). **Metadata only** — rows render the three D-V4 fields (title,
/// type, created date) and nothing else: no body, no preview, no download
/// (D-V1). The row opens the metadata detail (`/vault/:id`); that detail
/// shows the same metadata fields and still has no content/download/preview
/// affordance. Phase 12 adds the **reverse cross-link** (D-C1): a row whose
/// provider query embedded the matter title renders the compact
/// "View matter" chip — a secondary tap target inside the row (D-C2), gated
/// by the `canViewMatters` nav hint (D-C4).
///
/// On expanded windows (≥840dp) the screen is a two-pane master/detail: the
/// vault list stays on the left and the selected document's metadata renders
/// on the right. Compact/medium windows keep push navigation.
class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({
    required this.capabilities,
    this.initialSelectedDocumentId,
    super.key,
  });

  /// UX-only capability projection for the reverse cross-link (D-C4): the
  /// "View matter" chip renders only under [RoleCapability.canViewMatters].
  /// Navigation hint only — never authorization (the D-W5 posture).
  final RoleCapability capabilities;

  /// Deep-link projection: `/vault/:id` on an expanded window opens the
  /// two-pane with this document selected.
  final String? initialSelectedDocumentId;

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  String? _selectedDocumentId;

  @override
  void initState() {
    super.initState();
    _selectedDocumentId = widget.initialSelectedDocumentId;
  }

  @override
  void didUpdateWidget(DocumentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedDocumentId !=
        oldWidget.initialSelectedDocumentId) {
      _selectedDocumentId = widget.initialSelectedDocumentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool twoPane =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return BlocProvider<DocumentCubit>(
      create: (BuildContext context) =>
          DocumentCubit(serviceLocator<DocumentGateway>()),
      child: twoPane
          ? _buildTwoPane(l10n)
          : _ListSurface(capabilities: widget.capabilities),
    );
  }

  Widget _buildTwoPane(AppLocalizations l10n) {
    final String? selectedId = _selectedDocumentId;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultTitle)),
      body: SafeArea(
        child: TwoPane(
          list: _ListSurface(
            embedded: true,
            capabilities: widget.capabilities,
            selectedDocumentId: selectedId,
            onSelectDocument: (String id) =>
                setState(() => _selectedDocumentId = id),
          ),
          detail: selectedId == null
              ? AppCenteredMessage(text: l10n.documentDetailsTitle)
              : DocumentDetailsScreen(
                  key: ValueKey<String>(selectedId),
                  documentId: selectedId,
                  capabilities: widget.capabilities,
                  embedded: true,
                ),
        ),
      ),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface({
    required this.capabilities,
    this.embedded = false,
    this.selectedDocumentId,
    this.onSelectDocument,
  });

  final RoleCapability capabilities;

  /// True inside the two-pane: the pane owns no Scaffold/AppBar.
  final bool embedded;

  /// The document rendered by the detail pane (two-pane only).
  final String? selectedDocumentId;

  /// Selection callback for two-pane. Null restores push navigation.
  final ValueChanged<String>? onSelectDocument;

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  bool _autoSelected = false;

  @override
  void initState() {
    super.initState();
    // The cubit's initial state is already loading and the fake resolves
    // immediately, so the first frame settles straight into the list.
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
    final Widget body = SafeArea(
      child: BlocBuilder<DocumentCubit, DocumentState>(
        builder: (BuildContext context, DocumentState state) {
          _maybeAutoSelect(state);
          return _resultsView(context, state, l10n, text, scheme);
        },
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultTitle)),
      body: body,
    );
  }

  /// Auto-selects the first loaded document once per list mount.
  void _maybeAutoSelect(DocumentState state) {
    if (_autoSelected ||
        widget.onSelectDocument == null ||
        widget.selectedDocumentId != null) {
      return;
    }
    if (state.documents case ViewSuccess<List<Document>>(
      data: final List<Document> documents,
    ) when documents.isNotEmpty) {
      _autoSelected = true;
      final String firstId = documents.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSelectDocument!(firstId);
        }
      });
    }
  }

  Widget _resultsView(
    BuildContext context,
    DocumentState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final DocumentCubit cubit = context.read<DocumentCubit>();
    final bool localOnly = backendIsLocalOnly;
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.vaultEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return ViewStateList<Document>(
      state: state.documents,
      onRetry: cubit.load,
      tileBuilder: (BuildContext context, Document document) => _DocumentTile(
        document: document,
        localOnly: localOnly,
        onViewMatter: _matterTap(context, document),
        // Two-pane: select in place. Compact/medium: forward navigation to
        // the metadata detail.
        onOpen: widget.onSelectDocument == null
            ? () => context.push(AppRoutes.documentDetail(document.id))
            : () => widget.onSelectDocument!(document.id),
      ),
      empty: empty,
      errorCopy: l10n.vaultError,
      localOnlyNote: localOnly ? l10n.vaultLocalOnlyNote : '',
      listPadding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
    );
  }

  /// The reverse cross-link target for a row, or null when the row renders
  /// no affordance: the provider query must have returned both the matter id
  /// and its embedded title (the safe fallback when the embed is absent),
  /// AND the `canViewMatters` nav hint must be granted (D-C4).
  VoidCallback? _matterTap(BuildContext context, Document document) {
    if (!widget.capabilities.canViewMatters) {
      return null;
    }
    final String? matterId = document.matterId;
    final String? matterTitle = document.matterTitle;
    if (matterId == null || matterTitle == null) {
      return null;
    }
    return () => context.push(AppRoutes.matterDetail(matterId));
  }
}
