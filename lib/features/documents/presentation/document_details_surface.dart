part of 'document_details_screen.dart';

class _DocumentDetailsSurface extends StatefulWidget {
  const _DocumentDetailsSurface({
    required this.documentId,
    required this.capabilities,
    required this.embedded,
    required this.loadOnMount,
  });

  final String documentId;
  final RoleCapability capabilities;
  final bool embedded;

  /// Standalone details load the list themselves; the two-pane reads the
  /// parent list's already-loaded cubit.
  final bool loadOnMount;

  @override
  State<_DocumentDetailsSurface> createState() =>
      _DocumentDetailsSurfaceState();
}

class _DocumentDetailsSurfaceState extends State<_DocumentDetailsSurface> {
  @override
  void initState() {
    super.initState();
    if (!widget.loadOnMount) {
      return;
    }
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
    final Widget body = SafeArea(
      child: BlocBuilder<DocumentCubit, DocumentState>(
        builder: (BuildContext context, DocumentState state) {
          return switch (state.documents) {
            ViewLoading() => const Center(child: CircularProgressIndicator()),
            ViewEmpty() => AppCenteredMessage(
              text: l10n.documentDetailsNotFound,
            ),
            ViewError() => AppCenteredRetry(
              message: l10n.vaultError,
              onRetry: context.read<DocumentCubit>().load,
              retryLabel: l10n.retry,
            ),
            ViewOffline() || ViewUnauthorized() => AppCenteredMessage(
              text: l10n.documentDetailsNotFound,
            ),
            ViewSuccess(data: final List<Document> documents) => _details(
              context,
              l10n,
              _findById(documents, widget.documentId),
            ),
          };
        },
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentDetailsTitle)),
      body: body,
    );
  }

  Document? _findById(List<Document> documents, String id) {
    for (final Document document in documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  Widget _details(
    BuildContext context,
    AppLocalizations l10n,
    Document? document,
  ) {
    if (document == null) {
      return AppCenteredMessage(text: l10n.documentDetailsNotFound);
    }
    final DemoLabels labels = DemoLabels(l10n, localOnly: backendIsLocalOnly);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String matterTitle = labels.matterTitle(
      document.matterTitle ?? document.matterRef,
    );
    final VoidCallback? matterTap = _matterTap(context, document);
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(labels.documentTitle(document.title), style: text.headlineSmall),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DocumentTypeChip(
            label: documentTypeLabel(l10n, document.type),
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        _MetaRow(
          label: l10n.documentDetailsType,
          value: documentTypeLabel(l10n, document.type),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _MetaRow(
          label: l10n.documentDetailsMatter,
          value: matterTitle,
          trailing: switch (matterTap) {
            final VoidCallback tap => MatterLinkChip(onTap: tap),
            null => null,
          },
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _MetaRow(
          label: l10n.documentDetailsCreated,
          value: formatMediumDate(l10n, document.createdAt),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        if (backendIsLocalOnly)
          Text(
            l10n.vaultLocalOnlyNote,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }

  /// The reverse cross-link target, or null when the row cannot resolve a
  /// matter (no embedded title) or the capability hint is absent (D-C4).
  VoidCallback? _matterTap(BuildContext context, Document document) {
    if (!widget.capabilities.canViewMatters) {
      return null;
    }
    final String? matterId = document.matterId;
    if (matterId == null || document.matterTitle == null) {
      return null;
    }
    return () => context.push(AppRoutes.matterDetail(matterId));
  }
}

/// One label/value metadata row; an optional trailing widget (the matter
/// cross-link) sits at the end of the value column.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.space2xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: Text(value, style: text.bodyMedium)),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: LegalHubTheme.spaceSm),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}
