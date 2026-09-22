part of 'matter_details_screen.dart';

class _DetailsSurface extends StatefulWidget {
  const _DetailsSurface({required this.matterId, required this.capabilities});

  final String matterId;
  final RoleCapability capabilities;

  @override
  State<_DetailsSurface> createState() => _DetailsSurfaceState();
}

class _DetailsSurfaceState extends State<_DetailsSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (same pattern as the list surface);
    // the details are resolved from the loaded list by id.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MatterCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterDetailsTitle)),
      body: SafeArea(
        child: BlocBuilder<MatterCubit, MatterState>(
          builder: (BuildContext context, MatterState state) {
            return switch (state.matters) {
              ViewLoading() => const Center(child: CircularProgressIndicator()),
              ViewEmpty() => AppCenteredMessage(
                text: l10n.matterDetailsNotFound,
              ),
              ViewError() => AppCenteredRetry(
                message: l10n.matterError,
                onRetry: context.read<MatterCubit>().load,
                retryLabel: l10n.retry,
              ),
              // The sealed ViewState set also carries offline/unauthorized
              // variants (shared vocabulary); a synthetic list has neither
              // state, so both render the not-found copy.
              ViewOffline() || ViewUnauthorized() => AppCenteredMessage(
                text: l10n.matterDetailsNotFound,
              ),
              ViewSuccess(data: final List<Matter> matters) => _details(
                context,
                l10n,
                _findById(matters, widget.matterId),
              ),
            };
          },
        ),
      ),
    );
  }

  Matter? _findById(List<Matter> matters, String id) {
    for (final Matter matter in matters) {
      if (matter.id == id) {
        return matter;
      }
    }
    return null;
  }

  Widget _details(BuildContext context, AppLocalizations l10n, Matter? matter) {
    if (matter == null) {
      return AppCenteredMessage(text: l10n.matterDetailsNotFound);
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(matter.title, style: text.headlineSmall),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MatterStatusChip(
            label: matterStatusLabel(l10n, matter.status),
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        _DetailRow(
          label: l10n.matterDetailsPracticeArea,
          value: practiceAreaLabel(l10n, matter.practiceArea),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _DetailRow(
          label: l10n.matterDetailsAssignedAttorney,
          value: matter.assignedAttorneyName,
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _DetailRow(
          label: l10n.matterDetailsCreated,
          value: formatMediumDate(l10n, matter.createdAt),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        if (widget.capabilities.canViewDocuments) ...<Widget>[
          AppSectionHeader(
            title: l10n.matterWorkspaceDocumentsTitle,
            titleStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            children: <Widget>[MatterDocumentsSection(matterRef: matter.title)],
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
        ],
        // Invoices are matter-scoped content like documents (matrix §4 — the
        // same client/attorney SHIP cells), so the section rides the same
        // canViewDocuments visibility gate (D-BI5 — no new capability flag;
        // the plan's file list carries no user_role.dart change).
        if (widget.capabilities.canViewDocuments) ...<Widget>[
          AppSectionHeader(
            title: l10n.matterWorkspaceInvoicesTitle,
            titleStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            children: <Widget>[MatterInvoicesSection(matterRef: matter.title)],
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
        ],
        if (widget.capabilities.canViewFiles) ...<Widget>[
          AppSectionHeader(
            title: l10n.matterWorkspaceFilesTitle,
            titleStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            children: <Widget>[MatterFilesSection(matterRef: matter.title)],
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
        ],
        if (widget.capabilities.canViewMessages) ...<Widget>[
          AppSectionHeader(
            title: l10n.matterWorkspaceMessagesTitle,
            titleStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            children: <Widget>[MatterMessagesSection(matterRef: matter.title)],
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
        ],
        Text(
          l10n.matterLocalOnlyNote,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
