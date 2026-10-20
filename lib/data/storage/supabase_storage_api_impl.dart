import 'package:supabase_flutter/supabase_flutter.dart';

import '../postgrest_failures.dart';
import '../supabase_seam.dart';
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

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first `.order('created_at')`
  /// (a projection-external column that still anchors the newest-first
  /// scan) + a hard row cap (audit 2026-09-21, P1).
  /// Shared seam binding ([SupabaseSeam.boundTable]).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
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

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor] — audit 2026-09-27,
  /// Q-Q1): this impl supplies only its enum values, the match-once logic
  /// lives in `postgrest_failures.dart`.
  SupabaseStorageFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseStorageFailureKind.denied,
      unknown: SupabaseStorageFailureKind.unknown,
    );
  }
}
