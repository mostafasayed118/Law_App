import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_billing_api.dart';

/// [SupabaseBillingApi] backed by the PostgREST client.
///
/// Like [SupabaseStorageApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseBillingException]s at the
/// seam.
class SupabaseBillingApiImpl implements SupabaseBillingApi {
  SupabaseBillingApiImpl(
    this._table, {
    BillingMatterTableCaller? matterTableCaller,
  }) : _matterTable = matterTableCaller ?? _boundMatterTable;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseBillingApiImpl.bind() => SupabaseBillingApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first `.order('issued_at')`
  /// + a hard row cap (audit 2026-09-21, P1).
  /// Shared seam binding ([SupabaseSeam.boundTable]).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  /// Binds the matter-scoped read to the app-level client via the shared
  /// filtered binding: the same cap + order as [boundTable], with
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

  final BillingTableCaller _table;
  final BillingMatterTableCaller _matterTable;

  @override
  Future<List<Map<String, dynamic>>> fetchInvoices({String? matterId}) async {
    try {
      // RLS-scoped (D-BI2): `invoices_select_assigned` returns only the
      // caller's rows; the matterRef title comes from the embedded
      // matters(title) select (D-BI5), never a blocked `profiles` join.
      // Metadata only — the D-BI1 column list carries no card/payment data.
      // A non-null [matterId] narrows the transfer to the open matter.
      const String columns =
          'id, matter_id, invoice_number, amount_cents, currency, status, '
          'issued_at, due_at, matters(title)';
      return matterId == null
          ? await _table(SupabaseTables.billingInvoices, columns)
          : await _matterTable(
              SupabaseTables.billingInvoices,
              columns,
              matterId,
            );
    } on PostgrestException catch (e) {
      throw SupabaseBillingException(kind: _kindFor(e), message: e.message);
    } on Exception {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseBillingException(
        kind: SupabaseBillingFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor] — audit 2026-09-27,
  /// Q-Q1): this impl supplies only its enum values, the match-once logic
  /// lives in `postgrest_failures.dart`.
  SupabaseBillingFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseBillingFailureKind.denied,
      unknown: SupabaseBillingFailureKind.unknown,
    );
  }
}
