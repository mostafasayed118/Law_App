import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';
import 'package:legalhub/features/research/domain/research_wire_codes.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/l10n/app_message_l10n.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'ai_research_cubit.dart';
import 'ai_research_state.dart';

part 'ai_research_denied_state.dart';
part 'ai_research_finding_card.dart';
part 'ai_research_findings.dart';
part 'ai_research_idle_or_no_match.dart';
part 'ai_research_runs.dart';
part 'ai_research_surface.dart';

/// Research surface (`/research`; AI research slice 1.1; design §5).
///
/// Two postures share this screen:
/// - an env-less build answers from the synthetic demo corpus and says so in
///   the banner and footer;
/// - a configured build runs `research-analyze` against the caller's selected
///   matter/documents, lists persisted runs, and surfaces every failure
///   honestly — a missing provider secret renders an explicit unavailable
///   state, never a synthetic success.
///
/// Rails pinned structurally: the "AI-suggested / AI-generated — not legal
/// advice" banner persists in every render state, findings are advisory-only
/// (no save/apply/export affordance), and every finding's citation row renders
/// unconditionally.
///
/// D-R1 gating: a role without [RoleCapability.canUseAiResearch] gets the
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
        create: (BuildContext context) => AiResearchCubit(
          serviceLocator<AiGateway>(),
          mattersGateway: serviceLocator<MatterGateway>(),
          documentsGateway: serviceLocator<DocumentGateway>(),
        ),
        child: const _ResearchSurface(),
      ),
    );
  }
}

/// The active organization. The env-less demo has no session-backed org, so
/// it sends a clearly non-UUID demo value to the synthetic engine only; a
/// configured build never fabricates one and blocks generation instead.
///
/// Resolved here, in the composition file, so the surface reads no service
/// locator entry itself.
String? _researchOrganizationId() {
  final String? active = serviceLocator.isRegistered<ActiveOrgStore>()
      ? serviceLocator<ActiveOrgStore>().activeOrganizationId
      : null;
  if (active != null && active.isNotEmpty) {
    return active;
  }
  return backendIsLocalOnly ? DemoCorpus.organizationId : null;
}
