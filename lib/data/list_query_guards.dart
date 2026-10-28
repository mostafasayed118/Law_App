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
/// matter/document/invoice/notification list.
const int kSupabaseListRowCap = 200;

/// The list-read deadline, matching the RPC/storage seam: a stalled
/// PostgREST socket surfaces as a TimeoutException (a transport failure the
/// data impls map to `providerUnavailable`) instead of leaving every list
/// screen loading forever.
const Duration kSupabaseListReadTimeout = Duration(seconds: 15);

/// Deterministic server-side ordering per table: `(column, descending)`.
///
/// Columns are verified against the migration set (`07_storage.files
/// created_at`, `08_messages.sent_at` + `messages_thread_sent` index,
/// `14_notifications.server_timestamp` + `notifications_org_ts` index,
/// `06_message_threads.last_activity_at`, `10_billing_invoices.issued_at`).
/// Tables without an entry (e.g. the `memberships` read, which is scoped
/// to the caller's own rows by an equality filter) get the cap only.
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
      'tasks': ('created_at', true),
      // Availability catalogue: ascending is deliberate — the cap must keep
      // the SOONEST bookable slots, not the furthest-out ones. This is not a
      // content feed, so the newest-end invariant does not apply; the
      // ordering test carries an explicit ascending allowlist for this table.
      'consultation_slots': ('starts_at', false),
    };

/// The deterministic server-side ordering for `table`, or `null` when the
/// table is capped without ordering (never fail: an unknown table falling
/// back to a guessed column would turn a SELECT into a 400 — the cap alone
/// still bounds the payload).
///
/// Exposed as a pure function so the ordering decision is unit-testable
/// without a Supabase instance (the binding itself needs the app client).
(String, bool)? orderingFor(String table) => kSupabaseListOrderings[table];

/// Per-table allowlist for caller-supplied filter column names (audit A03).
///
/// `.eq()`/`.ilike()` take a raw column name: PostgREST validates it against
/// the schema (so no SQL injection), but without an allowlist a
/// caller-controlled name could probe filters on columns that must never
/// drive a query (e.g. RLS-bypass-adjacent or PII-heavy columns). Columns
/// land here only when verified against the migration-set projections; a
/// table with no entry (or a column missing from its set) fails closed with
/// an [ArgumentError] — a programming error, never user input.
const Map<String, Set<String>> kSupabaseFilterableColumns =
    <String, Set<String>>{
      'matters': <String>{
        'id',
        'organization_id',
        'title',
        'practice_area',
        'status',
        'assigned_attorney_id',
      },
      'documents': <String>{'id', 'matter_id', 'title', 'document_type'},
      'files': <String>{'id', 'matter_id', 'name'},
      'billing_invoices': <String>{
        'id',
        'matter_id',
        'invoice_number',
        'status',
      },
      'messages': <String>{'id', 'thread_id'},
      'message_threads': <String>{'id', 'matter_id', 'title'},
      'memberships': <String>{'user_id'},
    };

/// Throws [ArgumentError] unless [column] is an allowed filter on [table].
void requireFilterableColumn(String table, String column) {
  final Set<String>? allowed = kSupabaseFilterableColumns[table];
  if (allowed == null || !allowed.contains(column)) {
    throw ArgumentError(
      'Column "$column" is not an allowed filter on table "$table".',
    );
  }
}

/// The production table-SELECT binding shared by every Supabase api impl:
/// a bounded, deterministically ordered table SELECT with an optional
/// equality filter, an optional case-insensitive substring filter, and an
/// optional `.range()` page window.
///
/// Ordering by a column that is not in the SELECT list is a PostgREST
/// no-op for the projection (used by `files`, whose `created_at` is not
/// read client-side but still anchors the newest-first scan).
///
/// Unlisted tables are capped without ordering (never fail): an unknown
/// table falling back to a guessed column would turn a SELECT into a
/// 400 — the cap alone still bounds the payload.
///
/// Defaults preserve the pre-pagination contract exactly (cap 200, no
/// offset, no ilike), so every existing caller keeps its behavior until it
/// opts into paging. Every read carries the shared [kSupabaseListReadTimeout]
/// deadline (overridable for tests via [timeout]).
Future<List<Map<String, dynamic>>> boundedTableSelect(
  String table,
  String columns, {
  String? filterColumn,
  Object? filterValue,
  int? limit,
  int? offset,
  String? ilikeColumn,
  String? ilikeValue,
  Duration timeout = kSupabaseListReadTimeout,
  SupabaseClient? client,
}) {
  // postgrest 2.8.0 type ladder: `.select()`/`.eq()`/`.ilike()` live on
  // `PostgrestFilterBuilder`, but `.order()`/`.limit()`/`.range()` are
  // declared on its SUPERTYPE `PostgrestTransformBuilder` and widen the
  // static type — so the filter chain is built first, then widened once
  // for order+limit/range. Declaring the variable as the filter builder
  // (the previous shape) made the ordered re-assignment a compile error.
  PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered =
      (client ?? Supabase.instance.client).from(table).select(columns);
  if (filterColumn != null && filterValue != null) {
    requireFilterableColumn(table, filterColumn);
    filtered = filtered.eq(filterColumn, filterValue);
  }
  if (ilikeColumn != null && ilikeValue != null && ilikeValue.isNotEmpty) {
    requireFilterableColumn(table, ilikeColumn);
    filtered = filtered.ilike(ilikeColumn, '%${_escapeIlike(ilikeValue)}%');
  }
  PostgrestTransformBuilder<List<Map<String, dynamic>>> query = filtered;
  final (String orderColumn, bool descending)? ordering = orderingFor(table);
  if (ordering != null) {
    query = query.order(ordering.$1, ascending: !ordering.$2);
  }
  final int effectiveLimit = limit ?? kSupabaseListRowCap;
  final Future<List<Map<String, dynamic>>> read = offset != null
      ? query.range(offset, offset + effectiveLimit - 1)
      : query.limit(effectiveLimit);
  return read.timeout(timeout);
}

/// Escapes PostgREST `like` wildcards (`%`, `_`, `\`) in user input so a
/// literal search for `100%` cannot become a wildcard match.
String _escapeIlike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
