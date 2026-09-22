import 'package:supabase_flutter/supabase_flutter.dart';

import '../list_query_guards.dart';
import '../postgrest_failures.dart';
import 'supabase_document_api.dart';

/// [SupabaseDocumentApi] backed by the PostgREST client.
///
/// Like [SupabaseMatterApiImpl], this is a data-layer file whose only job is
/// holding the provider import: a table SELECT in, plain map rows out, and
/// PostgrestExceptions mapped to [SupabaseDocumentException]s at the seam.
class SupabaseDocumentApiImpl implements SupabaseDocumentApi {
  SupabaseDocumentApiImpl(this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseDocumentApiImpl.bind() =>
      SupabaseDocumentApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first `.order('created_at')`
  /// + a hard row cap (audit 2026-09-21, P1).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return boundedTableSelect(table, columns);
  }

  final DocumentTableCaller _table;

  @override
  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    try {
      // RLS-scoped (D-DR1/D-DR2): `documents_select_assigned` returns only
      // the caller's rows; the matterRef title comes from the embedded
      // matters(title) select (D-DR4), never a blocked `profiles` join.
      return await _table(
        'documents',
        'id, matter_id, title, document_type, created_at, matters(title)',
      );
    } on PostgrestException catch (e) {
      throw SupabaseDocumentException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseDocumentException(
        kind: SupabaseDocumentFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable RLS denial text is the only fragment matched; everything
  /// else is [SupabaseDocumentFailureKind.unknown] with the message preserved.
  SupabaseDocumentFailureKind _kindFor(PostgrestException e) {
    if (isPostgrestDenial(e)) {
      return SupabaseDocumentFailureKind.denied;
    }
    return SupabaseDocumentFailureKind.unknown;
  }
}
