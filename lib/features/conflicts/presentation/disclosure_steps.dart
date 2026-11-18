part of 'disclosure_wizard_screen.dart';

class _DisclosureWizard extends StatelessWidget {
  const _DisclosureWizard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conflictsDiscloseTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () => context.go(AppRoutes.alerts),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.conflictsIdentifyBody,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: Text(l10n.conflictsDiscloseTitle),
                content: Text(l10n.conflictsIdentifyBody),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DisclosureCubit, DisclosureState>(
          builder: (BuildContext context, DisclosureState state) {
            if (state.step == DisclosureStep.success) {
              return const _SuccessStep();
            }
            return Column(
              children: <Widget>[
                _Progress(step: state.step),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.all(
                      LegalHubTheme.marginMobile,
                    ),
                    children: <Widget>[
                      switch (state.step) {
                        DisclosureStep.matter => const _MatterStep(),
                        DisclosureStep.parties => const _PartyStep(),
                        DisclosureStep.analysis => const _AnalysisStep(),
                        DisclosureStep.review => const _ReviewStep(),
                        DisclosureStep.success => const SizedBox.shrink(),
                      },
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final DisclosureStep step;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<DisclosureStep> steps = <DisclosureStep>[
      DisclosureStep.matter,
      DisclosureStep.parties,
      DisclosureStep.analysis,
      DisclosureStep.review,
    ];
    final int current = steps.indexOf(step);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: LegalHubTheme.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < steps.length; i++) ...<Widget>[
            Expanded(
              child: _ProgressChip(
                label: switch (steps[i]) {
                  DisclosureStep.matter => l10n.conflictsStepMatter,
                  DisclosureStep.parties => l10n.conflictsStepParties,
                  DisclosureStep.analysis => l10n.conflictsStepAnalysis,
                  DisclosureStep.review => l10n.conflictsStepReview,
                  DisclosureStep.success => '',
                },
                number: i + 1,
                done: i < current,
                active: i == current,
              ),
            ),
            if (i < steps.length - 1)
              const SizedBox(width: LegalHubTheme.spaceXs),
          ],
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.label,
    required this.number,
    required this.done,
    required this.active,
  });

  final String label;
  final int number;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: LegalHubTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: active
            ? scheme.primaryContainer
            : scheme.surface.withValues(alpha: 0),
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusMd),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: LegalHubTheme.space2xs),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!done && !active)
            Text('$number', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MatterStep extends StatefulWidget {
  const _MatterStep();

  @override
  State<_MatterStep> createState() => _MatterStepState();
}

class _MatterStepState extends State<_MatterStep> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DisclosureCubit cubit = context.read<DisclosureCubit>();
    return BlocBuilder<DisclosureCubit, DisclosureState>(
      builder: (BuildContext context, DisclosureState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.conflictsIdentifyMatter,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.conflictsIdentifyBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          LegalHubTextField(
            controller: _query,
            hint: l10n.conflictsSearchMatters,
            prefixIcon: Icons.search,
            onChanged: (String value) {
              _debounce?.cancel();
              _debounce = Timer(LegalHubMotion.debounce, () {
                if (mounted) {
                  cubit.searchMatters(value);
                }
              });
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          Text(
            l10n.conflictsRecentMatters,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          switch (state.matters) {
            ViewSuccess<List<Matter>>(data: final List<Matter> matters) =>
              RadioGroup<String>(
                groupValue: state.draft.matter?.id,
                onChanged: (String? id) {
                  for (final Matter matter in matters) {
                    if (matter.id == id) {
                      cubit.selectMatter(matter);
                      break;
                    }
                  }
                },
                child: Column(
                  children: <Widget>[
                    for (final Matter matter in matters)
                      RadioListTile<String>(
                        value: matter.id,
                        title: Text(
                          DemoLabels(
                            l10n,
                            localOnly: backendIsLocalOnly,
                          ).matterTitle(matter.title),
                        ),
                        subtitle: Text(
                          l10n.conflictsLead(matter.assignedAttorneyName),
                        ),
                      ),
                  ],
                ),
              ),
            ViewEmpty<List<Matter>>() => Text(
              l10n.alertsEmptyFiltered,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            _ => const LinearProgressIndicator(),
          },
          const SizedBox(height: LegalHubTheme.spaceLg),
          FilledButton(
            onPressed: state.draft.matter == null ? null : cubit.nextFromMatter,
            child: Text(l10n.conflictsNextStep),
          ),
        ],
      ),
    );
  }
}

class _PartyStep extends StatefulWidget {
  const _PartyStep();

  @override
  State<_PartyStep> createState() => _PartyStepState();
}

class _PartyStepState extends State<_PartyStep> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _jurisdiction = TextEditingController();
  ConflictPartyRole _role = ConflictPartyRole.adverseParty;

  @override
  void dispose() {
    _name.dispose();
    _jurisdiction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DisclosureCubit cubit = context.read<DisclosureCubit>();
    return BlocBuilder<DisclosureCubit, DisclosureState>(
      builder: (BuildContext context, DisclosureState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.conflictsStepOf(2),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(
            l10n.conflictsPartyIdentification,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.conflictsPartyBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(
            l10n.conflictsAddInvolvedParty,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          LegalHubTextField(
            controller: _name,
            hint: l10n.conflictsPartyNameHint,
            label: l10n.conflictsPartyName,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          DropdownButtonFormField<ConflictPartyRole>(
            initialValue: _role,
            decoration: InputDecoration(labelText: l10n.conflictsPartyRole),
            items: <DropdownMenuItem<ConflictPartyRole>>[
              for (final ConflictPartyRole role in ConflictPartyRole.values)
                DropdownMenuItem<ConflictPartyRole>(
                  value: role,
                  child: Text(_roleLabel(l10n, role)),
                ),
            ],
            onChanged: (ConflictPartyRole? value) {
              if (value != null) {
                setState(() => _role = value);
              }
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          LegalHubTextField(
            controller: _jurisdiction,
            hint: l10n.conflictsPartyJurisdictionHint,
            label: l10n.conflictsPartyJurisdiction,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          OutlinedButton(
            onPressed: () {
              cubit.addParty(
                name: _name.text,
                role: _role,
                jurisdiction: _jurisdiction.text,
              );
              _name.clear();
              _jurisdiction.clear();
            },
            child: Text(l10n.conflictsAddParty),
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          Text(
            l10n.conflictsIdentifiedParties(state.draft.parties.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (int i = 0; i < state.draft.parties.length; i++)
            ListTile(
              title: Text(state.draft.parties[i].name),
              subtitle: Text(
                '${_roleLabel(l10n, state.draft.parties[i].role).toUpperCase()} · '
                '${state.draft.parties[i].jurisdiction}',
              ),
              trailing: TextButton(
                onPressed: () => cubit.removeParty(i),
                child: Text(l10n.conflictsRemoveParty),
              ),
            ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: cubit.back,
                  child: Text(l10n.conflictsBack),
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceSm),
              Expanded(
                child: FilledButton(
                  onPressed: state.draft.parties.isEmpty
                      ? null
                      : cubit.nextFromParties,
                  child: Text(l10n.conflictsNextStep),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, ConflictPartyRole role) =>
    switch (role) {
      ConflictPartyRole.adverseParty => l10n.conflictsRoleAdverse,
      ConflictPartyRole.coCounsel => l10n.conflictsRoleCoCounsel,
      ConflictPartyRole.relatedEntity => l10n.conflictsRoleRelated,
      ConflictPartyRole.keyWitness => l10n.conflictsRoleWitness,
    };

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<DisclosureCubit, DisclosureState>(
      builder: (BuildContext context, DisclosureState state) {
        final ConflictAnalysis? analysis = state.analysis;
        if (analysis == null) {
          return const LinearProgressIndicator();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.conflictsStepOf(3),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.conflictsAnalysisFindings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            Text(
              l10n.conflictsRiskAssessment,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              analysis.hasMatches
                  ? l10n.conflictsMatchFound
                  : l10n.conflictsNoMatches,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            Text(
              l10n.conflictsAnalysisSummary,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.conflictsCheckedParties(
                analysis.checkedMatterCount,
                analysis.checkedPartyCount,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LegalHubTheme.spaceLg),
            if (!analysis.hasMatches)
              Text(l10n.conflictsNoConflicts)
            else
              for (final ConflictFinding finding in analysis.findings)
                ListTile(
                  title: Text(finding.partyName),
                  subtitle: Text(
                    '${finding.kind == ConflictMatchKind.direct ? l10n.conflictsDirectMatch : l10n.conflictsIndirectLink} · '
                    '${finding.matterTitle} (${finding.matterId})',
                  ),
                  trailing: TextButton(
                    onPressed: () =>
                        context.go(AppRoutes.matterDetail(finding.matterId)),
                    child: Text(l10n.conflictsViewDetails),
                  ),
                ),
            if (analysis.hasMatches) ...<Widget>[
              const SizedBox(height: LegalHubTheme.spaceMd),
              Text(l10n.conflictsRecommendation),
            ],
            const SizedBox(height: LegalHubTheme.spaceLg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: context.read<DisclosureCubit>().back,
                    child: Text(l10n.conflictsBack),
                  ),
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(
                  child: FilledButton(
                    onPressed: context.read<DisclosureCubit>().nextFromAnalysis,
                    child: Text(l10n.conflictsContinueReview),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<DisclosureCubit, DisclosureState>(
      builder: (BuildContext context, DisclosureState state) {
        final Matter? matter = state.draft.matter;
        final ConflictAnalysis? analysis = state.analysis;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.conflictsStepOf(4),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              l10n.conflictsFinalReview,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.conflictsReviewBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            _ReviewSection(
              title: l10n.conflictsMatterDetails,
              onEdit: () =>
                  context.read<DisclosureCubit>().edit(DisclosureStep.matter),
              lines: <String>[
                '${l10n.conflictsMatterType}: ${matter?.practiceArea.name ?? ''}',
                '${l10n.conflictsDescription}: ${matter?.title ?? ''}',
              ],
            ),
            _ReviewSection(
              title: l10n.conflictsIdentifiedParties(
                state.draft.parties.length,
              ),
              onEdit: () =>
                  context.read<DisclosureCubit>().edit(DisclosureStep.parties),
              lines: <String>[
                for (final ConflictParty party in state.draft.parties)
                  '${party.name} · ${_roleLabel(l10n, party.role)}',
              ],
            ),
            _ReviewSection(
              title: l10n.conflictsAnalysisFindings,
              onEdit: () =>
                  context.read<DisclosureCubit>().edit(DisclosureStep.analysis),
              lines: <String>[
                if (analysis != null)
                  l10n.conflictsCheckedParties(
                    analysis.checkedMatterCount,
                    analysis.checkedPartyCount,
                  ),
                analysis == null
                    ? l10n.conflictsNoMatches
                    : analysis.hasMatches
                    ? l10n.conflictsMatchFound
                    : l10n.conflictsNoConflicts,
                if (analysis != null && analysis.hasMatches)
                  '${l10n.conflictsProposedResolution}: ${l10n.conflictsRecommendation}',
              ],
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            CheckboxListTile(
              value: state.draft.certified,
              onChanged: (bool? value) =>
                  context.read<DisclosureCubit>().setCertified(value ?? false),
              title: Text(l10n.conflictsCertifyLabel),
              subtitle: Text(l10n.conflictsCertification),
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: context.read<DisclosureCubit>().back,
                    child: Text(l10n.conflictsBack),
                  ),
                ),
                const SizedBox(width: LegalHubTheme.spaceSm),
                Expanded(
                  child: FilledButton(
                    onPressed: state.draft.certified
                        ? context.read<DisclosureCubit>().submit
                        : null,
                    child: Text(l10n.conflictsSubmitDisclosure),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.onEdit,
    required this.lines,
  });

  final String title;
  final VoidCallback onEdit;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(onPressed: onEdit, child: Text(l10n.conflictsEdit)),
            ],
          ),
          for (final String line in lines) Text(line),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 48),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(l10n.conflictsSubmitSuccess),
          const SizedBox(height: LegalHubTheme.spaceLg),
          FilledButton(
            onPressed: () => context.go(AppRoutes.alerts),
            child: Text(l10n.conflictsBack),
          ),
        ],
      ),
    );
  }
}
