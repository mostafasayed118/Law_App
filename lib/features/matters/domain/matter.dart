import 'package:equatable/equatable.dart';

import '../../../core/practice_area.dart';

/// Lifecycle status of a synthetic matter (Phase 7, D-M1/D-M4).
///
/// Three values rendered as status chips on the list surface. The enum-pin
/// test in `matter_test.dart` enforces the set (same discipline as the
/// `PracticeArea`/`BookingCategory` pins).
enum MatterStatus { open, active, closed }

/// A synthetic matter preview (Phase 7, owner decision D-M4).
///
/// Carries **non-PII data only**: a stable synthetic id, a generic demo
/// title, a practice area, a lifecycle status, the assigned attorney's
/// display name, and a created date. No client names, no real-looking case
/// numbers, no contact data, no documents, no messages anywhere on the type
/// — the real matters data path stays §10-deferred and this shape is TBD.
/// Matters come only from the fake gateway's fixed synthetic list; titles
/// are static demo copy (R1: fake-data honesty — nothing here may read as a
/// real case).
class Matter extends Equatable {
  const Matter({
    required this.id,
    required this.title,
    required this.practiceArea,
    required this.status,
    required this.assignedAttorneyName,
    required this.createdAt,
  });

  final String id;

  /// Generic demo wording — never a real client or case name (D-M4).
  final String title;

  final PracticeArea practiceArea;

  final MatterStatus status;

  /// Display name of the assigned attorney (reuses the Phase 6 synthetic
  /// roster names, D-M4). Presentation-only; never an availability claim.
  final String assignedAttorneyName;

  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    practiceArea,
    status,
    assignedAttorneyName,
    createdAt,
  ];
}
