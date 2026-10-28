import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drift pin for the postgrest TABLE-SELECT await contract — the same
/// crash class as the RPC binding fix (`supabase_rpc_await_contract_test.dart`),
/// for the `from(table).select(columns)` pattern every `*ApiImpl` table
/// seam uses (org memberships, billing, notifications, matters, documents,
/// storage, messaging — the `_boundTable` / `_table` callables typed
/// `Future<List<Map<String, dynamic>>>`).
///
/// postgrest 2.8.0: `await client.from(t).select(c)` resolves to the RAW
/// decoded row list (`PostgrestList`), NOT a `PostgrestResponse` — the
/// response wrapper is produced only when a count is requested. If a
/// future postgrest upgrade changes this, these pins fail loudly here
/// instead of breaking every table read on a device.
void main() {
  SupabaseClient buildClient(MockClient mock) => SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: mock,
  );

  test('await from().select() yields the raw row list, not a '
      'PostgrestResponse (the _boundTable contract)', () async {
    final client = buildClient(
      MockClient((request) async {
        expect(request.url.path, endsWith('/rest/v1/notifications'));
        return http.Response(
          '[{"id":"b0000000-0000-4000-8000-000000000001","summary":"x"}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final List<Map<String, dynamic>> rows = await client
        .from('notifications')
        .select('*');

    expect(rows, hasLength(1));
    expect(rows.single['id'], 'b0000000-0000-4000-8000-000000000001');
    expect(rows is PostgrestResponse<dynamic>, isFalse);
  });

  test('await from().select().eq() (the messaging chained pattern) yields '
      'the raw row list too', () async {
    final client = buildClient(
      MockClient((request) async {
        expect(request.url.path, endsWith('/rest/v1/messages'));
        // PostgREST encodes filters with the operator prefix.
        expect(
          request.url.queryParameters['thread_id'],
          'eq.60000000-0000-4000-8000-000000000001',
        );
        return http.Response(
          '[{"id":"52a5cba7-3c52-457c-92ba-55cc1d50d344"}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final List<Map<String, dynamic>> rows = await client
        .from('messages')
        .select('*')
        .eq('thread_id', '60000000-0000-4000-8000-000000000001');

    expect(rows.single['id'], '52a5cba7-3c52-457c-92ba-55cc1d50d344');
    expect(rows is PostgrestResponse<dynamic>, isFalse);
  });
}
