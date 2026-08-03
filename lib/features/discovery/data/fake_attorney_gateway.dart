import '../../../core/errors/result.dart';
import '../../../core/practice_area.dart';
import '../domain/attorney.dart';
import '../domain/attorney_gateway.dart';

/// Development-only attorney-discovery implementation: a fixed synthetic list
/// of non-PII profiles.
///
/// No real backend and no availability logic (owner decisions D-A2/D-A4):
/// [fetchAttorneys] returns the same deterministic list on every call.
/// Profiles carry name / practice area / locale / short bio only — no phone,
/// email, address, or credentials anywhere (D-A4), and the bios are static
/// demo copy that must never read as a real directory (R1). The list resolves
/// immediately (no artificial delay) so cubit/widget tests stay
/// timing-independent.
class FakeAttorneyGateway implements AttorneyGateway {
  /// The fixed synthetic profile list served by [fetchAttorneys].
  static final List<Attorney> syntheticAttorneys = <Attorney>[
    Attorney(
      id: 'atty-1',
      name: 'Layla Mansour',
      practiceArea: PracticeArea.corporate,
      locale: 'EN / AR',
      bio: 'Corporate transactions and governance counsel.',
    ),
    Attorney(
      id: 'atty-2',
      name: 'Omar Farouk',
      practiceArea: PracticeArea.civil,
      locale: 'EN / AR',
      bio: 'Civil litigation and contracts.',
    ),
    Attorney(
      id: 'atty-3',
      name: 'Sara Khalil',
      practiceArea: PracticeArea.criminal,
      locale: 'AR / EN',
      bio: 'Criminal defense and procedure.',
    ),
    Attorney(
      id: 'atty-4',
      name: 'Youssef Haddad',
      practiceArea: PracticeArea.family,
      locale: 'AR / EN',
      bio: 'Family law and personal status matters.',
    ),
    Attorney(
      id: 'atty-5',
      name: 'Maya Adel',
      practiceArea: PracticeArea.corporate,
      locale: 'EN',
      bio: 'Startup formation and advisory work.',
    ),
  ];

  @override
  Future<Result<List<Attorney>>> fetchAttorneys() async {
    return Result<List<Attorney>>.success(
      List<Attorney>.unmodifiable(syntheticAttorneys),
    );
  }
}
