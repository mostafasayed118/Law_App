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
part 'ai_research_denied_state.dart';
part 'ai_research_surface.dart';
part 'ai_research_idle_or_no_match.dart';
part 'ai_research_finding_card.dart';

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
