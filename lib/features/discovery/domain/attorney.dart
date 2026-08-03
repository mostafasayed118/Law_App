import 'package:equatable/equatable.dart';

/// The practice areas an attorney profile may list (Phase 6, D-A5).
///
/// Four values mirroring the home dashboard's practice-area fixtures
/// (`l10n.areaCorporate` … `l10n.areaFamily`), which the discovery surface
/// reuses for labels — no new l10n keys are needed for the areas themselves.
/// The enum-pin test in `attorney_test.dart` enforces the set, so adding an
/// area is a deliberate owner decision (same discipline as the `BookingCategory`
/// G2 pin).
enum PracticeArea { corporate, civil, criminal, family }

/// A synthetic attorney profile (Phase 6, owner decision D-A4).
///
/// Carries **non-PII data only**: a stable id, a name, a practice area, a
/// display locale, and a short bio. No phone, email, address, credentials, or
/// availability anywhere on the type — the real attorney data contract is
/// deferred to P2/P3 and this shape is TBD. Profiles come only from the fake
/// gateway's fixed synthetic list; bios are static demo copy (R1: fake-data
/// honesty — nothing here may read as a real directory or a real person).
class Attorney extends Equatable {
  const Attorney({
    required this.id,
    required this.name,
    required this.practiceArea,
    required this.locale,
    required this.bio,
  });

  final String id;
  final String name;
  final PracticeArea practiceArea;

  /// Display locale, e.g. "EN / AR". A cosmetic attribute of the synthetic
  /// profile (D-A4); it is not a capability or availability claim.
  final String locale;

  final String bio;

  @override
  List<Object?> get props => <Object?>[id, name, practiceArea, locale, bio];
}
