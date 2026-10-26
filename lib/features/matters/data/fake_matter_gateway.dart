import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/pagination.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

/// Development-only matter implementation: a fixed synthetic list of
/// non-PII matter previews.
///
/// No real backend, no availability, no documents, no messaging (owner
/// decisions D-M1/D-M2/D-M4): [fetchMatters] returns the same deterministic
/// list on every call. Matters carry id / generic demo title / practice
/// area / status / assigned-attorney display name / created date only — no
/// client names or real-looking case numbers (D-M4), and titles are static
/// demo copy that must never read as a real case (R1). The list resolves
/// immediately (no artificial delay) so cubit/widget tests stay
/// timing-independent.
class FakeMatterGateway implements MatterGateway {
  /// The fixed synthetic matter list served by [fetchMatters].
  static final List<Matter> syntheticMatters = <Matter>[
    Matter(
      id: DemoCorpus.matterIds[0],
      title: DemoCorpus.matterTitleAcquisition,
      practiceArea: PracticeArea.corporate,
      status: MatterStatus.active,
      assignedAttorneyName: 'Layla Mansour',
      createdAt: DateTime.utc(2026, 7, 12),
    ),
    Matter(
      id: DemoCorpus.matterIds[1],
      title: DemoCorpus.matterTitleLease,
      practiceArea: PracticeArea.civil,
      status: MatterStatus.open,
      assignedAttorneyName: 'Omar Farouk',
      createdAt: DateTime.utc(2026, 7, 18),
    ),
    Matter(
      id: DemoCorpus.matterIds[2],
      title: DemoCorpus.matterTitleProcedural,
      practiceArea: PracticeArea.criminal,
      status: MatterStatus.closed,
      assignedAttorneyName: 'Sara Khalil',
      createdAt: DateTime.utc(2026, 6, 2),
    ),
    Matter(
      id: DemoCorpus.matterIds[3],
      title: DemoCorpus.matterTitleFamily,
      practiceArea: PracticeArea.family,
      status: MatterStatus.active,
      assignedAttorneyName: 'Youssef Haddad',
      createdAt: DateTime.utc(2026, 7, 25),
    ),
    Matter(
      id: DemoCorpus.matterIds[4],
      title: DemoCorpus.matterTitleStartup,
      practiceArea: PracticeArea.corporate,
      status: MatterStatus.open,
      assignedAttorneyName: 'Maya Adel',
      createdAt: DateTime.utc(2026, 7, 30),
    ),
  ];

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    return Result<List<Matter>>.success(
      List<Matter>.unmodifiable(syntheticMatters),
    );
  }

  @override
  Future<Result<List<Matter>>> searchMatters(
    String query, {
    int limit = kSearchPageSize,
  }) async {
    // In-memory backend: no transfer cost to save, so no prefilter — the
    // caller's full matching pass is the arbiter and results stay identical
    // to the fetchMatters path.
    return fetchMatters();
  }
}
