import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'document_cubit.dart';
import 'document_labels.dart';
import 'document_state.dart';
import 'document_type_chip.dart';

part 'document_list_tile.dart';

/// Document-vault list surface (Phase 8, slice 8.1; Phase 12, slice 12.0).
///
/// A `/vault` route that loads the document-metadata list from the
/// [DocumentGateway] seam (the dev fake in env-less runs, owner decision
/// D-V2). **Metadata only** — rows render the three D-V4 fields (title,
/// type, created date) and nothing else: no body, no preview, no download,
/// no open action (D-V1). Phase 12 adds the **reverse cross-link** (D-C1):
/// a row whose provider query embedded the matter title renders the compact
/// "View matter" chip — the only tap target in the list (D-C2), gated by the
/// `canViewMatters` nav hint (D-C4). The link target is the row's own
/// `matter_id` (the embed carries the title), so the screen no longer loads
/// the full matter list just to resolve `matterRef`; a row without the embed
/// stays metadata-only (the safe fallback). All copy is local-only — the
/// synthetic list must never read as real files (R1/D-V4).
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({required this.capabilities, super.key});

  /// UX-only capability projection for the reverse cross-link (D-C4): the
  /// "View matter" chip renders only under [RoleCapability.canViewMatters].
  /// Navigation hint only — never authorization (the D-W5 posture).
  final RoleCapability capabilities;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DocumentCubit>(
      create: (BuildContext context) =>
          DocumentCubit(serviceLocator<DocumentGateway>()),
      child: _ListSurface(capabilities: capabilities),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface({required this.capabilities});

  final RoleCapability capabilities;

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultTitle)),
      body: SafeArea(
        child: BlocBuilder<DocumentCubit, DocumentState>(
          builder: (BuildContext context, DocumentState state) {
            return _resultsView(context, state, l10n, text, scheme);
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
    final bool localOnly = backendIsLocalOnly;
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.vaultEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    // Lazy list surface (audit 2026-09-21, M-20): the success arm used to be a
    // Column of every tile nested in a non-lazy ListView, so row culling never
    // applied. ViewStateList builds rows through SliverChildBuilderDelegate and
    // carries the local-only note itself, which is why it replaces the outer
    // ListView rather than nesting inside it.
    return ViewStateList<Document>(
      state: state.documents,
      onRetry: cubit.load,
      tileBuilder: (BuildContext context, Document document) => _DocumentTile(
        document: document,
        onViewMatter: _matterTap(context, document),
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
    // E2E BUG-1 fix: list → matter detail is a forward navigation.
    return () => context.push(AppRoutes.matterDetail(matterId));
  }
}
