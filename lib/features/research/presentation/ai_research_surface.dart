part of 'ai_research_screen.dart';

class _ResearchSurface extends StatefulWidget {
  const _ResearchSurface();

  @override
  State<_ResearchSurface> createState() => _ResearchSurfaceState();
}

class _ResearchSurfaceState extends State<_ResearchSurface> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AiResearchCubit>().research(_queryController.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceMd,
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceXs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(
                  child: Text(
                    l10n.aiResearchAdvisoryBanner,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LegalHubTheme.marginMobile,
              0,
              LegalHubTheme.marginMobile,
              LegalHubTheme.spaceMd,
            ),
            child: LegalHubTextField(
              controller: _queryController,
              hint: l10n.aiResearchFieldHint,
              prefixIcon: Icons.search,
              textInputAction: TextInputAction.search,
              onSubmitted: (String _) => _submit(),
            ),
          ),
          Expanded(
            child: BlocBuilder<AiResearchCubit, AiResearchState>(
              builder: (BuildContext context, AiResearchState state) {
                // Lazy list surface (audit 2026-09-21, M-20): the success arm
                // was a Column of every card inside a non-lazy ListView, so
                // card culling never applied.
                return ViewStateList<AiFinding>(
                  state: state.findings,
                  onRetry: () =>
                      context.read<AiResearchCubit>().research(state.lastQuery),
                  tileBuilder: (BuildContext context, AiFinding finding) =>
                      _FindingCard(finding: finding),
                  empty: _IdleOrNoMatch(state: state),
                  errorCopy: l10n.aiResearchError,
                  localOnlyNote: l10n.aiResearchLocalOnlyNote,
                  listPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: LegalHubTheme.marginMobile,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
