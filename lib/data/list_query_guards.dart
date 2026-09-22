import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared guard constants + the bounded SELECT binding for Supabase list
/// reads (audit 2026-09-21, P1).
///
/// Every list read at the PostgREST seam is bounded server-side: an
/// explicit `.order()` (deterministic and index-backed where the migration
/// set provides one) plus a hard `.limit()` so a single call can never pull
/// an entire RLS-visible table into memory.
///
/// The cap is intentionally conservative — 200 rows covers any realistic
/// matter/document/invoice/notification list — and is a cap, not
/// pagination: cursor/`.range()` paging remains a separate slice (perf
/// backlog).
const int kSupabaseListRowCap = 200;

/// Deterministic server-side ordering per table: `(column, descending)`.
///
/// Columns are verified against the migration set (`07_storage.files
/// created_at`, `08_messages.sent_at` + `messages_thread_sent` index,
/// `14_notifications.server_timestamp` + `notifications_org_ts` index,
/// `06_message_threads.last_activity_at`, `10_billing_invoices.issued_at`).
/// Tables without an entry (e.g. the caller-scoped `memberships` read,
/// whose row count is bounded by the user's own orgs) get the cap only.
const Map<String, (String, bool)> kSupabaseListOrderings =
    <String, (String, bool)>{
      'matters': ('created_at', true),
      'documents': ('created_at', true),
      'files': ('created_at', true),
      'billing_invoices': ('issued_at', true),
      'notifications': ('server_timestamp', true),
      'message_threads': ('last_activity_at', true),
      // Chat is fetched NEWEST-first (sent_at DESC): a hard cap keeps the
      // FIRST rows of the ordering, so an ascending order here would keep
      // the 200 oldest and silently drop the newest — the worst direction
      // for a conversation read. SupabaseMessageGateway.fetchMessages
      // reverses the mapped list to chronological (oldest first) for the
      // detail screen's top-to-bottom render and the live-append path; the
      // `messages_thread_sent (thread_id, sent_at)` index serves both.
      'messages': ('sent_at', true),
    };

/// The deterministic server-side ordering for `table`, or `null` when the
/// table is capped without ordering (never fail: an unknown table falling
/// back to a guessed column would turn a SELECT into a 400 — the cap alone
/// still bounds the payload).
///
/// Exposed as a pure function so the ordering decision is unit-testable
/// without a Supabase instance (the binding itself needs the app client).
(String, bool)? orderingFor(String table) => kSupabaseListOrderings[table];

/// The production table-SELECT binding shared by every Supabase api impl:
/// a bounded, deterministically ordered table SELECT with an optional
/// equality filter.
///
/// Ordering by a column that is not in the SELECT list is a PostgREST
/// no-op for the projection (used by `files`, whose `created_at` is not
/// read client-side but still anchors the newest-first scan).
///
/// Unlisted tables are capped without ordering (never fail): an unknown
/// table falling back to a guessed column would turn a SELECT into a
/// 400 — the cap alone still bounds the payload.
Future<List<Map<String, dynamic>>> boundedTableSelect(
  String table,
  String columns, {
  String? filterColumn,
  Object? filterValue,
}) {
  // postgrest 2.8.0 type ladder: `.select()`/`.eq()` live on
  // `PostgrestFilterBuilder`, but `.order()`/`.limit()` are declared on its
  // SUPERTYPE `PostgrestTransformBuilder` and widen the static type — so
  // the filter chain is built first, then widened once for order+limit.
  // Declaring the variable as the filter builder (the previous shape) made
  // the ordered re-assignment a compile error.
  PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered = Supabase
      .instance
      .client
      .from(table)
      .select(columns);
  if (filterColumn != null && filterValue != null) {
    filtered = filtered.eq(filterColumn, filterValue);
  }
  PostgrestTransformBuilder<List<Map<String, dynamic>>> query = filtered;
  final (String orderColumn, bool descending)? ordering = orderingFor(table);
  if (ordering != null) {
    query = query.order(ordering.$1, ascending: !ordering.$2);
  }
  return query.limit(kSupabaseListRowCap);
}
