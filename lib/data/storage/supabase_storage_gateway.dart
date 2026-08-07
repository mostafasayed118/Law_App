import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/storage/domain/file_metadata.dart';
import '../../features/storage/domain/storage_gateway.dart';
import 'supabase_storage_api.dart';

/// [StorageGateway] backed by the Supabase provider via [SupabaseStorageApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseDocumentGateway]): raw rows from the seam become [FileMetadata]
/// VOs, and typed [SupabaseStorageException]s become [AppError]s. The
/// `FileMetadata` VO and all presentation are untouched — this is the
/// env-gated seam-compatible swap of plan T7 (D-STR7). Files are **metadata
/// only** (D-STR3): no content/bytes/url column is ever read, so the
/// download affordance stays structurally unbuilt (D-STR9).
///
/// **matterRef resolution (D-STR5):** rows store `matter_id` ids only; the VO
/// is title-keyed by design (D-W2), so the title comes from the embedded
/// `matters(title)` select (PostgREST embed, the `listMyMemberships`
/// pattern — the files policy guarantees the reader passes the matter gate,
/// so the embed resolves), falling back to the raw matter id when the embed
/// is absent (plan §9) — never a fabricated title.
class SupabaseStorageGateway implements StorageGateway {
  SupabaseStorageGateway(this._api);

  final SupabaseStorageApi _api;

  @override
  Future<Result<List<FileMetadata>>> fetchFiles() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchFiles();
      return Result<List<FileMetadata>>.success(
        List<FileMetadata>.unmodifiable(rows.map(_fileFromRow)),
      );
    } on SupabaseStorageException catch (e) {
      return Result<List<FileMetadata>>.failure(_mapFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected mime_type/size_bytes/storage_path shape)
      // surfaces loudly, never as a silently wrong file.
      return Result<List<FileMetadata>>.failure(
        AppError(
          code: 'file_read_failed',
          userMessage: 'Unable to load files. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw file row to the [FileMetadata] VO.
  ///
  /// Every cast below is guarded above (id/matter_id/name/mime_type/
  /// size_bytes/storage_path), so a malformed row surfaces as a typed
  /// FormatException → AppError, never a raw TypeError across the boundary.
  FileMetadata _fileFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('File row has no id');
    }
    final Object? matterId = row['matter_id'];
    if (matterId is! String || matterId.isEmpty) {
      throw FormatException('File row has no matter_id');
    }
    final Object? name = row['name'];
    if (name is! String || name.isEmpty) {
      throw FormatException('File row has no name');
    }
    final Object? mimeType = row['mime_type'];
    if (mimeType is! String || mimeType.isEmpty) {
      throw FormatException('File row has no mime_type');
    }
    // `size_bytes` is a bigint → PostgREST hands back a Dart int; anything
    // else is provider drift (the documents T7 malformed-row guard baseline).
    final Object? sizeBytes = row['size_bytes'];
    if (sizeBytes is! int) {
      throw FormatException('File row has no size_bytes');
    }
    final Object? storagePath = row['storage_path'];
    if (storagePath is! String || storagePath.isEmpty) {
      throw FormatException('File row has no storage_path');
    }
    return FileMetadata(
      id: id,
      name: name,
      // D-STR5: the embedded matters(title) join resolves under the same RLS
      // gate (the policy guarantees the reader passes the matter check); an
      // absent embed falls back to the raw matter id, never a fabricated
      // title (the listMyMemberships null-embed pattern).
      matterRef: _matterRefFromRow(row, matterId),
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      storagePath: storagePath,
    );
  }

  /// Resolves the VO's title-keyed `matterRef` from the embedded
  /// `matters(title)` select, falling back to the raw matter id (D-STR5).
  String _matterRefFromRow(Map<String, dynamic> row, String matterId) {
    final Object? matters = row['matters'];
    final Object? embeddedTitle = matters is Map<String, dynamic>
        ? matters['title']
        : null;
    return (embeddedTitle is String && embeddedTitle.isNotEmpty)
        ? embeddedTitle
        : matterId;
  }

  /// Maps a provider failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — file row
  /// content never crosses into errors.
  AppError _mapFailure(SupabaseStorageException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseStorageFailureKind.denied => (
        'file_read_denied',
        'You do not have permission to view these files.',
      ),
      SupabaseStorageFailureKind.providerUnavailable => (
        'file_read_unavailable',
        'Files are temporarily unavailable. Please try again.',
      ),
      SupabaseStorageFailureKind.unknown => (
        'file_read_failed',
        'Unable to load files. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }
}
