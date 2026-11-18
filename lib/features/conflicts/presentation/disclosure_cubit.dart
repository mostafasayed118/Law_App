import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_motion.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/conflicts/domain/conflict_disclosure.dart';
import 'package:legalhub/features/conflicts/domain/conflict_search_source.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';

/// Single owner of the four-step disclosure wizard (one `/conflicts/disclose`
/// route, steps as views — the `/book` pattern). The draft never travels in a
/// route parameter. All displayed values come from the matter/alerts gateways
/// or from the user's own input this session.
class DisclosureCubit extends Cubit<DisclosureState> {
  DisclosureCubit({
    required this._matters,
    required this._search,
    required this._alerts,
    required this._org,
  }) : super(const DisclosureState());

  final MatterGateway _matters;
  final ConflictSearchSource _search;
  final ComplianceAlertsGateway _alerts;
  final ActiveOrgStore _org;

  Timer? _debounce;
  int _request = 0;

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> loadMatters() async {
    final int request = ++_request;
    emit(state.copyWith(matters: const ViewLoading<List<Matter>>()));
    final Result<List<Matter>> result = await _matters.fetchMatters();
    if (isClosed || request != _request) {
      return;
    }
    emit(
      state.copyWith(
        matters: switch (result) {
          Success<List<Matter>>(value: final List<Matter> matters) =>
            matters.isEmpty
                ? const ViewEmpty<List<Matter>>()
                : ViewSuccess<List<Matter>>(matters),
          Failure<List<Matter>>(error: final AppError error) =>
            viewStateForFailure<List<Matter>>(error),
        },
      ),
    );
  }

  /// Debounced field-facing search; matches use the matter gateway's own
  /// substring search, refined in [ConflictSearchSource].
  void queryChanged(String query) {
    _debounce?.cancel();
    emit(state.copyWith(query: query));
    _debounce = Timer(LegalHubMotion.debounce, () {
      if (!isClosed) {
        unawaited(_searchMatters(query));
      }
    });
  }

  Future<void> searchMatters(String query) async {
    _debounce?.cancel();
    emit(state.copyWith(query: query));
    await _searchMatters(query);
  }

