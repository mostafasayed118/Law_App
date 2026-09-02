import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/ai_finding.dart';
import '../domain/ai_gateway.dart';
import 'ai_research_cubit.dart';
import 'ai_research_state.dart';

/// AI research-assistant surface (`/research`; AI research slice 1.1, plan
/// 2026-09-02).
///
/// Demo-posture synthetic research (ratified scope decisions A-1/D-1): a
/// query field drives the `SyntheticAiGateway` engine and the findings of
/// the **latest** query render below (D-R2 — last answer only; no
/// transcript). Rails pinned structurally:
/// - the **"AI-suggested, not legal advice" banner is persistent on every
///   render state** — idle, loading, success, empty, error (C-3);
/// - **every finding's citation row renders unconditionally** (C-2/B-3);
/// - **no save/apply/export affordance exists anywhere** (C-4/D-3) —
///   findings are advisory-only and nothing is persisted (C-1).
///
/// D-R1 gating: a role without [RoleCapability.canUseAiResearch] (client /
/// complianceOfficer / admin reaching the route by deep link) gets the
/// distinct denial arm — never the research surface and never an
/// empty-success (the platform-admin AC-7 pattern).
class AiResearchScreen extends StatelessWidget {
  const AiResearchScreen({required this.capabilities, super.key});

  /// The active membership's role capabilities (UX projection — mirrors the
  /// shell; a navigation hint, never an authorization grant).
  final RoleCapability capabilities;

  @override
  Widget build(BuildContext context) {
    if (!capabilities.canUseAiResearch) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).aiResearchTitle),
        ),
        body: const _DeniedState(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).aiResearchTitle)),
      body: BlocProvider<AiResearchCubit>(
        create: (BuildContext context) =>
            AiResearchCubit(serviceLocator<AiGateway>()),
        child: const _ResearchSurface(),
      ),
    );
  }
}

/// Distinct D-R1 denial: the research surface is a legal-team-facing demo
/// (owner decision 2026-09-02). No retry — the gate is the role, not a
/// transient failure. The persistent banner stays off here: the denied
/// caller never reached the advisory surface (C-3 governs its renders).
class _DeniedState extends StatelessWidget {
  const _DeniedState();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.stateUnauthorized,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

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
                return ViewStateSwitch<List<AiFinding>>(
                  state: state.findings,
                  onRetry: () =>
                      context.read<AiResearchCubit>().research(state.lastQuery),
                  builder: (BuildContext context, List<AiFinding> findings) =>
                      findings.isEmpty
                      ? _IdleOrNoMatch(state: state)
                      : ListView(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: LegalHubTheme.marginMobile,
                          ),
                          children: <Widget>[
                            for (final AiFinding finding
                                in findings) ...<Widget>[
                              _FindingCard(finding: finding),
                              const SizedBox(height: LegalHubTheme.spaceMd),
                            ],
                            const SizedBox(height: LegalHubTheme.spaceLg),
                            Text(
                              l10n.aiResearchLocalOnlyNote,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                  empty: _IdleOrNoMatch(state: state),
                  errorCopy: l10n.aiResearchError,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The idle prompt (no query submitted yet) and the honest no-match empty
/// state share this arm — the [AiResearchState.lastQuery] distinguishes the
/// two. The persistent banner lives above this widget, so both states keep
/// it on-screen (C-3).
class _IdleOrNoMatch extends StatelessWidget {
  const _IdleOrNoMatch({required this.state});

  final AiResearchState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: Center(
        child: Text(
          state.lastQuery.isEmpty
              ? l10n.aiResearchIdlePrompt
              : l10n.aiResearchNoMatches,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// One advisory finding with its **unconditional citation row** (C-2/B-3).
/// The card carries no tap target and no trailing action — advisory-only
/// means nothing here saves, applies, or exports (C-4/D-3).
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final AiFinding finding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(finding.headline, style: text.titleMedium),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(finding.summary, style: text.bodyMedium),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              finding.excerpt,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            // The citation row renders unconditionally — sources are never
            // toggleable (C-2). Static labels, no affordances.
            Text(
              l10n.aiResearchCitationsLabel,
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            for (final AiSource source in finding.sources)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: LegalHubTheme.spaceXs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      source.kind == AiSourceKind.document
                          ? Icons.description_outlined
                          : Icons.folder_outlined,
                      size: 16,
                      color: scheme.outline,
                    ),
                    const SizedBox(width: LegalHubTheme.spaceXs),
                    Expanded(
                      child: Text(
                        '${source.title} — ${source.detail}',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
