import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_matter_api.dart';

/// [SupabaseMatterApi] backed by the PostgREST client.
///
/// Like [SupabaseOrgApiImpl], this is a data-layer file whose only job is
/// holding the provider import: a table SELECT in, plain map rows out, and
/// PostgrestExceptions mapped to [SupabaseMatterException]s at the seam.
class SupabaseMatterApiImpl implements SupabaseMatterApi {
  SupabaseMatterApiImpl(this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseMatterApiImpl.bind() => SupabaseMatterApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client. The builder's `select`
  /// resolves to the raw row list (PostgrestList) — no cast needed.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return Supabase.instance.client.from(table).select(columns);
  }

  final MatterTableCaller _table;

  @override
  Future<List<Map<String, dynamic>>> fetchMatters() async {
    try {
      // RLS-scoped (D-MR1): `matters_select_assigned` returns only the
      // caller's assigned rows; ids only, names resolve via the roster seam
      // (D-MR4). `assigned_attorney_id` may be null (no attorney assigned).
      return await _table(
        'matters',
        'id, organization_id, title, practice_area, status, '
            'assigned_attorney_id, created_at',
      );
    } on PostgrestException catch (e) {
      throw SupabaseMatterException(kind: _kindFor(e), message: e.message);
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable RLS denial text is the only fragment matched; everything
  /// else is [SupabaseMatterFailureKind.unknown] with the message preserved.
  SupabaseMatterFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseMatterFailureKind.denied;
    }
    return SupabaseMatterFailureKind.unknown;
  }
}
