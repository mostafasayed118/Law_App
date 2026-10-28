import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/billing/data/supabase_billing_api.dart';
import 'package:legalhub/features/billing/data/supabase_billing_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/supabase_api_stub.dart';

void main() {
  group('SupabaseBillingApiImpl', () {
    late SupabaseApiStub stub;
    late SupabaseBillingApiImpl api;

    setUp(() {
      stub = SupabaseApiStub();
      api = SupabaseBillingApiImpl(stub.tableCaller);
    });

    test('fetchInvoices selects the billing_invoices table with the VO '
        'columns', () async {
      stub.tableData['billing_invoices'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'invoice-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchInvoices();

      expect(rows, hasLength(1));
      expect(stub.calls, <String>[
        'billing_invoices:id, matter_id, invoice_number, amount_cents, '
            'currency, status, issued_at, due_at, matters(title)',
      ]);
    });

    test('fetchInvoices maps a table denial to the denied kind', () async {
      stub.tableErrors['billing_invoices'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchInvoices(),
        throwsA(
          isA<SupabaseBillingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBillingFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchInvoices maps an RLS denial text to the denied kind', () async {
      stub.tableErrors['billing_invoices'] = const PostgrestException(
        message: 'new row violates row-level security policy',
      );

      await expectLater(
        api.fetchInvoices(),
        throwsA(
          isA<SupabaseBillingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBillingFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchInvoices preserves unknown failures with the message', () async {
      stub.tableErrors['billing_invoices'] = const PostgrestException(
        message: 'connection reset by peer',
      );

      await expectLater(
        api.fetchInvoices(),
        throwsA(
          isA<SupabaseBillingException>()
              .having((e) => e.kind, 'kind', SupabaseBillingFailureKind.unknown)
              .having((e) => e.message, 'message', 'connection reset by peer'),
        ),
      );
    });

    test(
      'fetchInvoices maps a non-Postgrest failure to providerUnavailable',
      () async {
        // A transport/network failure is not a PostgrestException; the impl
        // must map it to the typed unavailable kind, never leak a raw
        // exception across the seam (auth-impl defensive-catch precedent).
        stub.objectErrors['billing_invoices'] = Exception('network down');

        await expectLater(
          api.fetchInvoices(),
          throwsA(
            isA<SupabaseBillingException>().having(
              (e) => e.kind,
              'kind',
              SupabaseBillingFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );
  });
}
