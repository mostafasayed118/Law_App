import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/billing/supabase_billing_api.dart';
import 'package:legalhub/data/billing/supabase_billing_gateway.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';

/// Hand-rolled fake of the [SupabaseBillingApi] seam: records calls and
/// answers with canned rows or a [SupabaseBillingException], so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabaseBillingApi implements SupabaseBillingApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseBillingException? error;

  @override
  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    if (error != null) {
      throw error!;
    }
    return rows;
  }
}

Map<String, dynamic> _row({
  String id = 'invoice-1',
  String matterId = 'm-1',
  String invoiceNumber = 'INV-2026-0001',
  int amountCents = 125000,
  String currency = 'EGP',
  String status = 'issued',
  DateTime? issuedAt,
  DateTime? dueAt,
  Object? matters = const <String, dynamic>{'title': 'Demo acquisition review'},
}) => <String, dynamic>{
  'id': id,
  'matter_id': matterId,
  'invoice_number': invoiceNumber,
  'amount_cents': amountCents,
  'currency': currency,
  'status': status,
  'issued_at': issuedAt ?? DateTime(2026, 7, 1),
  'due_at': dueAt ?? DateTime(2026, 7, 31),
  'matters': matters,
};

void main() {
  late _StubSupabaseBillingApi api;
  late SupabaseBillingGateway gateway;

  setUp(() {
    api = _StubSupabaseBillingApi();
    gateway = SupabaseBillingGateway(api);
  });

  group('row → Invoice mapping (D-BI5)', () {
    test(
      'maps a full row to the Invoice VO with the embedded matter title',
      () async {
        api.rows = <Map<String, dynamic>>[_row()];

        final Result<List<Invoice>> result = await gateway.fetchInvoices();

        expect(result.isSuccess, isTrue);
        final Invoice invoice = result.valueOrNull!.single;
        expect(invoice.id, 'invoice-1');
        expect(invoice.matterRef, 'Demo acquisition review');
        expect(invoice.invoiceNumber, 'INV-2026-0001');
        expect(invoice.amountCents, 125000);
        expect(invoice.currency, 'EGP');
        expect(invoice.status, InvoiceStatus.issued);
        expect(invoice.issuedAt, DateTime(2026, 7, 1));
        expect(invoice.dueAt, DateTime(2026, 7, 31));
      },
    );

    test('maps a paid row to the paid status', () async {
      api.rows = <Map<String, dynamic>>[_row(status: 'paid')];

      final Invoice invoice =
          (await gateway.fetchInvoices()).valueOrNull!.single;

      expect(invoice.status, InvoiceStatus.paid);
    });

    test(
      'resolves matterRef from the embedded matters(title) select (D-BI5)',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(
            matterId: 'm-9',
            matters: <String, dynamic>{'title': 'Lease review'},
          ),
        ];

        final Invoice invoice =
            (await gateway.fetchInvoices()).valueOrNull!.single;

        expect(invoice.matterRef, 'Lease review');
      },
    );

    test(
      'falls back to the raw matter id when the embed is absent (D-BI5)',
      () async {
        api.rows = <Map<String, dynamic>>[_row(matters: null)];

        final Invoice invoice =
            (await gateway.fetchInvoices()).valueOrNull!.single;

        expect(invoice.matterRef, 'm-1');
      },
    );

    test(
      'falls back to the raw matter id when the embed title is empty',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(matters: <String, dynamic>{'title': ''}),
        ];

        final Invoice invoice =
            (await gateway.fetchInvoices()).valueOrNull!.single;

        expect(invoice.matterRef, 'm-1');
      },
    );

    test('returns an empty success for no rows', () async {
      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('loud provider-drift handling (no raw TypeErrors)', () {
    test('a non-int amount_cents fails the fetch loudly', () async {
      // bigint → int on PostgREST; a string here is provider drift and must
      // surface as the typed FormatException → AppError, never a raw
      // TypeError across the boundary.
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{..._row(), 'amount_cents': 'big'},
      ];

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'invoice_read_failed');
    });

    test('an unmapped status fails the fetch loudly', () async {
      // The D-11 minimal CHECK set is issued/paid; anything else is provider
      // drift and must surface loudly, never as a silently wrong invoice.
      api.rows = <Map<String, dynamic>>[_row(status: 'overdue')];

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'invoice_read_failed');
    });

    test('a missing invoice_number fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'invoice-1', 'matter_id': 'm-1'},
      ];

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'invoice_read_failed');
    });

    test('a missing matter_id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'invoice-1', 'invoice_number': 'INV-1'},
      ];

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'invoice_read_failed');
    });

    test('a missing issued_at fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'invoice-1',
          'matter_id': 'm-1',
          'invoice_number': 'INV-1',
          'amount_cents': 100,
          'currency': 'EGP',
          'status': 'issued',
          'due_at': DateTime(2026, 7, 31),
        },
      ];

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'invoice_read_failed');
    });

    test('a missing id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'matter_id': 'm-1',
          'invoice_number': 'INV-1',
          'amount_cents': 100,
          'currency': 'EGP',
          'status': 'issued',
          'issued_at': DateTime(2026, 7, 1),
          'due_at': DateTime(2026, 7, 31),
        },
      ];

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'invoice_read_failed');
    });
  });

  group('failure mapping (contract §5)', () {
    test('maps a denied read to the denied AppError code', () async {
      api.error = const SupabaseBillingException(
        kind: SupabaseBillingFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'invoice_read_denied');
      expect(error.technicalMessage, 'permission denied');
    });

    test(
      'maps an unknown failure to the generic code with no row content',
      () async {
        api.error = const SupabaseBillingException(
          kind: SupabaseBillingFailureKind.unknown,
          message: 'provider hiccup',
        );

        final Result<List<Invoice>> result = await gateway.fetchInvoices();

        final AppError error = result.errorOrNull!;
        expect(error.code, 'invoice_read_failed');
        // The failure path never touches row content (the seam throws before
        // mapping runs) and the AppError context stays empty by construction
        // — only the provider's own message crosses as the technical message.
        expect(error.technicalMessage, 'provider hiccup');
        expect(error.context, isEmpty);
      },
    );

    test('maps an unavailable read to the unavailable AppError code', () async {
      api.error = const SupabaseBillingException(
        kind: SupabaseBillingFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );

      final Result<List<Invoice>> result = await gateway.fetchInvoices();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'invoice_read_unavailable');
      expect(error.technicalMessage, 'Provider unavailable.');
    });
  });
}
