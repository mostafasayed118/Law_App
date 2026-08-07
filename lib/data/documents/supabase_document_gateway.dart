import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/documents/domain/document.dart';
import '../../features/documents/domain/document_gateway.dart';
import 'supabase_document_api.dart';

/// [DocumentGateway] backed by the Supabase provider via [SupabaseDocumentApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseMatterGateway]): raw rows from the seam become [Document] VOs,
/// `document_type` strings map to the client enum with a loud failure on
/// unknown values (provider drift, never a silently wrong enum), and typed
/// [SupabaseDocumentException]s become [AppError]s. The `Document` VO and all
/// presentation are untouched — this is the env-gated seam-compatible swap of
/// plan T7 (D-DR7).
///
/// **matterRef resolution (D-DR4):** rows store `matter_id` ids only; the VO
/// is title-keyed by design (D-W2), so the title comes from the embedded
/// `matters(title)` select (PostgREST embed, the `listMyMemberships`
/// pattern — the documents policy guarantees the reader passes the matter
/// gate, so the embed resolves), falling back to the raw matter id when the
/// embed is absent (plan §9) — never a fabricated title.
class SupabaseDocumentGateway implements DocumentGateway {
  SupabaseDocumentGateway(this._api);

  final SupabaseDocumentApi _api;

  @override
  Future<Result<List<Document>>> fetchDocuments() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchDocuments();
      return Result<List<Document>>.success(
        List<Document>.unmodifiable(rows.map(_documentFromRow)),
      );
    } on SupabaseDocumentException catch (e) {
      return Result<List<Document>>.failure(_mapFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected document_type/date shape) surfaces
      // loudly, never as a silently wrong document.
      return Result<List<Document>>.failure(
        AppError(
          code: 'document_read_failed',
          userMessage: 'Unable to load documents. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw document row to the [Document] VO.
  ///
  /// Every `as` cast below is guarded above (id/matter_id/title/created_at)
  /// or is a nullable enum-name (document_type), so a malformed row surfaces
  /// as a typed FormatException → AppError, never a raw TypeError across the
  /// boundary.
  Document _documentFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Document row has no id');
    }
    final Object? matterId = row['matter_id'];
    if (matterId is! String || matterId.isEmpty) {
      throw FormatException('Document row has no matter_id');
    }
    final Object? title = row['title'];
    if (title is! String || title.isEmpty) {
      throw FormatException('Document row has no title');
    }
    final Object? createdAt = row['created_at'];
    if (createdAt is! String || createdAt.isEmpty) {
      throw FormatException('Document row has no created_at');
    }
    return Document(
      id: id,
      title: title,
      // D-DR4: the embedded matters(title) join resolves under the same RLS
      // gate (the policy guarantees the reader passes the matter check); an
      // absent embed falls back to the raw matter id, never a fabricated
      // title (the listMyMemberships null-embed pattern).
      matterRef: _matterRefFromRow(row, matterId),
      // Guarded, never a bare cast: a present-but-non-string value (beyond
      // schema drift) would otherwise surface as a raw TypeError instead of
      // the typed FormatException the fetch catches.
      type: _typeFromServerName(
        row['document_type'] is String ? row['document_type'] as String : null,
      ),
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }

  /// Resolves the VO's title-keyed `matterRef` from the embedded
  /// `matters(title)` select, falling back to the raw matter id (D-DR4).
  String _matterRefFromRow(Map<String, dynamic> row, String matterId) {
    final Object? matters = row['matters'];
    final Object? embeddedTitle = matters is Map<String, dynamic>
        ? matters['title']
        : null;
    return (embeddedTitle is String && embeddedTitle.isNotEmpty)
        ? embeddedTitle
        : matterId;
  }

  /// Maps a server `document_type` name to the domain [DocumentType], or
  /// throws when the name is unknown (provider drift — surfaces loudly,
  /// never silently as a type the client does not understand).
  DocumentType _typeFromServerName(String? name) {
    return switch (name) {
      'contract' => DocumentType.contract,
      'brief' => DocumentType.brief,
      'evidence' => DocumentType.evidence,
      'correspondence' => DocumentType.correspondence,
      _ => throw FormatException('Unknown document type: $name'),
    };
  }

  /// Maps a provider failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — document row
  /// content never crosses into errors.
  AppError _mapFailure(SupabaseDocumentException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseDocumentFailureKind.denied => (
        'document_read_denied',
        'You do not have permission to view these documents.',
      ),
      SupabaseDocumentFailureKind.providerUnavailable => (
        'document_read_unavailable',
        'Documents are temporarily unavailable. Please try again.',
      ),
      SupabaseDocumentFailureKind.unknown => (
        'document_read_failed',
        'Unable to load documents. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }
}
