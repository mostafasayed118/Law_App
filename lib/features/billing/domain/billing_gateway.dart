import '../../../core/errors/result.dart';
import 'invoice.dart';

/// Billing integration boundary (ninth §14 un-deferral, billing slice
/// D-BI5).
///
/// This slice **builds** the minimal consumer-attached surface (there was no
/// fake to swap): a dev fake is registered for env-less runs and ALL tests,
/// and the env-gated Supabase implementation takes over only in configured
/// builds behind `env.isConfigured` (the documents/messages/storage flip
/// pattern). **Metadata only** — no payment capability, no charge method,
/// never crosses this boundary (D-11: no live payment in MVP; the
/// metadata-only line is structural on the [Invoice] VO).
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class BillingGateway {
  /// The caller's assignment-scoped invoice-metadata list (active member of
  /// the invoice's org AND assigned on its matter, matrix §4 — the
  /// `invoices_select_assigned` RLS gate server-side). Deterministic and
  /// read-only.
  Future<Result<List<Invoice>>> fetchInvoices();
}
