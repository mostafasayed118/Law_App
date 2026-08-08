/// Provider-neutral billing_invoices-table seam.
///
/// The seam is the only surface the billing gateway talks to: plain map rows
/// out, typed [SupabaseBillingException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseDocumentApi] /
/// [SupabaseStorageApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `StorageTableCaller` from the
/// storage seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef BillingTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// Typed reasons the invoices read can fail, mapped from the PostgREST
/// surface. The read path is a plain RLS-scoped SELECT — the RPC-specific
/// kinds of the organization seam cannot occur here.
enum SupabaseBillingFailureKind {
  /// The caller is not permitted to read the requested rows (RLS denied or
  /// the caller has no session).
  denied,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseBillingApi] seam.
class SupabaseBillingException implements Exception {
  const SupabaseBillingException({required this.kind, required this.message});

  final SupabaseBillingFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseBillingException(${kind.name}): $message';
}

/// billing_invoices-table surface backed by the Supabase PostgREST client.
///
/// The SELECT is RLS-scoped (D-BI2): the `invoices_select_assigned` policy
/// returns only the rows whose matter the caller is assigned to (client or
/// attorney) as an active member of the invoice's org. Rows carry ids + the
/// embedded matter title — the gateway resolves the VO's title-keyed
/// `matterRef` from the embed, falling back to the raw matter id (D-BI5).
/// The table is **metadata-only by construction** (D-BI1 — no card/payment
/// column exists), so no payment data can cross this seam.
abstract interface class SupabaseBillingApi {
  /// The caller's assignment-scoped `billing_invoices` rows.
  ///
  /// Columns requested: `id`, `matter_id`, `invoice_number`, `amount_cents`,
  /// `currency`, `status`, `issued_at`, `due_at`, `matters(title)` — the
  /// metadata-only read surface the [Invoice] VO needs (D-BI1).
  Future<List<Map<String, dynamic>>> fetchInvoices();
}
