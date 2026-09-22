part of 'matter_documents_section.dart';

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
    return BlocBuilder<DocumentCubit, DocumentState>(
      builder: (BuildContext context, DocumentState state) {
        return WorkspaceSection<Document>(
          state: state.documents,
          onRetry: () => context.read<DocumentCubit>().load(),
          errorCopy: l10n.vaultError,
          emptyCopy: l10n.matterWorkspaceDocumentsEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (Document document) => document.matterRef,
          itemBuilder: (BuildContext context, Document document) => AppTile(
            title: document.title,
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
