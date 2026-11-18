import 'package:equatable/equatable.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/matters/domain/matter.dart';

/// Roles a user can enter for an identified party. Pure wizard input: no
/// server enum, no backend write, no inference from gateway data.
enum ConflictPartyRole { adverseParty, coCounsel, relatedEntity, keyWitness }

/// One user-entered party. Session-only: never persisted by this feature and
/// never presented as gateway data.
class ConflictParty extends Equatable {
  const ConflictParty({
    required this.name,
    required this.role,
    required this.jurisdiction,
  });

  final String name;
  final ConflictPartyRole role;
  final String jurisdiction;

  @override
  List<Object?> get props => <Object?>[name, role, jurisdiction];
}

/// How one real gateway match relates to the selected matter.
///
/// [direct] means the party matched an attorney/client of a matter OTHER than
/// the selected one; [indirect] means the only match is the selected matter.
enum ConflictMatchKind { direct, indirect }

/// One real match from the matter gateway. Never a fabricated row.
class ConflictFinding extends Equatable {
  const ConflictFinding({
    required this.partyName,
    required this.kind,
    required this.matterId,
    required this.matterTitle,
  });

  final String partyName;
  final ConflictMatchKind kind;
  final String matterId;
  final String matterTitle;

  @override
  List<Object?> get props => <Object?>[partyName, kind, matterId, matterTitle];
}

/// Deterministic, local analysis result. Counts and findings come only from
/// the matter gateway; there is no score, model, or invented timestamp.
class ConflictAnalysis extends Equatable {
  const ConflictAnalysis({
    required this.checkedPartyCount,
    required this.checkedMatterCount,
    required this.findings,
  });

  final int checkedPartyCount;
  final int checkedMatterCount;
  final List<ConflictFinding> findings;

  bool get hasMatches => findings.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    checkedPartyCount,
    checkedMatterCount,
    findings,
  ];
}

/// The four visible steps plus the terminal success step of one route wizard.
enum DisclosureStep { matter, parties, analysis, review, success }

/// Submit lifecycle, kept separate from the visible step.
enum DisclosureSubmitStatus { idle, submitting, success, error }

/// The partial disclosure owned by [DisclosureCubit], never by route params.
class DisclosureDraft extends Equatable {
  const DisclosureDraft({
    this.matter,
    this.parties = const <ConflictParty>[],
    this.certified = false,
  });

  final Matter? matter;
  final List<ConflictParty> parties;
  final bool certified;

  DisclosureDraft copyWith({
    Object? matter = _unset,
    List<ConflictParty>? parties,
    bool? certified,
  }) {
    return DisclosureDraft(
      matter: identical(matter, _unset) ? this.matter : matter as Matter?,
      parties: parties ?? this.parties,
      certified: certified ?? this.certified,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[matter, parties, certified];
}

/// Immutable state of the disclosure wizard.
class DisclosureState extends Equatable {
  const DisclosureState({
    this.step = DisclosureStep.matter,
    this.draft = const DisclosureDraft(),
    this.query = '',
    this.matters = const ViewLoading<List<Matter>>(),
    this.analysis,
    this.submitStatus = DisclosureSubmitStatus.idle,
    this.submitError,
  });

  final DisclosureStep step;
  final DisclosureDraft draft;
  final String query;
  final ViewState<List<Matter>> matters;
  final ConflictAnalysis? analysis;
  final DisclosureSubmitStatus submitStatus;
  final Object? submitError;

  DisclosureState copyWith({
    DisclosureStep? step,
    DisclosureDraft? draft,
    String? query,
    ViewState<List<Matter>>? matters,
    Object? analysis = _unset,
    DisclosureSubmitStatus? submitStatus,
    Object? submitError = _unset,
  }) {
    return DisclosureState(
      step: step ?? this.step,
      draft: draft ?? this.draft,
      query: query ?? this.query,
      matters: matters ?? this.matters,
      analysis: identical(analysis, _unset)
          ? this.analysis
          : analysis as ConflictAnalysis?,
      submitStatus: submitStatus ?? this.submitStatus,
      submitError: identical(submitError, _unset)
          ? this.submitError
          : submitError,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[
    step,
    draft,
    query,
    matters,
    analysis,
    submitStatus,
    submitError,
  ];
}
