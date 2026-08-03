import '../../../core/errors/result.dart';
import '../../../core/practice_area.dart';
import '../domain/matter.dart';
import '../domain/matter_gateway.dart';

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
      id: 'matter-1',
      title: 'Demo acquisition review',
      practiceArea: PracticeArea.corporate,
      status: MatterStatus.active,
      assignedAttorneyName: 'Layla Mansour',
      createdAt: DateTime.utc(2026, 7, 12),
    ),
    Matter(
      id: 'matter-2',
      title: 'Commercial lease consultation',
      practiceArea: PracticeArea.civil,
      status: MatterStatus.open,
      assignedAttorneyName: 'Omar Farouk',
      createdAt: DateTime.utc(2026, 7, 18),
    ),
    Matter(
      id: 'matter-3',
      title: 'Procedural review matter',
      practiceArea: PracticeArea.criminal,
      status: MatterStatus.closed,
      assignedAttorneyName: 'Sara Khalil',
      createdAt: DateTime.utc(2026, 6, 2),
    ),
    Matter(
      id: 'matter-4',
      title: 'Family status consultation',
      practiceArea: PracticeArea.family,
      status: MatterStatus.active,
      assignedAttorneyName: 'Youssef Haddad',
      createdAt: DateTime.utc(2026, 7, 25),
    ),
    Matter(
      id: 'matter-5',
      title: 'Startup formation advisory',
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
}
