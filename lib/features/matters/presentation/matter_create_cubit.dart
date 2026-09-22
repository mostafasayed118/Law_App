import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../domain/matter_write_gateway.dart';
import 'matter_create_state.dart';

/// Owns the matter-creation submit lifecycle (F-01 step 2 client swap, C-D6).
///
/// [submit] sends the create intent through the [MatterWriteGateway] seam
/// (the env-gated fake in env-less runs, the Supabase-backed implementation
/// in configured builds) and emits the sealed lifecycle state. The server
/// is the authority: no org/membership/owner check happens client-side
/// (F-11) — refusals arrive as typed [AppError]s and map 1:1 to the RPC's
/// in-function gates (C-D2).
///
/// [loadMembers] is the assignee-option read. It moved here from the screen
/// (audit 2026-09-21, H-4): presentation was calling [OrganizationGateway]
/// directly, which bypassed the cubit layer `INSTRUCTIONS.md` §4.1 mandates.
/// It is a **returning method** rather than an emitted state (owner decision
/// OI-D2, 2026-09-22) so the sealed submit lifecycle stays clean.
class MatterCreateCubit extends Cubit<MatterCreateState> {
  MatterCreateCubit(this._gateway, this._organizationGateway)
    : super(const MatterCreateInitial());

  final MatterWriteGateway _gateway;
  final OrganizationGateway _organizationGateway;

  /// Loads the assignee options for [organizationId].
  ///
  /// Only **active** members are offerable (F2-D4): suspended and removed rows
  /// are excluded client-side (the server re-asserts). A failed read returns
  /// an empty list — the picker then offers nobody, exactly as the screen's
  /// local `switch` did before this moved behind the cubit.
  Future<List<OrgMember>> loadMembers(String organizationId) async {
    final OrgOutcome<List<OrgMember>> outcome = await _organizationGateway
        .listMembers(organizationId: organizationId);
    return switch (outcome) {
      OrgSuccess<List<OrgMember>>(value: final List<OrgMember> members) =>
        members
            .where((OrgMember member) => member.isActive)
            .toList(growable: false),
      OrgFailed<List<OrgMember>>() => const <OrgMember>[],
    };
  }

  /// In-flight guard: a submit while one is in flight is ignored (the
  /// `_loading` pattern of [MatterCubit]).
  bool _submitting = false;

  /// Sends the create intent. Idle → submitting → success, or idle →
  /// submitting → failure with the typed [AppError]; a failure keeps the
  /// form intact (the user can correct and resubmit).
  Future<void> submit(CreateMatterRequest request) async {
    if (isClosed || _submitting) {
      return;
    }
    _submitting = true;
    emit(const MatterCreateSubmitting());
    final Result<CreatedMatter> result = await _gateway.createMatter(request);
    _submitting = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<CreatedMatter>(value: final CreatedMatter created):
        emit(MatterCreateSuccess(created));
      case Failure<CreatedMatter>(error: final AppError error):
        emit(MatterCreateFailure(error));
    }
  }
}
