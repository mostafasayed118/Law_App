part of 'search_screen.dart';

/// The interactive surface — a child of the [SearchCubit] provider so its
/// state can read the cubit on open (the vault/matters pattern).
class _SearchSurface extends StatefulWidget {
  const _SearchSurface({
    required this.capabilities,
    required this.initialQuery,
  });

  final RoleCapability capabilities;
  final String initialQuery;

  @override
  State<_SearchSurface> createState() => _SearchSurfaceState();
}

class _SearchSurfaceState extends State<_SearchSurface> {
  late final TextEditingController _queryController = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Seed the first search from the `q` query param after the first frame
    // (the vault/matters pattern); a blank param stays in the no-query state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.initialQuery.trim().isNotEmpty) {
        context.read<SearchCubit>().search(
          widget.initialQuery,
          l10n: AppLocalizations.of(context),
        );
      }
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<SearchCubit>().search(
          value,
          l10n: AppLocalizations.of(context),
        );
      }
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    context.read<SearchCubit>().search(
      value,
      l10n: AppLocalizations.of(context),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // The query field sits ABOVE the BlocBuilder on purpose: every cubit
    // emission used to rebuild the field (and the whole eager tile list)
    // with it. The field keeps its own controller state, so hoisting it
    // out of the builder drops one full subtree rebuild per emission with
    // zero behavior change.
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          children: <Widget>[
            LegalHubTextField(
              controller: _queryController,
              hint: l10n.searchPlaceholder,
              prefixIcon: Icons.search,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _submit,
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            BlocBuilder<SearchCubit, SearchState>(
              buildWhen: (SearchState prev, SearchState curr) =>
                  prev.results != curr.results || prev.query != curr.query,
              builder: (BuildContext context, SearchState state) {
                return _resultsView(context, state, l10n, text, scheme);
              },
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            Text(
              l10n.searchLocalOnlyNote,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView(
    BuildContext context,
    SearchState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final SearchCubit cubit = context.read<SearchCubit>();
    final Widget noQuery = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.searchNoQuery,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.searchEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    // A blank/whitespace query shows the no-query state, not results (D-S4).
    if (state.isNoQuery) {
      return noQuery;
    }
    return ViewStateSwitch<SearchResults>(
      state: state.results,
      onRetry: () => cubit.search(state.query, l10n: l10n),
      builder: (BuildContext context, SearchResults results) =>
          _grouped(context, results, l10n, empty),
      empty: empty,
      errorCopy: l10n.searchError,
    );
  }

  Widget _grouped(
    BuildContext context,
    SearchResults results,
    AppLocalizations l10n,
    Widget empty,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final List<Widget> sections = <Widget>[];
    if (widget.capabilities.canViewMatters && results.matters.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.matterTitle,
          children: <Widget>[
            for (final Matter matter in results.matters) ...<Widget>[
              _matterTile(context, l10n, matter),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    if (widget.capabilities.canViewDocuments && results.documents.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.vaultTitle,
          children: <Widget>[
            for (final Document document in results.documents) ...<Widget>[
              _documentTile(context, l10n, document),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    if (widget.capabilities.canViewMessages && results.threads.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.messagesTitle,
          children: <Widget>[
            for (final MessageThread thread in results.threads) ...<Widget>[
              _threadTile(context, l10n, thread),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    if (widget.capabilities.canViewAttorneyDiscovery &&
        results.attorneys.isNotEmpty) {
      sections.add(
        AppSectionHeader(
          title: l10n.discoveryTitle,
          children: <Widget>[
            for (final Attorney attorney in results.attorneys) ...<Widget>[
              _attorneyTile(context, l10n, attorney, scheme),
              const SizedBox(height: LegalHubTheme.spaceSm),
            ],
          ],
        ),
      );
    }
    // Every group hidden by capability (or every subset empty) renders the
    // same localized empty copy rather than a blank surface. A partial
    // search (one or more failed groups) keeps the good sections and
    // prefixes the same unavailable notice in both cases, so a dropped
    // seam is never silent (audit: fail-fast search).
    final Widget? partialNotice = results.isPartial
        ? Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: LegalHubTheme.spaceMd,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(
                  child: Text(
                    l10n.searchPartialUnavailable,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;
    if (sections.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (partialNotice case final Widget notice) notice,
          empty,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (partialNotice case final Widget notice) ...<Widget>[
          notice,
          const SizedBox(height: LegalHubTheme.spaceLg),
        ],
        for (int i = 0; i < sections.length; i++) ...<Widget>[
          sections[i],
          if (i < sections.length - 1)
            const SizedBox(height: LegalHubTheme.spaceLg),
        ],
      ],
    );
  }

  Widget _chipWrap({required List<Widget> children}) {
    return Wrap(
      spacing: LegalHubTheme.spaceSm,
      runSpacing: LegalHubTheme.spaceSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _matterTile(
    BuildContext context,
    AppLocalizations l10n,
    Matter matter,
  ) {
    return AppTile(
      icon: Icons.folder_outlined,
      title: demoMatterTitle(l10n, matter.title),
      subtitles: <String>[
        '${practiceAreaLabel(l10n, matter.practiceArea)} · ${matter.assignedAttorneyName}',
      ],
      trailing: _chipWrap(
        children: <Widget>[
          MatterStatusChip(label: matterStatusLabel(l10n, matter.status)),
        ],
      ),
      // E2E BUG-1 fix: search result → detail is a forward nav.
      onTap: () => context.push(AppRoutes.matterDetail(matter.id)),
    );
  }

  Widget _documentTile(
    BuildContext context,
    AppLocalizations l10n,
    Document document,
  ) {
    return AppTile(
      icon: Icons.folder_outlined,
      title: demoDocumentTitle(l10n, document.title),
      subtitles: <String>[
        '${documentTypeLabel(l10n, document.type)} · ${formatMediumDate(l10n, document.createdAt)}',
      ],
      trailing: _chipWrap(
        children: <Widget>[
          DocumentTypeChip(label: documentTypeLabel(l10n, document.type)),
        ],
      ),
      onTap: () => context.push(AppRoutes.vault),
    );
  }

  Widget _threadTile(
    BuildContext context,
    AppLocalizations l10n,
    MessageThread thread,
  ) {
    return AppTile(
      icon: Icons.forum_outlined,
      title: demoThreadTitle(l10n, thread.title),
      subtitles: <String>[
        '${thread.participants.join(', ')} · ${formatMediumDate(l10n, thread.lastActivityAt)}',
      ],
      trailing: _chipWrap(
        children: <Widget>[
          MessageCountChip(
            label: l10n.messagesMessageCount(thread.messageCount),
          ),
        ],
      ),
      onTap: () => context.push(AppRoutes.messages),
    );
  }

  Widget _attorneyTile(
    BuildContext context,
    AppLocalizations l10n,
    Attorney attorney,
    ColorScheme scheme,
  ) {
    return AppTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          attorney.name.isEmpty
              ? '?'
              : attorney.name.substring(0, 1).toUpperCase(),
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
      title: attorney.name,
      subtitles: <String>[
        if (attorney.practiceArea != null || attorney.locale.isNotEmpty)
          <String>[
            if (attorney.practiceArea != null)
              practiceAreaLabel(l10n, attorney.practiceArea!),
            if (attorney.locale.isNotEmpty) attorney.locale,
          ].join(' · '),
      ],
      onTap: () => context.push(AppRoutes.attorneyProfile(attorney.id)),
    );
  }
}