  Future<void> _searchMatters(String query) async {
    final int request = ++_request;
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      await loadMatters();
      return;
    }
    emit(state.copyWith(matters: const ViewLoading<List<Matter>>()));
    final Result<List<Matter>> result = await _matters.searchMatters(needle);
    if (isClosed || request != _request) {
      return;
    }
    emit(
      state.copyWith(
        matters: switch (result) {
          Success<List<Matter>>(value: final List<Matter> matters) =>
            matters.isEmpty
                ? const ViewEmpty<List<Matter>>()
                : ViewSuccess<List<Matter>>(
                    matters
                        .where(
                          (Matter m) =>
                              m.title.toLowerCase().contains(needle) ||
                              m.assignedAttorneyName.toLowerCase().contains(
                                needle,
                              ),
                        )
                        .toList(growable: false),
                  ),
          Failure<List<Matter>>(error: final AppError error) =>
            viewStateForFailure<List<Matter>>(error),
        },
      ),
    );
  }

  void selectMatter(Matter matter) {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(draft: state.draft.copyWith(matter: matter)));
  }

  void nextFromMatter() {
    if (isClosed ||
        state.draft.matter == null ||
        state.step != DisclosureStep.matter) {
      return;
    }
    emit(state.copyWith(step: DisclosureStep.parties));
  }

  void addParty({
    required String name,
    required ConflictPartyRole role,
    required String jurisdiction,
  }) {
    if (isClosed || state.step != DisclosureStep.parties) {
      return;
    }
    final String clean = name.trim();
    if (clean.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        draft: state.draft.copyWith(
          parties: <ConflictParty>[
            ...state.draft.parties,
            ConflictParty(
              name: clean,
              role: role,
              jurisdiction: jurisdiction.trim(),
            ),
          ],
        ),
      ),
    );
  }

  void removeParty(int index) {
    if (isClosed || state.step != DisclosureStep.parties) {
      return;
    }
    final List<ConflictParty> parties = List<ConflictParty>.from(
      state.draft.parties,
    );
    if (index < 0 || index >= parties.length) {
      return;
    }
    parties.removeAt(index);
    emit(state.copyWith(draft: state.draft.copyWith(parties: parties)));
  }

  /// Runs the real, deterministic local check. No score, no AI, no timestamp.
  Future<void> nextFromParties() async {
    if (isClosed || state.step != DisclosureStep.parties) {
      return;
    }
    final Matter? selected = state.draft.matter;
    if (selected == null) {
      return;
    }
    emit(state.copyWith(step: DisclosureStep.analysis));
    final int available = await _search.availableMatterCount();
    final List<ConflictFinding> findings = <ConflictFinding>[];
    for (final ConflictParty party in state.draft.parties) {
      final List<Matter> matches = await _search.matchesForParty(party.name);
      for (final Matter matter in matches) {
        findings.add(
          ConflictFinding(
            partyName: party.name,
            kind: matter.id == selected.id
                ? ConflictMatchKind.indirect
                : ConflictMatchKind.direct,
            matterId: matter.id,
            matterTitle: matter.title,
          ),
        );
      }
    }
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        analysis: ConflictAnalysis(
          checkedPartyCount: state.draft.parties.length,
          checkedMatterCount: available,
          findings: findings,
        ),
      ),
    );
  }

  void nextFromAnalysis() {
    if (isClosed ||
        state.step != DisclosureStep.analysis ||
        state.analysis == null) {
      return;
    }
    emit(state.copyWith(step: DisclosureStep.review));
  }

  void edit(DisclosureStep step) {
    if (isClosed ||
        state.step != DisclosureStep.review ||
        step == DisclosureStep.success ||
        step == DisclosureStep.review) {
      return;
    }
    emit(state.copyWith(step: step));
  }

  void back() {
    if (isClosed) {
      return;
    }
    final DisclosureStep? previous = switch (state.step) {
      DisclosureStep.parties => DisclosureStep.matter,
      DisclosureStep.analysis => DisclosureStep.parties,
      DisclosureStep.review => DisclosureStep.analysis,
      DisclosureStep.matter || DisclosureStep.success => null,
    };
    if (previous != null) {
      emit(
        state.copyWith(
          step: previous,
          submitStatus: DisclosureSubmitStatus.idle,
        ),
      );
    }
  }

  void setCertified(bool value) {
    if (isClosed || state.step != DisclosureStep.review) {
      return;
    }
    emit(state.copyWith(draft: state.draft.copyWith(certified: value)));
  }

  /// Submits through the EXISTING compliance-alert gateway — the same create
  /// path the compliance-alert create sheet uses (`create_compliance_alert`).
  /// No new mutation is invented.
  Future<void> submit() async {
    if (isClosed ||
        state.step != DisclosureStep.review ||
        !state.draft.certified ||
        state.submitStatus == DisclosureSubmitStatus.submitting ||
        state.submitStatus == DisclosureSubmitStatus.success) {
      return;
    }
    final Matter? matter = state.draft.matter;
    final String? organizationId = _org.activeOrganizationId;
    if (matter == null || organizationId == null) {
      return;
    }
    final ConflictAnalysis? analysis = state.analysis;
    final String summary = <String>[
      'Matter: ${matter.id} — ${matter.title}',
      'Parties: ${state.draft.parties.map((ConflictParty p) => '${p.name} (${p.role.name})').join(', ')}',
      'Findings: ${analysis == null ? 0 : analysis.findings.length}',
      for (final ConflictFinding finding
          in analysis?.findings ?? const <ConflictFinding>[])
        '${finding.kind.name}: ${finding.partyName} → ${finding.matterId} (${finding.matterTitle})',
    ].join('\n');
    emit(state.copyWith(submitStatus: DisclosureSubmitStatus.submitting));
    final Result<String> result = await _alerts.create(
      ComplianceAlertDraft(
        organizationId: organizationId,
        matterId: matter.id,
        title: 'Conflict disclosure: ${matter.title}',
        kind: AlertKind.conflict,
        severity: AlertSeverity.high,
        description: summary,
      ),
    );
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        step: switch (result) {
          Success<String>() => DisclosureStep.success,
          Failure<String>() => DisclosureStep.review,
        },
        submitStatus: switch (result) {
          Success<String>() => DisclosureSubmitStatus.success,
          Failure<String>() => DisclosureSubmitStatus.error,
        },
        submitError: switch (result) {
          Success<String>() => null,
          Failure<String>(error: final AppError error) => error,
        },
      ),
    );
  }
}
