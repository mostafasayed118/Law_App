import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../../matters/domain/matter_title_resolver.dart';
import '../../matters/presentation/matter_cubit.dart';
import '../../matters/presentation/matter_link_chip.dart';
import '../../matters/presentation/matter_state.dart';
import '../domain/document.dart';
import '../domain/document_gateway.dart';
import 'document_cubit.dart';
import 'document_labels.dart';
import 'document_state.dart';
import 'document_type_chip.dart';

/// Document-vault list surface (Phase 8, slice 8.1; Phase 12, slice 12.0).
///
/// A `/vault` route that loads the document-metadata list from the
/// [DocumentGateway] seam (the dev fake in env-less runs, owner decision
/// D-V2). **Metadata only** — rows render the three D-V4 fields (title,
/// type, created date) and nothing else: no body, no preview, no download,
/// no open action (D-V1). Phase 12 adds the **reverse cross-link** (D-C1):
/// a row whose `matterRef` resolves to a known synthetic matter renders the
/// compact "View matter" chip — the only tap target in the list (D-C2),
/// gated by the `canViewMatters` nav hint (D-C4). Resolution is title-keyed
/// and client-side against the loaded synthetic matter list (D-C3, the D-M5
/// discipline in reverse); rows whose `matterRef` does not resolve stay
/// metadata-only. All copy is local-only — the synthetic list must never
/// read as real files (R1/D-V4).
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({required this.capabilities, super.key});

  /// UX-only capability projection for the reverse cross-link (D-C4): the
  /// "View matter" chip renders only under [RoleCapability.canViewMatters].
  /// Navigation hint only — never authorization (the D-W5 posture).
  final RoleCapability capabilities;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<DocumentCubit>(
          create: (BuildContext context) =>
              DocumentCubit(serviceLocator<DocumentGateway>()),
        ),
        // Loads the synthetic matter list alongside the documents so each
        // row's matterRef can be resolved client-side (D-C3).
        BlocProvider<MatterCubit>(
          create: (BuildContext context) =>
              MatterCubit(serviceLocator<MatterGateway>()),
        ),
      ],
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
    // Load both synthetic lists on open (matches the discovery/matter
    // pattern): the cubits' initial states are already loading, and the
    // fakes resolve immediately, so the first frame settles straight into
    // the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DocumentCubit>().load();
      context.read<MatterCubit>().load();
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
            return BlocBuilder<MatterCubit, MatterState>(
              builder: (BuildContext context, MatterState matterState) {
                // The loaded matter list feeds the title-keyed resolution
                // (D-C3); empty until the matter list loads, so tiles render
                // without a chip until then (the fakes resolve immediately).
                // The loaded matter list feeds the title-keyed resolution
                // (D-C3); empty until the matter list loads, so tiles render
                // without a chip until then (the fakes resolve immediately).
                // Deliberate degradation: if the matter load ever fails, the
                // vault still renders its documents and the reverse link
                // simply disappears — a nav hint, not a second error state.
                final List<Matter> matters = switch (matterState.matters) {
                  ViewSuccess<List<Matter>>(data: final List<Matter> list) =>
                    list,
                  ViewLoading() ||
                  ViewEmpty() ||
                  ViewError() ||
                  ViewOffline() ||
                  ViewUnauthorized() => const <Matter>[],
                };
                return ListView(
                  padding: const EdgeInsetsDirectional.all(
                    LegalHubTheme.marginMobile,
                  ),
                  children: <Widget>[
                    _resultsView(context, state, matters, l10n, text, scheme),
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
            );
          },
        ),
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    DocumentState state,
    List<Matter> matters,
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
    return ViewStateSwitch<List<Document>>(
      state: state.documents,
      onRetry: cubit.load,
      builder: (BuildContext context, List<Document> documents) =>
          documents.isEmpty
          ? empty
          : Column(
              children: <Widget>[
                for (final Document document in documents) ...<Widget>[
                  _DocumentTile(
                    document: document,
                    onViewMatter: _matterTap(context, document, matters),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceSm),
                ],
              ],
            ),
      empty: empty,
      errorCopy: l10n.vaultError,
    );
  }

  /// The reverse cross-link target for a row, or null when the row renders
  /// no affordance: the `matterRef` must resolve to a known synthetic matter
  /// (D-C3) AND the `canViewMatters` nav hint must be granted (D-C4).
  VoidCallback? _matterTap(
    BuildContext context,
    Document document,
    List<Matter> matters,
  ) {
    if (!widget.capabilities.canViewMatters) {
      return null;
    }
    final Matter? matter = resolveMatterByTitle(matters, document.matterRef);
    if (matter == null) {
      return null;
    }
    return () => context.go(AppRoutes.matterDetail(matter.id));
  }
}

/// A read-only metadata row. Carries **no onTap on the row body, no chevron,
/// and no trailing action other than the Phase 12 "View matter" chip** — the
/// vault's metadata-only line (D-V1) now allows exactly one tap target per
/// resolved row: the compact `MatterLinkChip`, which is the ONLY InkWell in
/// the list (D-C2). The AC-2 pin asserts these absences structurally.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onViewMatter});

  final Document document;

  /// The reverse cross-link tap, or null when the row renders no chip
  /// (unresolved `matterRef` or the nav hint not granted, D-C2/D-C4).
  ///
  /// Null-checked with a `case` pattern below: public final fields do not
  /// promote in Dart 3.2, so a plain `!= null` check would not narrow the
  /// type here.
  final VoidCallback? onViewMatter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Same localized date shape as the matter details surface (yMMMd,
    // locale-aware via l10n.localeName).
    final String date = formatMediumDate(l10n, document.createdAt);
    return AppTile(
      icon: Icons.folder_outlined,
      title: document.title,
      subtitles: <String>['${documentTypeLabel(l10n, document.type)} · $date'],
      // The chips wrap beneath the metadata line (the roster pattern); the
      // link chip stays the only tap target in the row (D-C2), so the card
      // itself renders no InkWell and no chevron (AppTile null onTap).
      trailing: switch (onViewMatter) {
        final VoidCallback tap => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceSm),
          child: Wrap(
            spacing: LegalHubTheme.spaceSm,
            runSpacing: LegalHubTheme.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DocumentTypeChip(label: documentTypeLabel(l10n, document.type)),
              MatterLinkChip(onTap: tap),
            ],
          ),
        ),
        null => null,
      },
    );
  }
}
