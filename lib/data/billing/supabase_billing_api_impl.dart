import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_billing_api.dart';

/// [SupabaseBillingApi] backed by the PostgREST client.
///
/// Like [SupabaseStorageApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseBillingException]s at the
/// seam.
class SupabaseBillingApiImpl implements SupabaseBillingApi {
  SupabaseBillingApiImpl(this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseBillingApiImpl.bind() => SupabaseBillingApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client. The builder's `select`
  /// resolves to the raw row list (PostgrestList) — no cast needed.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return Supabase.instance.client.from(table).select(columns);
  }

  final BillingTableCaller _table;

  @override
  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    try {
      // RLS-scoped (D-BI2): `invoices_select_assigned` returns only the
      // caller's rows; the matterRef title comes from the embedded
      // matters(title) select (D-BI5), never a blocked `profiles` join.
      // Metadata only — the D-BI1 column list carries no card/payment data.
      return await _table(
        'billing_invoices',
        'id, matter_id, invoice_number, amount_cents, currency, status, '
            'issued_at, due_at, matters(title)',
      );
    } on PostgrestException catch (e) {
      throw SupabaseBillingException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseBillingException(
        kind: SupabaseBillingFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable RLS denial text is the only fragment matched; everything
  /// else is [SupabaseBillingFailureKind.unknown] with the message preserved.
  SupabaseBillingFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseBillingFailureKind.denied;
    }
    return SupabaseBillingFailureKind.unknown;
  }
}
