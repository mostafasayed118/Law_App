part of 'ai_research_screen.dart';

/// Upper bound on the eagerly built document-picker chips (the picker is
/// optional context; a capped vault must not expand the whole form).
const int _maxDocumentChips = 50;

class _ResearchSurface extends StatefulWidget {
  const _ResearchSurface();

  @override
  State<_ResearchSurface> createState() => _ResearchSurfaceState();
}

class _ResearchSurfaceState extends State<_ResearchSurface> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _question = TextEditingController();
  final Set<String> _selectedDocumentIds = <String>{};

  String? _selectedMatterId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final AiResearchCubit cubit = context.read<AiResearchCubit>();
      cubit.loadRuns();
      cubit.loadLookups();
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _reloadLookups() {
    context.read<AiResearchCubit>().loadLookups();
  }

  /// Drops a picked matter/document that the settled lookups no longer
  /// contain, so a request never carries an id the picker cannot show. Runs
  /// only on settled arms — a reload must not clear a still-valid selection
  /// while the new rows are in flight.
  void _pruneSelections(AiResearchState state) {
    if (state.matters is ViewLoading<List<Matter>> ||
        state.documents is ViewLoading<List<Document>>) {
      return;
    }
    List<Matter> matterRows = const <Matter>[];
    if (state.matters case ViewSuccess<List<Matter>>(
      data: final List<Matter> rows,
    )) {
      matterRows = rows;
    }
    final Set<String> documentIds = <String>{};
    if (state.documents case ViewSuccess<List<Document>>(
      data: final List<Document> rows,
    )) {
      documentIds.addAll(rows.map((Document document) => document.id));
    }
    final bool matterStale =
        _selectedMatterId != null &&
        !matterRows.any((Matter matter) => matter.id == _selectedMatterId);
    final bool documentsStale = _selectedDocumentIds.any(
      (String id) => !documentIds.contains(id),
    );
    if (!matterStale && !documentsStale) {
      return;
    }
    setState(() {
      if (matterStale) {
        _selectedMatterId = null;
      }
      _selectedDocumentIds.removeWhere(
        (String id) => !documentIds.contains(id),
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? organizationId = _researchOrganizationId();
    if (organizationId == null) {
      return;
    }
    context.read<AiResearchCubit>().generate(
      ResearchRequest(
        organizationId: organizationId,
        matterId: _selectedMatterId,
        documentIds: _selectedDocumentIds.toList(growable: false),
        question: _question.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool hasOrganization =
        backendIsLocalOnly || _researchOrganizationId() != null;
    return SafeArea(
      child: BlocListener<AiResearchCubit, AiResearchState>(
        listenWhen: (AiResearchState previous, AiResearchState current) =>
            previous.matters != current.matters ||
            previous.documents != current.documents,
        listener: (BuildContext context, AiResearchState state) =>
            _pruneSelections(state),
        child: BlocBuilder<AiResearchCubit, AiResearchState>(
          buildWhen: (AiResearchState previous, AiResearchState current) =>
              previous.findings != current.findings ||
              previous.runs != current.runs ||
              previous.matters != current.matters ||
              previous.documents != current.documents ||
              previous.lastQuery != current.lastQuery ||
              previous.lastError != current.lastError,
          builder: (BuildContext context, AiResearchState state) {
            final bool loading = state.findings is ViewLoading<List<AiFinding>>;
            final List<Widget> sections = <Widget>[
              _AdvisoryBanner(localOnly: backendIsLocalOnly),
              const SizedBox(height: LegalHubTheme.spaceMd),
              LegalHubTextField(
                controller: _question,
                label: l10n.aiResearchQuestionLabel,
                hint: l10n.aiResearchFieldHint,
                prefixIcon: Icons.auto_awesome_outlined,
                maxLength: ResearchRequest.maxQuestionLength,
                textInputAction: TextInputAction.search,
                validator: (String? value) => _validateQuestion(l10n, value),
                onSubmitted: (String _) {
                  if (!loading) {
                    _submit();
                  }
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              _matterPicker(l10n, state, locked: loading),
              const SizedBox(height: LegalHubTheme.spaceMd),
              _documentsPicker(l10n, state, locked: loading),
              const SizedBox(height: LegalHubTheme.spaceMd),
              if (!hasOrganization) ...<Widget>[
                Text(
                  l10n.aiResearchErrorNoOrg,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
              ],
              FilledButton(
                onPressed: loading || !hasOrganization ? null : _submit,
                child: loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: LegalHubTheme.spaceSm),
                          Text(l10n.stateLoading),
                        ],
                      )
                    : Text(l10n.aiResearchGenerate),
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              _RunsHistory(
                runs: state.runs,
                onOpen: (ResearchRun run) =>
                    context.read<AiResearchCubit>().loadRunFindings(run.id),
                onRetry: () => context.read<AiResearchCubit>().loadRuns(),
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              _FindingsSection(state: state, onRetry: _submit),
              const SizedBox(height: LegalHubTheme.spaceLg),
              Text(
                backendIsLocalOnly
                    ? l10n.aiResearchLocalOnlyNote
                    : l10n.aiResearchStoredNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ];
            return Form(
              key: _formKey,
              // Lazy list: the sections inflate on demand instead of
              // expanding the whole form tree on every state emission.
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.all(
                  LegalHubTheme.marginMobile,
                ),
                itemCount: sections.length,
                itemBuilder: (BuildContext context, int index) =>
                    sections[index],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateQuestion(AppLocalizations l10n, String? value) {
    final String text = (value ?? '').trim();
    if (text.length < ResearchRequest.minQuestionLength) {
      return l10n.aiResearchQuestionTooShort;
    }
    if (text.length > ResearchRequest.maxQuestionLength) {
      return l10n.aiResearchQuestionTooLong;
    }
    return null;
  }

  Widget _matterPicker(
    AppLocalizations l10n,
    AiResearchState state, {
    required bool locked,
  }) {
    final ViewState<List<Matter>> lookup = state.matters;
    if (lookup is ViewLoading<List<Matter>>) {
      return const LinearProgressIndicator();
    }
    if (lookup is ViewError<List<Matter>> ||
        lookup is ViewOffline<List<Matter>> ||
        lookup is ViewUnauthorized<List<Matter>>) {
      return _LookupError(
        message: l10n.aiResearchMattersError,
        onReload: _reloadLookups,
      );
    }
    final List<Matter> matters = lookup is ViewSuccess<List<Matter>>
        ? lookup.data
        : const <Matter>[];
    return DropdownButtonFormField<String?>(
      initialValue: _selectedMatterId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.aiResearchMatterLabel,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(child: Text(l10n.aiResearchMatterNone)),
        for (final Matter matter in matters)
          DropdownMenuItem<String?>(
            value: matter.id,
            child: Text(demoMatterTitle(l10n, matter.title)),
          ),
      ],
      onChanged: locked
          ? null
          : (String? value) => setState(() => _selectedMatterId = value),
    );
  }

  Widget _documentsPicker(
    AppLocalizations l10n,
    AiResearchState state, {
    required bool locked,
  }) {
    final ViewState<List<Document>> lookup = state.documents;
    if (lookup is ViewLoading<List<Document>>) {
      return const LinearProgressIndicator();
    }
    final Widget rows;
    if (lookup is ViewError<List<Document>> ||
        lookup is ViewOffline<List<Document>> ||
        lookup is ViewUnauthorized<List<Document>>) {
      rows = _LookupError(
        message: l10n.aiResearchDocumentsError,
        onReload: _reloadLookups,
      );
    } else if (lookup is ViewSuccess<List<Document>> &&
        lookup.data.isNotEmpty) {
      rows = Wrap(
        spacing: LegalHubTheme.spaceXs,
        runSpacing: LegalHubTheme.spaceXs,
        children: <Widget>[
          // shortcut: only the first _maxDocumentChips render as pickable
          // chips; add paging if a matter's vault routinely exceeds that.
          for (final Document document in lookup.data.take(_maxDocumentChips))
            FilterChip(
              label: Text(demoDocumentTitle(l10n, document.title)),
              selected: _selectedDocumentIds.contains(document.id),
              onSelected: locked
                  ? null
                  : (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedDocumentIds.add(document.id);
                        } else {
                          _selectedDocumentIds.remove(document.id);
                        }
                      });
                    },
            ),
        ],
      );
    } else {
      rows = Text(
        l10n.aiResearchDocumentsNone,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.aiResearchDocumentsLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceXs),
        rows,
      ],
    );
  }
}

/// The persistent advisory banner (C-3). The demo copy names the synthetic
/// posture; the configured copy states the AI-generated provenance. Both say
/// "not legal advice" — the no-false-assurance rule.
class _AdvisoryBanner extends StatelessWidget {
  const _AdvisoryBanner({required this.localOnly});

  final bool localOnly;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.auto_awesome_outlined, size: 18, color: scheme.primary),
        const SizedBox(width: LegalHubTheme.spaceSm),
        Expanded(
          child: Text(
            localOnly
                ? l10n.aiResearchAdvisoryBanner
                : l10n.aiResearchGeneratedNotice,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LookupError extends StatelessWidget {
  const _LookupError({required this.message, required this.onReload});

  final String message;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: onReload,
          child: Text(AppLocalizations.of(context).aiResearchReload),
        ),
      ],
    );
  }
}
