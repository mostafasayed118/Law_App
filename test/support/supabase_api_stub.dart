import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory stand-in for the two-argument table-SELECT seam shared by the
/// Supabase api-impl tests (`BillingTableCaller`, `DocumentTableCaller`,
/// `MatterTableCaller`, `NotificationTableCaller`, `StorageTableCaller`).
///
/// Behavior is pinned to the closures the five tests previously copied:
///  1. record `'$table:$columns'` in [calls];
///  2. throw [objectErrors] first (the non-Postgrest transport branch the
///     impls exercise before the Postgrest mapping);
///  3. then throw [tableErrors];
///  4. otherwise return [tableData] for the table, or an empty list when the
///     table was not seeded.
class SupabaseApiStub {
  /// Every `(table:columns)` selector the seam was called with, in order.
  final List<String> calls = <String>[];

  /// Seeded rows per table; an unseeded table returns an empty list.
  final Map<String, List<Map<String, dynamic>>> tableData =
      <String, List<Map<String, dynamic>>>{};

  /// Postgrest failures per table, thrown after [objectErrors].
  final Map<String, PostgrestException> tableErrors =
      <String, PostgrestException>{};

  /// Non-Postgrest failures per table; checked before [tableErrors].
  final Map<String, Object> objectErrors = <String, Object>{};

  /// The injectable seam callback: record, throw the configured error, else
  /// return the seeded rows.
  Future<List<Map<String, dynamic>>> tableCaller(
    String table,
    String columns,
  ) async {
    calls.add('$table:$columns');
    final Object? objectError = objectErrors[table];
    if (objectError != null) {
      throw objectError;
    }
    final PostgrestException? error = tableErrors[table];
    if (error != null) {
      throw error;
    }
    return tableData[table] ?? const <Map<String, dynamic>>[];
  }
}
