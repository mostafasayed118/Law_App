import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/approvals/domain/approvals_gateway.dart';
import '../../features/approvals/domain/pending_approval.dart';
import 'supabase_approval_api.dart';

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
        ),
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.listApprovals(
        organizationId: organizationId,
        status: status == null ? null : _serverStatus(status),
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
        decision: approve ? 'approved' : 'rejected',
        note: note,
      ),
      prefix: 'approval_decide',
      deniedMessage: 'Only a partner can decide this request.',
      validationMessage:
          'The request could not be decided. It may no longer be pending, or the note is missing.',
      unavailableMessage:
          'Deciding the request is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to decide the request. Please try again.',
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
    );
  }

  Future<Result<void>> _write(
    Future<void> Function() write, {
    required String prefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
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
    final String id = _requiredString(row, 'id');
    final String organizationId = _requiredString(row, 'organization_id');
    final String title = _requiredString(row, 'title');
    return PendingApproval(
      id: id,
      organizationId: organizationId,
      matterId: _optionalString(row['matter_id']),
      title: title,
      description: _optionalString(row['description']),
      kind: _kindOf(row['kind']),
      status: _statusOf(row['status']),
      requestedBy: _optionalString(row['requested_by']),
      decidedBy: _optionalString(row['decided_by']),
      decidedAt: _optionalDate(row['decided_at']),
      decisionNote: _optionalString(row['decision_note']),
      createdAt: _requiredDate(row, 'created_at'),
    );
  }

  ApprovalStatus _statusOf(Object? value) => switch (value) {
    'pending' => ApprovalStatus.pending,
    'approved' => ApprovalStatus.approved,
    'rejected' => ApprovalStatus.denied,
    'cancelled' => ApprovalStatus.cancelled,
    _ => throw const FormatException('Approval row has an unknown status'),
  };

  ApprovalKind _kindOf(Object? value) => switch (value) {
    'conflict' => ApprovalKind.conflict,
    'waiver' => ApprovalKind.waiver,
    'filing' => ApprovalKind.filing,
    'expense' => ApprovalKind.expense,
    'other' => ApprovalKind.other,
    _ => throw const FormatException('Approval row has an unknown kind'),
  };

  String _serverStatus(ApprovalStatus status) => switch (status) {
    ApprovalStatus.pending => 'pending',
    ApprovalStatus.approved => 'approved',
    ApprovalStatus.denied => 'rejected',
    ApprovalStatus.cancelled => 'cancelled',
  };

  String _requiredString(Map<String, dynamic> row, String field) {
    final Object? value = row[field];
    if (value is! String || value.isEmpty) {
      throw FormatException('Approval row has no $field');
    }
    return value;
  }

  DateTime _requiredDate(Map<String, dynamic> row, String field) {
    final Object? value = row[field];
    if (value is! String) {
      throw FormatException('Approval row has no $field');
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Approval row has an invalid $field');
    }
    return parsed;
  }

  DateTime? _optionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Approval row has an invalid date');
    }
    return parsed;
  }

  String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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
  }) {
    return switch (e.kind) {
      SupabaseApprovalFailureKind.denied => AppError(
        code: '${prefix}_denied',
        userMessage: deniedMessage,
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.notFound => AppError(
        code: 'approval_not_found',
        userMessage: 'Approval request not found.',
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.validation => AppError(
        code: '${prefix}_invalid',
        userMessage: validationMessage,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.providerUnavailable => AppError(
        code: '${prefix}_unavailable',
        userMessage: unavailableMessage,
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseApprovalFailureKind.unknown => AppError(
        code: '${prefix}_failed',
        userMessage: failedMessage,
        technicalMessage: e.message,
      ),
    };
  }

  /// Provider drift (unexpected row shape) surfaces loudly, never as a
  /// silently wrong request.
  AppError _drift(FormatException e) => AppError(
    code: 'approval_read_failed',
    userMessage: 'Unable to load approvals. Please try again.',
    technicalMessage: e.message,
  );
}
