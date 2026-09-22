part of 'attorney_search_screen.dart';

class _SearchSurface extends StatefulWidget {
  const _SearchSurface();

  @override
  State<_SearchSurface> createState() => _SearchSurfaceState();
}

class _SearchSurfaceState extends State<_SearchSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (matches the roster pattern): the
    // cubit's initial state is already loading, and the fake resolves
    // immediately, so the first frame settles straight into the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DiscoveryCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoveryTitle)),
      body: SafeArea(
        child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
          builder: (BuildContext context, DiscoveryState state) {
            // Lazy list surface (audit 2026-09-21, M-20): the search field and
            // the practice-area chips stay the header of the same scroll view —
            // passed as `header`, they keep scrolling away with the rows
            // instead of being pinned, and no nested scrollable is created.
            return _resultsView(context, state, l10n, text, scheme);
          },
        ),
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    DiscoveryState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final DiscoveryCubit cubit = context.read<DiscoveryCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.discoveryEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return ViewStateList<Attorney>(
      state: state.visibleAttorneysState,
      onRetry: cubit.load,
      tileBuilder: (BuildContext context, Attorney attorney) => _AttorneyTile(
        attorney: attorney,
        onTap: () => context.go(AppRoutes.attorneyProfile(attorney.id)),
      ),
      header: <Widget>[
        const _SearchField(),
        const SizedBox(height: LegalHubTheme.spaceMd),
        AppFilterChips<PracticeArea>(
          values: PracticeArea.values,
          selected: state.practiceArea,
          allLabel: l10n.discoveryFilterAll,
          labelOf: (PracticeArea area) => practiceAreaLabel(l10n, area),
          onSelected: cubit.setPracticeArea,
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
      ],
      empty: empty,
      errorCopy: l10n.discoveryError,
      localOnlyNote: l10n.discoveryLocalOnlyNote,
      listPadding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
    );
  }
}
