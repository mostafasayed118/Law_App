part of 'matter_list_screen.dart';

class _ListSurface extends StatefulWidget {
  const _ListSurface({required this.canCreateMatter});

  final bool canCreateMatter;

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (matches the discovery pattern): the
    // cubit's initial state is already loading, and the fake resolves
    // immediately, so the first frame settles straight into the list.
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterTitle)),
      // F-01 step 2 client swap: the partner-gated create entry (C-D6/Q5) —
      // a FAB over the read-first list. The server re-asserts F2-D1.
      floatingActionButton: widget.canCreateMatter
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.matterCreate),
              icon: const Icon(Icons.add),
              label: Text(l10n.matterCreateFab),
            )
          : null,
      body: SafeArea(
        child: BlocBuilder<MatterCubit, MatterState>(
          builder: (BuildContext context, MatterState state) {
            // Lazy list surface (audit 2026-09-21, M-20): the filter chips stay
            // the header of the same scroll view — passed as `header`, they
            // keep scrolling away with the rows instead of being pinned, and
            // no nested scrollable is created.
            return _resultsView(context, state, l10n, text, scheme);
          },
        ),
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    MatterState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final MatterCubit cubit = context.read<MatterCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.matterEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return ViewStateList<Matter>(
      state: state.visibleMattersState,
      onRetry: cubit.load,
      tileBuilder: (BuildContext context, Matter matter) => AppTile(
        icon: Icons.folder_outlined,
        title: matter.title,
        subtitles: <String>[
          '${practiceAreaLabel(l10n, matter.practiceArea)} · ${matter.assignedAttorneyName}',
        ],
        trailing: Wrap(
          spacing: LegalHubTheme.spaceSm,
          runSpacing: LegalHubTheme.spaceSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            MatterStatusChip(label: matterStatusLabel(l10n, matter.status)),
          ],
        ),
        onTap: () => context.go(AppRoutes.matterDetail(matter.id)),
      ),
      header: <Widget>[
        AppFilterChips<MatterStatus>(
          values: MatterStatus.values,
          selected: state.status,
          allLabel: l10n.matterFilterAll,
          labelOf: (MatterStatus status) => matterStatusLabel(l10n, status),
          onSelected: cubit.setStatus,
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
      ],
      empty: empty,
      errorCopy: l10n.matterError,
      localOnlyNote: l10n.matterLocalOnlyNote,
      listPadding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
    );
  }
}
