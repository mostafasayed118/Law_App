import 'dart:typed_data';

import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_storage_api.dart';

/// [SupabaseStorageApi] backed by PostgREST + Storage.
///
/// Like [SupabaseDocumentApiImpl], this is a data-layer file whose only job
/// is holding the provider imports: table/RPC calls and bucket operations in,
/// plain values out, and provider exceptions mapped to
/// [SupabaseStorageException]s at the seam.
class SupabaseStorageApiImpl implements SupabaseStorageApi {
  SupabaseStorageApiImpl(
    this._table, {
    StorageMatterCaller? matterCaller,
    StorageMatterTableCaller? matterTableCaller,
    StorageObjectUploader? objectUploader,
    StorageSignedUrlCreator? signedUrlCreator,
    StorageObjectRemover? objectRemover,
    StorageRpcCaller? rpcCaller,
  }) : _matterCaller = matterCaller ?? _boundMatter,
       _matterTable = matterTableCaller ?? _boundMatterTable,
       _objectUploader = objectUploader ?? _boundUpload,
       _signedUrlCreator = signedUrlCreator ?? _boundSignedUrl,
       _objectRemover = objectRemover ?? _boundRemove,
       _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseStorageApiImpl.bind() => SupabaseStorageApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first `.order('created_at')`
  /// + a hard row cap (audit 2026-09-21, P1).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  /// The RLS-scoped matter lookup (`fetchMatterForUpload`). A missing row is
  /// an empty map, not an exception, so the gateway can map it to a denial.
  static Future<Map<String, dynamic>> _boundMatter(String matterId) async {
    final Map<String, dynamic>? row = await Supabase.instance.client
        .from('matters')
        .select('id, organization_id, title')
        .eq('id', matterId)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    return row ?? const <String, dynamic>{};
  }

  /// Binds the matter-scoped file read to the app-level client via the
  /// shared filtered binding: the same cap + order as [boundTable], with
  /// `.eq('matter_id', …)` applied server-side.
  static Future<List<Map<String, dynamic>>> _boundMatterTable(
    String table,
    String columns,
    String matterId,
  ) {
    return SupabaseSeam.boundFilteredTable(
      table,
      columns,
      filterColumn: 'matter_id',
      filterValue: matterId,
    );
  }

  /// Uploads to the private bucket. `upsert: false` keeps a name collision a
  /// typed conflict rather than a silent overwrite.
  ///
  /// The deadline is size-aware ([uploadTimeoutForBytes]). The storage client
  /// exposes no request-cancel handle, so on timeout only the `await` is
  /// abandoned — the HTTP write may still complete. The gateway therefore
  /// registers the destination path before calling this and compensates by
  /// deleting it on failure (best-effort: a write that lands after the delete
  /// is an orphan nothing in this API can recall).
  static Future<void> _boundUpload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    await Supabase.instance.client.storage
        .from('matter-files')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        )
        .timeout(uploadTimeoutForBytes(bytes.length));
  }

  static Future<String> _boundSignedUrl(String path, int expiresInSeconds) {
    return Supabase.instance.client.storage
        .from('matter-files')
        .createSignedUrl(path, expiresInSeconds)
        .timeout(const Duration(seconds: 15));
  }

  static Future<void> _boundRemove(String path) async {
    await Supabase.instance.client.storage
        .from('matter-files')
        .remove(<String>[path])
        .timeout(const Duration(seconds: 15));
  }

  static Future<Object?> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRawRpc(function, params);
  }

  final StorageTableCaller _table;
  final StorageMatterCaller _matterCaller;
  final StorageMatterTableCaller _matterTable;
  final StorageObjectUploader _objectUploader;
  final StorageSignedUrlCreator _signedUrlCreator;
  final StorageObjectRemover _objectRemover;
  final StorageRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> fetchFiles({String? matterId}) async {
    try {
      // RLS-scoped (D-STR1/D-STR2): `files_select_assigned` returns only the
      // caller's rows; the matterRef title comes from the embedded
      // matters(title) select (D-STR5), never a blocked `profiles` join.
      // A non-null [matterId] narrows the transfer to the open matter.
      const String columns =
          'id, matter_id, name, mime_type, size_bytes, storage_path, '
          'matters(title)';
      return matterId == null
          ? await _table('files', columns)
          : await _matterTable('files', columns, matterId);
    } on PostgrestException catch (e) {
      throw SupabaseStorageException(kind: _kindFor(e), message: e.message);
    } on Exception {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMatterForUpload(String matterId) async {
    try {
      final Map<String, dynamic> row = await _matterCaller(matterId);
      return row;
    } on SupabaseStorageException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseStorageException(kind: _kindFor(e), message: e.message);
    } on Exception {
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<void> uploadObject(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    try {
      await _objectUploader(path, bytes, contentType);
    } on SupabaseStorageException {
      rethrow;
    } on StorageException catch (e) {
      throw SupabaseStorageException(
        kind: _kindForStorage(e),
        message: e.message,
      );
    } on PostgrestException catch (e) {
      throw SupabaseStorageException(kind: _kindFor(e), message: e.message);
    } on Exception {
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<String> createSignedUrl(String path, int expiresInSeconds) async {
    try {
      return await _signedUrlCreator(path, expiresInSeconds);
    } on SupabaseStorageException {
      rethrow;
    } on StorageException catch (e) {
      throw SupabaseStorageException(
        kind: _kindForStorage(e),
        message: e.message,
      );
    } on Exception {
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<void> removeObject(String path) async {
    try {
      await _objectRemover(path);
    } on SupabaseStorageException {
      rethrow;
    } on StorageException catch (e) {
      throw SupabaseStorageException(
        kind: _kindForStorage(e),
        message: e.message,
      );
    } on Exception {
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> registerMatterFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required String storagePath,
  }) async {
    try {
      final Object? data =
          await _rpcCaller('register_matter_file', <String, dynamic>{
            'p_matter_id': matterId,
            'p_name': name,
            'p_mime_type': mimeType,
            'p_size_bytes': sizeBytes,
            'p_storage_path': storagePath,
          });
      if (data is! Map<String, dynamic>) {
        throw const SupabaseStorageException(
          kind: SupabaseStorageFailureKind.unknown,
          message: 'register_matter_file returned no row.',
        );
      }
      return data;
    } on SupabaseStorageException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseStorageException(kind: _kindFor(e), message: e.message);
    } on Exception {
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a StorageException status to the provider-neutral failure kind.
  ///
  /// A missing status is a transport failure (the client could not complete
  /// the request), never a denial.
  SupabaseStorageFailureKind _kindForStorage(StorageException e) {
    return switch (e.statusCode) {
      '413' => SupabaseStorageFailureKind.tooLarge,
      '415' => SupabaseStorageFailureKind.unsupportedType,
      '403' => SupabaseStorageFailureKind.denied,
      '404' => SupabaseStorageFailureKind.notFound,
      '409' => SupabaseStorageFailureKind.conflict,
      null => SupabaseStorageFailureKind.providerUnavailable,
      _ => SupabaseStorageFailureKind.unknown,
    };
  }

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor]).
  SupabaseStorageFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseStorageFailureKind.denied,
      unknown: SupabaseStorageFailureKind.unknown,
    );
  }
}
