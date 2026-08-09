import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/matters/domain/matter_write_gateway.dart';
import 'supabase_matter_write_api.dart';

/// [MatterWriteGateway] backed by the Supabase provider via
/// [SupabaseMatterWriteApi].
///
/// Domain mapping happens here (the contract §5 pattern, same as
/// [SupabaseMessageGateway]): the persisted matter id from the seam becomes
/// a [CreatedMatter] VO, and typed [SupabaseMatterWriteException]s become
/// [AppError]s with the C-D2 codes (denied / owner-forbidden /
/// assignee-invalid / validation / unavailable / failed). The client never
/// derives authorization — the org id is a routing hint (D-08) and the
/// server re-derives every gate in-function (F-11).
class SupabaseMatterWriteGateway implements MatterWriteGateway {
  SupabaseMatterWriteGateway(this._api);

  final SupabaseMatterWriteApi _api;

  @override
  Future<Result<CreatedMatter>> createMatter(
    CreateMatterRequest request,
  ) async {
    try {
      final String id = await _api.createMatter(
        organizationId: request.organizationId,
        title: request.title,
        practiceArea: request.practiceArea.name,
        assignedClientId: request.assignedClientId,
        assignedAttorneyId: request.assignedAttorneyId,
      );
      // The RPC returns only the persisted id; the VO carries the trimmed
      // intent the client sent — never a fabricated timestamp or title.
      return Result<CreatedMatter>.success(
        CreatedMatter(
          id: id,
          title: request.title.trim(),
          practiceArea: request.practiceArea,
        ),
      );
    } on SupabaseMatterWriteException catch (e) {
      return Result<CreatedMatter>.failure(_mapFailure(e));
    }
  }

  /// Maps a provider failure to a redaction-safe [AppError] with the C-D2
  /// code. The technical message is the provider's own (denial/refusal
  /// text) — the title never crosses into errors.
  AppError _mapFailure(SupabaseMatterWriteException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseMatterWriteFailureKind.denied => (
        'matter_write_denied',
        'You do not have permission to create matters in this organization.',
      ),
      SupabaseMatterWriteFailureKind.ownerForbidden => (
        'matter_write_owner_forbidden',
        'The platform owner cannot be assigned to a matter.',
      ),
      SupabaseMatterWriteFailureKind.assigneeInvalid => (
        'matter_write_assignee_invalid',
        'The assigned member is not an active member of this organization.',
      ),
      SupabaseMatterWriteFailureKind.validation => (
        'matter_write_validation',
        'A matter title is required.',
      ),
      SupabaseMatterWriteFailureKind.providerUnavailable => (
        'matter_write_unavailable',
        'Matter creation is temporarily unavailable. Please try again.',
      ),
      SupabaseMatterWriteFailureKind.unknown => (
        'matter_write_failed',
        'Unable to create the matter. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }
}
