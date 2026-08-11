import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drift pin for the production RPC binding contract — the fix for the
/// on-device crash `type 'String' is not a subtype of type
/// 'PostgrestResponse&lt;dynamic&gt;' in type cast` in
/// `SupabaseOrgApiImpl._boundRpc` (create-org flow).
///
/// The crashed line cast the awaited value to `PostgrestResponse<dynamic>`;
/// the awaited value was actually the raw id `String` — postgrest resolves
/// `await rpc<T>()` to the decoded data `T`, not the response wrapper.
///
/// postgrest 2.8.0 (supabase 2.14.0): `await client.rpc<T>()` resolves to
/// the RAW decoded data (T), NOT a `PostgrestResponse` — the response
/// wrapper is produced only when a count is requested. Every
/// `*ApiImpl._boundRpc` production binding therefore wraps the raw value
/// into the seam's `PostgrestResponse(data:…, count: 0)` shape (the exact
/// shape the unit-test stubs already use). These pins run against a REAL
/// `SupabaseClient` with a mocked HTTP layer, so if a future postgrest
/// upgrade changes the awaited shape, they fail loudly here instead of
/// crashing on a device.
void main() {
  SupabaseClient buildClient(MockClient mock) => SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: mock,
  );

  test('await rpc<dynamic> on a scalar-returning RPC yields the raw String, '
      'not a PostgrestResponse (the create-org crash contract)', () async {
    final client = buildClient(
      MockClient((request) async {
        expect(request.url.path, endsWith('/rpc/create_organization'));
        // create_organization returns uuid -> PostgREST sends a JSON scalar.
        return http.Response(
          '"d28f1f05-f95f-46ea-9b15-767f15778c01"',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final dynamic data = await client.rpc<dynamic>(
      'create_organization',
      params: {'p_name': 'x'},
    );

    // The raw awaited value IS the id String — not a PostgrestResponse.
    expect(data, 'd28f1f05-f95f-46ea-9b15-767f15778c01');
    expect(data is PostgrestResponse<dynamic>, isFalse);

    // The seam shape the impl methods read (and the test stubs use).
    final PostgrestResponse<dynamic> wrapped = PostgrestResponse<dynamic>(
      data: data,
      count: 0,
    );
    expect(wrapped.data, 'd28f1f05-f95f-46ea-9b15-767f15778c01');
  });

  test(
    'await rpc<dynamic> on a set-returning RPC yields the raw List',
    () async {
      final client = buildClient(
        MockClient((request) async {
          expect(request.url.path, endsWith('/rpc/list_org_members_metadata'));
          return http.Response(
            '[{"user_id":"10000000-0000-4000-8000-000000000002"}]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final dynamic data = await client.rpc<dynamic>(
        'list_org_members_metadata',
        params: {'p_organization_id': '20000000-0000-4000-8000-000000000001'},
      );

      expect(data, isA<List<dynamic>>());
      expect(data is PostgrestResponse<dynamic>, isFalse);
    },
  );

  test('a non-2xx RPC response still surfaces as PostgrestException '
      'from the await (the impl error mapping depends on this)', () async {
    final client = buildClient(
      MockClient(
        (request) async => http.Response(
          '{"message":"permission denied"}',
          401,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );

    await expectLater(
      client.rpc<dynamic>('create_organization', params: {'p_name': 'x'}),
      throwsA(isA<PostgrestException>()),
    );
  });
}
