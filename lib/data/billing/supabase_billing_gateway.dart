import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/billing/domain/billing_gateway.dart';
import '../../features/billing/domain/invoice.dart';
import 'supabase_billing_api.dart';

/// [BillingGateway] backed by the Supabase provider via [SupabaseBillingApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseStorageGateway]): raw rows from the seam become [Invoice] VOs,
/// and typed [SupabaseBillingException]s become [AppError]s. The `Invoice`
/// VO and all presentation are untouched — this is the env-gated
/// seam-compatible swap of plan T7 (D-BI5). Invoices are **metadata only**
/// (D-BI1/D-11): no card/payment column is ever read, so no payment
/// capability can cross this boundary.
///
/// **matterRef resolution (D-BI5):** rows store `matter_id` ids only; the VO
/// is title-keyed by design (D-W2), so the title comes from the embedded
/// `matters(title)` select (PostgREST embed, the `listMyMemberships`
/// pattern — the invoices policy guarantees the reader passes the matter
/// gate, so the embed resolves), falling back to the raw matter id when the
/// embed is absent (plan §9) — never a fabricated title.
class SupabaseBillingGateway implements BillingGateway {
  SupabaseBillingGateway(this._api);

  final SupabaseBillingApi _api;

  @override
  Future<Result<List<Invoice>>> fetchInvoices() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchInvoices();
      return Result<List<Invoice>>.success(
        List<Invoice>.unmodifiable(rows.map(_invoiceFromRow)),
      );
    } on SupabaseBillingException catch (e) {
      return Result<List<Invoice>>.failure(_mapFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected amount/status/date shape) surfaces
      // loudly, never as a silently wrong invoice.
      return Result<List<Invoice>>.failure(
        AppError(
          code: 'invoice_read_failed',
          userMessage: 'Unable to load invoices. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw invoice row to the [Invoice] VO.
  ///
  /// Every cast below is guarded above (id/matter_id/invoice_number/
  /// amount_cents/currency/status/issued_at/due_at), so a malformed row
  /// surfaces as a typed FormatException → AppError, never a raw TypeError
  /// across the boundary.
  Invoice _invoiceFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Invoice row has no id');
    }
    final Object? matterId = row['matter_id'];
    if (matterId is! String || matterId.isEmpty) {
      throw FormatException('Invoice row has no matter_id');
    }
    final Object? invoiceNumber = row['invoice_number'];
    if (invoiceNumber is! String || invoiceNumber.isEmpty) {
      throw FormatException('Invoice row has no invoice_number');
    }
    // `amount_cents` is a bigint → PostgREST hands back a Dart int; anything
    // else is provider drift (the documents/storage T7 malformed-row guard
    // baseline).
    final Object? amountCents = row['amount_cents'];
    if (amountCents is! int) {
      throw FormatException('Invoice row has no amount_cents');
    }
    final Object? currency = row['currency'];
    if (currency is! String || currency.isEmpty) {
      throw FormatException('Invoice row has no currency');
    }
    final Object? status = row['status'];
    if (status is! String || status.isEmpty) {
      throw FormatException('Invoice row has no status');
    }
    // `issued_at`/`due_at` are timestamptz → PostgREST hands back a Dart
    // DateTime; anything else is provider drift.
    final Object? issuedAt = row['issued_at'];
    if (issuedAt is! DateTime) {
      throw FormatException('Invoice row has no issued_at');
    }
    final Object? dueAt = row['due_at'];
    if (dueAt is! DateTime) {
      throw FormatException('Invoice row has no due_at');
    }
    return Invoice(
      id: id,
      // D-BI5: the embedded matters(title) join resolves under the same RLS
      // gate (the policy guarantees the reader passes the matter check); an
      // absent embed falls back to the raw matter id, never a fabricated
      // title (the listMyMemberships null-embed pattern).
      matterRef: _matterRefFromRow(row, matterId),
      invoiceNumber: invoiceNumber,
      amountCents: amountCents,
      currency: currency,
      status: _statusFromString(status),
      issuedAt: issuedAt,
      dueAt: dueAt,
    );
  }

  /// Resolves the VO's title-keyed `matterRef` from the embedded
  /// `matters(title)` select, falling back to the raw matter id (D-BI5).
  String _matterRefFromRow(Map<String, dynamic> row, String matterId) {
    final Object? matters = row['matters'];
    final Object? embeddedTitle = matters is Map<String, dynamic>
        ? matters['title']
        : null;
    return (embeddedTitle is String && embeddedTitle.isNotEmpty)
        ? embeddedTitle
        : matterId;
  }

  /// Maps the DB `status` value to the [InvoiceStatus] enum. Anything
  /// outside the `issued`/`paid` CHECK set is provider drift → loud
  /// FormatException (the D-11 minimal mapping contract).
  InvoiceStatus _statusFromString(String status) => switch (status) {
    'issued' => InvoiceStatus.issued,
    'paid' => InvoiceStatus.paid,
    _ => throw FormatException('Invoice row has an unmapped status: $status'),
  };

  /// Maps a provider failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — invoice row
  /// content never crosses into errors.
  AppError _mapFailure(SupabaseBillingException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseBillingFailureKind.denied => (
        'invoice_read_denied',
        'You do not have permission to view these invoices.',
      ),
      SupabaseBillingFailureKind.providerUnavailable => (
        'invoice_read_unavailable',
        'Invoices are temporarily unavailable. Please try again.',
      ),
      SupabaseBillingFailureKind.unknown => (
        'invoice_read_failed',
        'Unable to load invoices. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }
}
