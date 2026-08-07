import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_storage_api.dart';

/// [SupabaseStorageApi] backed by the PostgREST client.
///
/// Like [SupabaseDocumentApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseStorageException]s at the seam.
class SupabaseStorageApiImpl implements SupabaseStorageApi {
  SupabaseStorageApiImpl(this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseStorageApiImpl.bind() => SupabaseStorageApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client. The builder's `select`
  /// resolves to the raw row list (PostgrestList) — no cast needed.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return Supabase.instance.client.from(table).select(columns);
  }

  final StorageTableCaller _table;

  @override
  Future<List<Map<String, dynamic>>> fetchFiles() async {
    try {
      // RLS-scoped (D-STR1/D-STR2): `files_select_assigned` returns only the
      // caller's rows; the matterRef title comes from the embedded
      // matters(title) select (D-STR5), never a blocked `profiles` join.
      return await _table(
        'files',
        'id, matter_id, name, mime_type, size_bytes, storage_path, '
            'matters(title)',
      );
    } on PostgrestException catch (e) {
      throw SupabaseStorageException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable RLS denial text is the only fragment matched; everything
  /// else is [SupabaseStorageFailureKind.unknown] with the message preserved.
  SupabaseStorageFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseStorageFailureKind.denied;
    }
    return SupabaseStorageFailureKind.unknown;
  }
}
