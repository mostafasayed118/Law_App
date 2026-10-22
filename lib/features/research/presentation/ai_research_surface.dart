part of 'ai_research_screen.dart';

class _ResearchSurface extends StatefulWidget {
  const _ResearchSurface();

  @override
  State<_ResearchSurface> createState() => _ResearchSurfaceState();
}

class _ResearchSurfaceState extends State<_ResearchSurface> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _question = TextEditingController();
  final Set<String> _selectedDocumentIds = <String>{};

  Result<List<Matter>>? _matters;
  Result<List<Document>>? _documents;
  bool _loadingLookups = true;
  String? _selectedMatterId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AiResearchCubit>().loadRuns();
      _loadLookups();
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  /// Loads both optional pickers in parallel. A failed lookup renders inline
  /// with its own reload affordance and never blocks generation — the matter
  /// and documents are optional context.
  Future<void> _loadLookups() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingLookups = true;
      _matters = null;
      _documents = null;
    });
    final Future<Result<List<Matter>>> mattersFuture = serviceLocator<
      MatterGateway
    >().fetchMatters();
    final Future<Result<List<Document>>> documentsFuture = serviceLocator<
      DocumentGateway
    >().fetchDocuments();
    final Result<List<Matter>> matters = await mattersFuture;
    final Result<List<Document>> documents = await documentsFuture;
    if (!mounted) {
      return;
    }
    setState(() {
      _matters = matters;
      _documents = documents;
      _loadingLookups = false;
      final List<Matter> matterRows =
          matters.valueOrNull ?? const <Matter>[];
      if (_selectedMatterId != null &&
          !matterRows.any((Matter m) => m.id == _selectedMatterId)) {
        _selectedMatterId = null;
      }
      final Set<String> available = <String>{
        for (final Document document
            in documents.valueOrNull ?? const <Document>[])
          document.id,
      };
      _selectedDocumentIds.removeWhere(
        (String id) => !available.contains(id),
      );
    });
  }

  /// The active organization. The env-less demo has no session-backed org, so
  /// it sends a clearly non-UUID demo value to the synthetic engine only; a
  /// configured build never fabricates one and blocks generation instead.
  String? get _organizationId {
    final String? active = serviceLocator.isRegistered<ActiveOrgStore>()
        ? serviceLocator<ActiveOrgStore>().activeOrganizationId
        : null;
    if (active != null && active.isNotEmpty) {
      return active;
    }
    return backendIsLocalOnly ? 'demo-organization' : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? organizationId = _organizationId;
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
        backendIsLocalOnly || _organizationId != null;
    return SafeArea(
      child: BlocBuilder<AiResearchCubit, AiResearchState>(
        builder: (BuildContext context, AiResearchState state) {
          final bool loading =
              state.findings is ViewLoading<List<AiFinding>>;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                _AdvisoryBanner(localOnly: backendIsLocalOnly),
                const SizedBox(height: LegalHubTheme.spaceMd),
                LegalHubTextField(
                  controller: _question,
                  label: l10n.aiResearchQuestionLabel,
                  hint: l10n.aiResearchFieldHint,
                  prefixIcon: Icons.auto_awesome_outlined,
                  maxLength: ResearchRequest.maxQuestionLength,
                  textInputAction: TextInputAction.search,
                  validator: (String? value) =>
                      _validateQuestion(l10n, value),
                  onSubmitted: (String _) {
                    if (!loading) {
                      _submit();
                    }
                  },
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
                _matterPicker(l10n, locked: loading),
                const SizedBox(height: LegalHubTheme.spaceMd),
                _documentsPicker(l10n, locked: loading),
                const SizedBox(height: LegalHubTheme.spaceMd),
                if (!hasOrganization) ...<Widget>[
                  Text(
                    l10n.aiResearchErrorNoOrg,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(
                              width: LegalHubTheme.spaceSm,
                            ),
                            Text(l10n.stateLoading),
                          ],
                        )
                      : Text(l10n.aiResearchGenerate),
                ),
                const SizedBox(height: LegalHubTheme.spaceLg),
                _RunsHistory(
                  runs: state.runs,
                  onOpen: (ResearchRun run) => context
                      .read<AiResearchCubit>()
                      .loadRunFindings(run.id),
                  onRetry: () =>
                      context.read<AiResearchCubit>().loadRuns(),
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
              ],
            ),
          );
        },
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

  Widget _matterPicker(AppLocalizations l10n, {required bool locked}) {
    if (_loadingLookups) {
      return const LinearProgressIndicator();
    }
    if (_matters is Failure<List<Matter>>) {
      return _LookupError(
        message: l10n.aiResearchMattersError,
        onReload: _loadLookups,
      );
    }
    final List<Matter> matters =
        _matters?.valueOrNull ?? const <Matter>[];
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

  Widget _documentsPicker(AppLocalizations l10n, {required bool locked}) {
    if (_loadingLookups) {
      return const LinearProgressIndicator();
    }
    final Widget rows = switch (_documents) {
      Failure<List<Document>>() => _LookupError(
        message: l10n.aiResearchDocumentsError,
        onReload: _loadLookups,
      ),
      Success<List<Document>>(value: final List<Document> documents)
          when documents.isEmpty =>
        Text(
          l10n.aiResearchDocumentsNone,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      Success<List<Document>>(value: final List<Document> documents) => Wrap(
        spacing: LegalHubTheme.spaceXs,
        runSpacing: LegalHubTheme.spaceXs,
        children: <Widget>[
          for (final Document document in documents)
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
      ),
      _ => const SizedBox.shrink(),
    };
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
