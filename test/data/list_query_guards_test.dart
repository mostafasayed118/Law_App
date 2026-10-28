import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:legalhub/data/list_query_guards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unit tests for the bounded-SELECT decision surface
/// (`lib/data/list_query_guards.dart`).
///
/// The binding itself needs a live `Supabase.instance` client (the api-impl
/// tests inject a stub `TableCaller`, which bypasses this path entirely),
/// so the testable contract is the pure decision: the cap constant and the
/// per-table ordering table. These tests pin the table so a renamed column,
/// a flipped direction, or a dropped entry fails here instead of silently
/// changing which end of the history the capped reads keep.
///
/// Regression anchor (audit 2026-09-21, P0.4): `messages` shipped with the
/// ascending flag, so `ORDER BY sent_at ASC LIMIT 200` returned the 200
/// OLDEST messages and silently dropped the newest. The "cap keeps the
/// newest end" group below fails the moment any table is flipped back to
/// ascending.
void main() {
  group('boundedTableSelect — the list-read deadline (C1)', () {
    test('defaults to the shared 15 s seam timeout', () {
      expect(kSupabaseListReadTimeout, const Duration(seconds: 15));
    });

    test('a stalled table read times out instead of hanging forever', () async {
      final Completer<http.Response> stalled = Completer<http.Response>();
      final SupabaseClient client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: MockClient((http.Request request) => stalled.future),
      );

      await expectLater(
        boundedTableSelect(
          'notifications',
          'id',
          client: client,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('kSupabaseListRowCap', () {
    test('is the documented 200-row hard cap', () {
      expect(kSupabaseListRowCap, 200);
    });
  });

  group('orderingFor — the mapped tables', () {
    test('matters is newest-first on created_at', () {
      expect(orderingFor('matters'), ('created_at', true));
    });

    test('documents is newest-first on created_at', () {
      expect(orderingFor('documents'), ('created_at', true));
    });

    test('files is newest-first on created_at', () {
      expect(orderingFor('files'), ('created_at', true));
    });

    test('billing_invoices is newest-first on issued_at', () {
      expect(orderingFor('billing_invoices'), ('issued_at', true));
    });

    test('notifications is newest-first on server_timestamp', () {
      expect(orderingFor('notifications'), ('server_timestamp', true));
    });

    test('message_threads is newest-first on last_activity_at', () {
      expect(orderingFor('message_threads'), ('last_activity_at', true));
    });

    test('messages is newest-first on sent_at (the gateway reverses)', () {
      // The DESC fetch is what keeps the NEWEST rows under the cap; the
      // paired chronological reversal lives in
      // SupabaseMessageGateway.fetchMessages and is pinned there.
      expect(orderingFor('messages'), ('sent_at', true));
    });

    test('consultation_slots is soonest-first on starts_at', () {
      // Availability window, not a content feed: the cap must keep the
      // soonest bookable slots. This is the one deliberate ascending entry.
      expect(orderingFor('consultation_slots'), ('starts_at', false));
    });

    test('an unmapped table is capped without ordering (never 400s)', () {
      // Caller-scoped reads (e.g. memberships) get the cap only; a guessed
      // column for an unknown table would turn the SELECT into a 400.
      expect(orderingFor('memberships'), isNull);
      expect(orderingFor('audit_events'), isNull);
      expect(orderingFor('table_that_does_not_exist'), isNull);
    });
  });

  group('orderingFor — the cap keeps the newest end', () {
    test('every content table is fetched DESCENDING', () {
      // A hard cap without pagination keeps the FIRST rows of the
      // ordering — so every content list must be newest-first or it
      // silently drops its newest rows. This is the invariant the messages
      // regression violated. The availability catalogue is the explicit
      // exception: ascending keeps the soonest bookable slots.
      final List<String> ascendingTables = kSupabaseListOrderings.entries
          .where((MapEntry<String, (String, bool)> entry) => !entry.value.$2)
          .map((MapEntry<String, (String, bool)> entry) => entry.key)
          .toList(growable: false);
      expect(ascendingTables, <String>['consultation_slots']);
    });
  });

  group('requireFilterableColumn — the audit A03 allowlist', () {
    test('accepts the thread_id scoping on messages', () {
      expect(
        () => requireFilterableColumn('messages', 'thread_id'),
        returnsNormally,
      );
    });

    test('accepts the verified title columns for server-side search', () {
      expect(
        () => requireFilterableColumn('matters', 'title'),
        returnsNormally,
      );
      expect(
        () => requireFilterableColumn('documents', 'title'),
        returnsNormally,
      );
      expect(
        () => requireFilterableColumn('message_threads', 'title'),
        returnsNormally,
      );
    });

    test('accepts the Wave-A caller-scoped memberships read on user_id', () {
      expect(
        () => requireFilterableColumn('memberships', 'user_id'),
        returnsNormally,
      );
      expect(
        () => requireFilterableColumn('memberships', 'organization_id'),
        throwsArgumentError,
      );
    });

    test('rejects an unlisted column on a listed table', () {
      expect(
        () => requireFilterableColumn('messages', 'body'),
        throwsArgumentError,
      );
      expect(
        () => requireFilterableColumn('matters', 'organization_id;--'),
        throwsArgumentError,
      );
    });

    test('fails closed for tables with no allowlist entry', () {
      expect(
        () => requireFilterableColumn('notifications', 'id'),
        throwsArgumentError,
      );
      expect(
        () => requireFilterableColumn('table_that_does_not_exist', 'id'),
        throwsArgumentError,
      );
    });
  });
}
