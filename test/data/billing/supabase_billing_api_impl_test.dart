import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/billing/supabase_billing_api.dart';
import 'package:legalhub/data/billing/supabase_billing_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseBillingApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late SupabaseBillingApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      api = SupabaseBillingApiImpl((String table, String columns) async {
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
      });
    });

    test('fetchInvoices selects the billing_invoices table with the VO '
        'columns', () async {
      tableData['billing_invoices'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'invoice-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchInvoices();

      expect(rows, hasLength(1));
      expect(calls, <String>[
        'billing_invoices:id, matter_id, invoice_number, amount_cents, '
            'currency, status, issued_at, due_at, matters(title)',
      ]);
    });

    test('fetchInvoices maps a table denial to the denied kind', () async {
      tableErrors['billing_invoices'] = const PostgrestException(
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
      tableErrors['billing_invoices'] = const PostgrestException(
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
      tableErrors['billing_invoices'] = const PostgrestException(
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
        objectErrors['billing_invoices'] = Exception('network down');

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
