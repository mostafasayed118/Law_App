import 'dart:typed_data';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'supabase_storage_api.dart';

/// [StorageGateway] backed by the Supabase provider via [SupabaseStorageApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseDocumentGateway]): raw rows from the seam become [FileMetadata]
/// VOs, and typed [SupabaseStorageException]s become [AppError]s. Reads stay
/// metadata-only (D-STR3); writes follow the two-step server contract —
/// upload to the private bucket, then register the metadata row through the
/// audited RPC.
class SupabaseStorageGateway implements StorageGateway {
  SupabaseStorageGateway(this._api);

  final SupabaseStorageApi _api;

  @override
  Future<Result<List<FileMetadata>>> fetchFiles({String? matterId}) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchFiles(
        matterId: matterId,
      );
      return Result<List<FileMetadata>>.success(
        List<FileMetadata>.unmodifiable(rows.map(_fileFromRow)),
      );
    } on SupabaseStorageException catch (e) {
      return Result<List<FileMetadata>>.failure(_mapReadFailure(e));
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

  @override
  Future<Result<FileMetadata>> uploadFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required Uint8List bytes,
  }) async {
    String? uploadedPath;
    try {
      // The server re-derives the full matter/org/assignment gate. No row
      // means the caller cannot see the matter: a denial, not a retry.
      final Map<String, dynamic> matter = await _api.fetchMatterForUpload(
        matterId,
      );
      final Object? organizationId = matter['organization_id'];
      final Object? resolvedMatterId = matter['id'];
      if (organizationId is! String ||
          organizationId.isEmpty ||
          resolvedMatterId is! String ||
          resolvedMatterId.isEmpty) {
        return Result<FileMetadata>.failure(_uploadDeniedError());
      }

      if (sizeBytes < 0 || sizeBytes > matterFileMaxBytes) {
        return Result<FileMetadata>.failure(
          const AppError(
            code: 'file_upload_too_large',
            userMessage: 'This file is too large.',
            technicalMessage: 'File exceeds the 25 MiB bucket limit.',
          ),
        );
      }
      if (!matterFileAllowedMimeTypes.contains(mimeType)) {
        return Result<FileMetadata>.failure(
          const AppError(
            code: 'file_upload_unsupported_type',
            userMessage: 'This file type is not supported.',
            technicalMessage: 'MIME type is not in the bucket allowlist.',
          ),
        );
      }

      final String path =
          '$organizationId/$matterId/'
          '${DateTime.now().microsecondsSinceEpoch}-${_safeFileName(name)}';
      await _api.uploadObject(path, bytes, mimeType);
      uploadedPath = path;

      final Map<String, dynamic> response = await _api.registerMatterFile(
        matterId: matterId,
        name: name,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        storagePath: path,
      );
      final Object? fileRow = response['file'];
      if (fileRow is! Map<String, dynamic>) {
        throw const SupabaseStorageException(
          kind: SupabaseStorageFailureKind.unknown,
          message: 'register_matter_file returned no file row.',
        );
      }
      final Object? matterTitle = response['matter_title'];
      return Result<FileMetadata>.success(
        _fileFromRow(
          fileRow,
          matterTitle: matterTitle is String ? matterTitle : null,
        ),
      );
    } on SupabaseStorageException catch (e) {
      // The object may exist while the metadata row does not; remove it so a
      // failed registration does not leave an orphan. The original failure
      // always wins.
      final String? cleanupPath = uploadedPath;
      if (cleanupPath != null) {
        await _removeQuietly(cleanupPath);
      }
      return Result<FileMetadata>.failure(_mapUploadFailure(e));
    } on FormatException catch (e) {
      final String? cleanupPath = uploadedPath;
      if (cleanupPath != null) {
        await _removeQuietly(cleanupPath);
      }
      return Result<FileMetadata>.failure(
        AppError(
          code: 'file_upload_failed',
          userMessage: 'Unable to upload the file. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  @override
  Future<Result<Uri>> createDownloadUrl(
    FileMetadata file, {
    Duration ttl = const Duration(seconds: 60),
  }) async {
    try {
      final String url = await _api.createSignedUrl(
        file.storagePath,
        ttl.inSeconds,
      );
      final Uri uri = Uri.parse(url);
      if (uri.scheme != 'https' || uri.host.isEmpty) {
        return Result<Uri>.failure(_openFailedError());
      }
      return Result<Uri>.success(uri);
    } on SupabaseStorageException catch (e) {
      return Result<Uri>.failure(_mapOpenFailure(e));
    } on FormatException {
      return Result<Uri>.failure(_openFailedError());
    }
  }

  /// Maps one raw file row to the [FileMetadata] VO.
  ///
  /// Every cast below is guarded, so a malformed row surfaces as a typed
  /// FormatException → AppError, never a raw TypeError across the boundary.
  /// [matterTitle] overrides the embed lookup for the register response,
  /// which carries the title beside (not inside) the file row.
  FileMetadata _fileFromRow(Map<String, dynamic> row, {String? matterTitle}) {
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
      // gate; an absent embed falls back to the raw matter id, never a
      // fabricated title.
      matterRef: (matterTitle != null && matterTitle.isNotEmpty)
          ? matterTitle
          : _matterRefFromRow(row, matterId),
      matterId: matterId,
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

  /// Keeps the object key inside `[A-Za-z0-9._-]` and strips path segments /
  /// traversal, independent of what the picker reported.
  String _safeFileName(String name) {
    final String base = name.split(RegExp(r'[/\\]')).last;
    final String cleaned = base
        .replaceAll(RegExp('[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '.');
    return (cleaned.isEmpty || cleaned == '.') ? 'file' : cleaned;
  }

  Future<void> _removeQuietly(String path) async {
    try {
      await _api.removeObject(path);
    } on SupabaseStorageException {
      // Best-effort cleanup only; the registration failure is the result.
    }
  }

  AppError _uploadDeniedError() {
    return const AppError(
      code: 'file_upload_denied',
      userMessage: 'You do not have permission to upload files to this matter.',
      technicalMessage: 'Matter is not readable under the caller gate.',
      kind: AppErrorKind.denied,
    );
  }

  AppError _openFailedError() {
    return const AppError(
      code: 'file_open_failed',
      userMessage: 'Unable to open the file. Please try again.',
      technicalMessage: 'Signed URL is not a usable https URL.',
    );
  }

  /// Maps an upload-path provider failure to a redaction-safe [AppError].
  /// The provider message is deliberately not forwarded: storage errors can
  /// echo the object path (and therefore the file name).
  AppError _mapUploadFailure(SupabaseStorageException e) {
    final (
      String code,
      String userMessage,
      AppErrorKind kind,
    ) = switch (e.kind) {
      SupabaseStorageFailureKind.denied => (
        'file_upload_denied',
        'You do not have permission to upload files to this matter.',
        AppErrorKind.denied,
      ),
      SupabaseStorageFailureKind.tooLarge => (
        'file_upload_too_large',
        'This file is too large.',
        AppErrorKind.unknown,
      ),
      SupabaseStorageFailureKind.unsupportedType => (
        'file_upload_unsupported_type',
        'This file type is not supported.',
        AppErrorKind.unknown,
      ),
      SupabaseStorageFailureKind.conflict => (
        'file_upload_conflict',
        'A file with this name already exists. Please try again.',
        AppErrorKind.unknown,
      ),
      SupabaseStorageFailureKind.providerUnavailable => (
        'file_upload_unavailable',
        'File uploads are temporarily unavailable. Please try again.',
        AppErrorKind.unavailable,
      ),
      SupabaseStorageFailureKind.notFound ||
      SupabaseStorageFailureKind.unknown => (
        'file_upload_failed',
        'Unable to upload the file. Please try again.',
        AppErrorKind.unknown,
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      kind: kind,
      technicalMessage: 'Upload failed (${e.kind.name}).',
    );
  }

  /// Maps a signed-URL provider failure to a redaction-safe [AppError].
  /// The provider message is not forwarded (it can echo the object path).
  AppError _mapOpenFailure(SupabaseStorageException e) {
    final (
      String code,
      String userMessage,
      AppErrorKind kind,
    ) = switch (e.kind) {
      SupabaseStorageFailureKind.denied => (
        'file_open_denied',
        'You do not have permission to open this file.',
        AppErrorKind.denied,
      ),
      SupabaseStorageFailureKind.providerUnavailable => (
        'file_open_unavailable',
        'Files are temporarily unavailable. Please try again.',
        AppErrorKind.unavailable,
      ),
      _ => (
        'file_open_failed',
        'Unable to open the file. Please try again.',
        AppErrorKind.unknown,
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      kind: kind,
      technicalMessage: 'Download URL failed (${e.kind.name}).',
    );
  }

  /// Maps a read failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — file row
  /// content never crosses into errors.
  AppError _mapReadFailure(SupabaseStorageException e) {
    final (
      String code,
      String userMessage,
      AppErrorKind kind,
    ) = switch (e.kind) {
      SupabaseStorageFailureKind.denied => (
        'file_read_denied',
        'You do not have permission to view these files.',
        AppErrorKind.denied,
      ),
      SupabaseStorageFailureKind.providerUnavailable => (
        'file_read_unavailable',
        'Files are temporarily unavailable. Please try again.',
        AppErrorKind.unavailable,
      ),
      _ => (
        'file_read_failed',
        'Unable to load files. Please try again.',
        AppErrorKind.unknown,
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      kind: kind,
      technicalMessage: e.message,
    );
  }
}
