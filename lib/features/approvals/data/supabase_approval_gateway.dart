import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/supabase/row_reader.dart';
import 'package:legalhub/data/approvals/supabase_approval_api.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';

/// Approval-request gateway backed by the Supabase provider (design §3).
///
/// Raw rows become [PendingApproval] VOs, the DB `rejected` status maps to
/// [ApprovalStatus.denied], and typed [SupabaseApprovalException]s become
/// [AppError]s with the denied/validation/unavailable classification
/// preserved. The read needs the caller's active organization id, supplied as
/// a resolver so the data layer never imports the app-scoped store.
class SupabaseApprovalGateway implements ApprovalsGateway {
  SupabaseApprovalGateway(this._api, {required this.organizationId});

  final SupabaseApprovalApi _api;
  final String? Function() organizationId;

  @override
  Future<Result<List<PendingApproval>>> fetchApprovals({
    ApprovalStatus? status,
  }) async {
    final String? organizationId = this.organizationId();
    if (organizationId == null || organizationId.isEmpty) {
      return Result<List<PendingApproval>>.failure(
        const AppError(
          code: 'approval_read_no_org',
          userMessage: 'Select an organization to view approvals.',
          messageKey: AppMessageKey.errSelectAnOrganizationToViewApprovals,
        ),
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.listApprovals(
        organizationId: organizationId,
        status: status == null ? null : approvalStatusToWire(status),
      );
      return Result<List<PendingApproval>>.success(
        List<PendingApproval>.unmodifiable(rows.map(_fromRow)),
      );
    } on SupabaseApprovalException catch (e) {
      return Result<List<PendingApproval>>.failure(
        _errorFor(
          e,
          prefix: 'approval_read',
          deniedMessage: 'You do not have permission to view approvals.',
          validationMessage: 'Unable to load approvals. Please try again.',
          unavailableMessage:
              'Approvals are temporarily unavailable. Please try again.',
          failedMessage: 'Unable to load approvals. Please try again.',
          deniedKey: AppMessageKey.errYouDoNotHavePermissionToViewApprovals,
          validationKey: AppMessageKey.errUnableToLoadApprovalsPleaseTryAgain,
          unavailableKey:
              AppMessageKey.errApprovalsAreTemporarilyUnavailablePleaseTryAgain,
          failedKey: AppMessageKey.errUnableToLoadApprovalsPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      return Result<List<PendingApproval>>.failure(_drift(e));
    }
  }

  @override
  Future<Result<String>> create(ApprovalDraft draft) async {
    try {
      final String id = await _api.createApproval(
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title,
        kind: draft.kind.name,
        description: draft.description,
      );
      return Result<String>.success(id);
    } on SupabaseApprovalException catch (e) {
      return Result<String>.failure(
        _errorFor(
          e,
          prefix: 'approval_create',
          deniedMessage:
              'You do not have permission to create approval requests.',
          validationMessage:
              'The request could not be created. Check the details and try again.',
          unavailableMessage:
              'Creating the request is temporarily unavailable. Please try again.',
          failedMessage: 'Unable to create the request. Please try again.',
          deniedKey: AppMessageKey.errYouDoNotHavePermissionToCreateApproval,
          validationKey: AppMessageKey.errTheRequestCouldNotBeCreatedCheckThe,
          unavailableKey: AppMessageKey
              .errCreatingTheRequestIsTemporarilyUnavailablePleaseTry,
          failedKey: AppMessageKey.errUnableToCreateTheRequestPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      return Result<String>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> decide(
    String id, {
    required bool approve,
    String? note,
  }) {
    return _write(
      () => _api.decideApproval(
        id,
        decision: approvalStatusToWire(
          approve ? ApprovalStatus.approved : ApprovalStatus.denied,
        ),
        note: note,
      ),
      prefix: 'approval_decide',
      deniedMessage: 'Only a partner can decide this request.',
      validationMessage:
          'The request could not be decided. It may no longer be pending, or the note is missing.',
      unavailableMessage:
          'Deciding the request is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to decide the request. Please try again.',
      deniedKey: AppMessageKey.errOnlyAPartnerCanDecideThisRequest,
      validationKey: AppMessageKey.errTheRequestCouldNotBeDecidedItMay,
      unavailableKey:
          AppMessageKey.errDecidingTheRequestIsTemporarilyUnavailablePleaseTry,
      failedKey: AppMessageKey.errUnableToDecideTheRequestPleaseTryAgain,
    );
  }

  @override
  Future<Result<void>> cancel(String id) {
    return _write(
      () => _api.cancelApproval(id),
      prefix: 'approval_cancel',
      deniedMessage: 'Only the requester or a partner can cancel this request.',
      validationMessage: 'The request can no longer be cancelled.',
      unavailableMessage:
          'Cancelling the request is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to cancel the request. Please try again.',
      deniedKey: AppMessageKey.errOnlyTheRequesterOrAPartnerCanCancel,
      validationKey: AppMessageKey.errTheRequestCanNoLongerBeCancelled,
      unavailableKey: AppMessageKey
          .errCancellingTheRequestIsTemporarilyUnavailablePleaseTry,
      failedKey: AppMessageKey.errUnableToCancelTheRequestPleaseTryAgain,
    );
  }

  Future<Result<void>> _write(
    Future<void> Function() write, {
    required String prefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
    required AppMessageKey deniedKey,
    required AppMessageKey validationKey,
    required AppMessageKey unavailableKey,
    required AppMessageKey failedKey,
  }) async {
    try {
      await write();
      return const Result<void>.success(null);
    } on SupabaseApprovalException catch (e) {
      return Result<void>.failure(
        _errorFor(
          e,
          prefix: prefix,
          deniedMessage: deniedMessage,
          validationMessage: validationMessage,
          unavailableMessage: unavailableMessage,
          failedMessage: failedMessage,
          deniedKey: deniedKey,
          validationKey: validationKey,
          unavailableKey: unavailableKey,
          failedKey: failedKey,
        ),
      );
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  /// Maps one raw `approval_requests` row to the [PendingApproval] VO.
  ///
  /// Required shapes are asserted explicitly (id, org, title, kind, status,
  /// created_at) so a malformed row surfaces as a typed `FormatException`
  /// rather than a raw cast error across the boundary.
  PendingApproval _fromRow(Map<String, dynamic> row) {
    final String id = requiredString(row, 'id', allowWhitespaceOnly: true);
    final String organizationId = requiredString(
      row,
      'organization_id',
      allowWhitespaceOnly: true,
    );
    final String title = requiredString(
      row,
      'title',
      allowWhitespaceOnly: true,
    );
    return PendingApproval(
      id: id,
      organizationId: organizationId,
      matterId: optionalString(row['matter_id']),
      title: title,
      description: optionalString(row['description']),
      kind: _kindOf(row['kind']),
      status: approvalStatusFromWire(requiredString(row, 'status')),
      requestedBy: optionalString(row['requested_by']),
      decidedBy: optionalString(row['decided_by']),
      decidedAt: optionalDate(row['decided_at']),
      decisionNote: optionalString(row['decision_note']),
      createdAt: requiredDate(row, 'created_at'),
    );
  }

  ApprovalKind _kindOf(Object? value) => switch (value) {
    'conflict' => ApprovalKind.conflict,
    'waiver' => ApprovalKind.waiver,
    'filing' => ApprovalKind.filing,
    'expense' => ApprovalKind.expense,
    'other' => ApprovalKind.other,
    _ => throw const FormatException('Approval row has an unknown kind'),
  };

  /// Maps a seam failure to a redaction-safe [AppError]. Request content never
  /// crosses into errors; only the provider's own message crosses as the
  /// technical message.
  AppError _errorFor(
    SupabaseApprovalException e, {
    required String prefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
    required AppMessageKey deniedKey,
    required AppMessageKey validationKey,
    required AppMessageKey unavailableKey,
    required AppMessageKey failedKey,
  }) {
    return switch (e.kind) {
      SupabaseApprovalFailureKind.denied => AppError(
        code: '${prefix}_denied',
        userMessage: deniedMessage,
        messageKey: deniedKey,
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.notFound => AppError(
        code: 'approval_not_found',
        userMessage: 'Approval request not found.',
        messageKey: AppMessageKey.errApprovalRequestNotFound,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.validation => AppError(
        code: '${prefix}_invalid',
        userMessage: validationMessage,
        messageKey: validationKey,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.providerUnavailable => AppError(
        code: '${prefix}_unavailable',
        userMessage: unavailableMessage,
        messageKey: unavailableKey,
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.unknown => AppError(
        code: '${prefix}_failed',
        userMessage: failedMessage,
        messageKey: failedKey,
        technicalMessage: e.message,
      ),
    };
  }

  /// Provider drift (unexpected row shape) surfaces loudly, never as a
  /// silently wrong request.
  AppError _drift(FormatException e) => AppError(
    code: 'approval_read_failed',
    userMessage: 'Unable to load approvals. Please try again.',
    messageKey: AppMessageKey.errUnableToLoadApprovalsPleaseTryAgain,
    technicalMessage: e.message,
  );
}
