import 'package:equatable/equatable.dart';

import '../../../core/errors/result.dart';
import '../../../core/practice_area.dart';

/// A matter-creation intent (F-01 step 2 client swap).
///
/// The server is the authority: this request carries only the create intent —
/// org membership, the platform-owner refusal, and the active-member guard
/// are re-derived in-function by `create_matter` (F2-D1/F2-D2/F2-D4, D-08;
/// `docs/f01_step2_matter_write_design_2026-08-09.md`). [title] mirrors the
/// RPC's trimmed non-empty check; [practiceArea] is the 04 CHECK set;
/// the assignees are optional (F2-D5 — orphan creates allowed) but when
/// provided must be active members of [organizationId] (F2-D4).
class CreateMatterRequest extends Equatable {
  const CreateMatterRequest({
    required this.organizationId,
    required this.title,
    required this.practiceArea,
    this.assignedClientId,
    this.assignedAttorneyId,
  });

  /// The ACTIVE org id (a client-side UX convenience, D-08 — the server
  /// re-derives membership and never trusts this arg alone).
  final String organizationId;

  /// Generic demo wording — never a real client or case name (D-M4).
  final String title;

  final PracticeArea practiceArea;

  /// Optional assignees (F2-D5). The platform-owner id is never accepted
  /// (F2-D2) and non-members are refused (F2-D4).
  final String? assignedClientId;
  final String? assignedAttorneyId;

  @override
  List<Object?> get props => <Object?>[
    organizationId,
    title,
    practiceArea,
    assignedClientId,
    assignedAttorneyId,
  ];
}

/// The persisted matter the `create_matter` RPC returned.
///
/// Carries the server's returned id only (the read path's [Matter] VO
/// supplies the full row — title/status/created-at — when the user opens
/// the details screen); no client-fabricated timestamp.
class CreatedMatter extends Equatable {
  const CreatedMatter({
    required this.id,
    required this.title,
    required this.practiceArea,
  });

  final String id;
  final String title;
  final PracticeArea practiceArea;

  @override
  List<Object?> get props => <Object?>[id, title, practiceArea];
}

/// Matter-creation boundary (F-01 step 2 client swap).
///
/// The server is the authority: this seam sends ONLY the create intent and
/// returns the persisted id; failures arrive as [Failure] with a typed
/// [AppError], never raw exceptions (the project's [Result] boundary, §D.4).
/// Env-less runs and ALL tests use the fake; configured builds use the
/// Supabase-backed implementation (the DI flip in `service_locator.dart`).
abstract interface class MatterWriteGateway {
  Future<Result<CreatedMatter>> createMatter(CreateMatterRequest request);
}
