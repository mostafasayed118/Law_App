import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/data/billing/supabase_billing_api.dart';
import 'package:legalhub/data/billing/supabase_billing_api_impl.dart';
import 'package:legalhub/data/documents/supabase_document_api.dart';
import 'package:legalhub/data/documents/supabase_document_api_impl.dart';
import 'package:legalhub/data/matters/supabase_matter_api.dart';
import 'package:legalhub/data/matters/supabase_matter_api_impl.dart';
import 'package:legalhub/data/messaging/supabase_message_api.dart';
import 'package:legalhub/data/messaging/supabase_message_api_impl.dart';
import 'package:legalhub/data/notifications/supabase_notification_api.dart';
import 'package:legalhub/data/notifications/supabase_notification_api_impl.dart';
import 'package:legalhub/data/orgs/supabase_membership_repository.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// R6 — network/error-path fault injection (2026-09-24).
///
/// The E2E report could not exercise real error surfaces because the demo
/// build resolves data locally. These tests pin the provider-failure
/// contract at the seam with a mocked transport: 401/403-shaped PostgREST
/// denials map to `denied`, 500-shaped PostgREST failures preserve their
/// message as `unknown` (never misclassified as a denial), and transport
/// failures (timeout / offline / closed client) map to `providerUnavailable`
/// (never leak a raw exception across the seam).
class _FailingOrgApi implements SupabaseOrgApi {
  _FailingOrgApi(this.error);

  final Object error;

  @override
  Future<List<Map<String, dynamic>>> listMyMemberships({
    required String userId,
  }) async => throw error;

  @override
  Future<String> createOrganization({required String name}) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> listAssignableMembers({
    required String matterId,
  }) async => throw UnimplementedError();

  @override
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  }) async => throw UnimplementedError();

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async => throw UnimplementedError();

  @override
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  }) async => throw UnimplementedError();

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async => throw UnimplementedError();

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async => throw UnimplementedError();

  @override
  Future<String> resendInvitation({required String invitationId}) async =>
      throw UnimplementedError();

  @override
  Future<void> revokeInvitation({required String invitationId}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteMyAccount() async => throw UnimplementedError();

  @override
  Future<String> acceptInvitation({required String token}) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit({
    required String organizationId,
  }) async => throw UnimplementedError();
}

void main() {
  // Explicit function type with the optional third positional, so the stub
  // satisfies every table-caller typedef (see rls_denial_matrix_test.dart).
  Future<List<Map<String, dynamic>>> Function(String, String, [String?])
  tableFor(Object error) {
    return (String table, String columns, [String? threadId]) async {
      throw error;
    };
  }

  group('401/403-shaped denials → denied (never retryable)', () {
    test('matters: 403 permission denied → denied', () async {
      final SupabaseMatterApiImpl api = SupabaseMatterApiImpl(
        tableFor(const PostgrestException(message: 'permission denied')),
      );
      await expectLater(
        api.fetchMatters(),
        throwsA(
          isA<SupabaseMatterException>().having(
            (SupabaseMatterException e) => e.kind,
            'kind',
            SupabaseMatterFailureKind.denied,
          ),
        ),
      );
    });

    test('documents: 401 JWT-shaped denial text → denied', () async {
      final SupabaseDocumentApiImpl api = SupabaseDocumentApiImpl(
        tableFor(
          const PostgrestException(
            message: 'permission denied for table documents',
          ),
        ),
      );
      await expectLater(
        api.fetchDocuments(),
        throwsA(
          isA<SupabaseDocumentException>().having(
            (SupabaseDocumentException e) => e.kind,
            'kind',
            SupabaseDocumentFailureKind.denied,
          ),
        ),
      );
    });

    test('messages: RLS denial → denied', () async {
      final SupabaseMessageApiImpl api = SupabaseMessageApiImpl(
        tableFor(
          const PostgrestException(
            message: 'new row violates row-level security policy',
          ),
        ),
      );
      await expectLater(
        api.fetchMessageThreads(),
        throwsA(
          isA<SupabaseMessageException>().having(
            (SupabaseMessageException e) => e.kind,
            'kind',
            SupabaseMessageFailureKind.denied,
          ),
        ),
      );
    });

    test('membership hydration: 403 → HydrationFailed(denied)', () async {
      final SupabaseMembershipRepository repo = SupabaseMembershipRepository(
        _FailingOrgApi(
          const SupabaseOrgException(
            kind: SupabaseOrgFailureKind.denied,
            message: 'permission denied',
          ),
        ),
      );
      final MembershipHydrationResult result = await repo.loadMemberships(
        userId: 'u-1',
      );
      expect(result, isA<HydrationFailed>());
      expect(
        (result as HydrationFailed).kind,
        MembershipHydrationFailureKind.denied,
      );
    });
  });

  group('500-shaped failures → unknown with the message preserved', () {
    test('matters: internal error stays unknown (not a denial)', () async {
      final SupabaseMatterApiImpl api = SupabaseMatterApiImpl(
        tableFor(const PostgrestException(message: 'internal server error')),
      );
      await expectLater(
        api.fetchMatters(),
        throwsA(
          isA<SupabaseMatterException>()
              .having(
                (SupabaseMatterException e) => e.kind,
                'kind',
                SupabaseMatterFailureKind.unknown,
              )
              .having(
                (SupabaseMatterException e) => e.message,
                'message',
                'internal server error',
              ),
        ),
      );
    });

    test('files: 500 stays unknown', () async {
      final SupabaseStorageApiImpl api = SupabaseStorageApiImpl(
        tableFor(const PostgrestException(message: 'database timeout')),
      );
      await expectLater(
        api.fetchFiles(),
        throwsA(
          isA<SupabaseStorageException>().having(
            (SupabaseStorageException e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.unknown,
          ),
        ),
      );
    });

    test('invoices: 500 stays unknown', () async {
      final SupabaseBillingApiImpl api = SupabaseBillingApiImpl(
        tableFor(const PostgrestException(message: 'connection refused')),
      );
      await expectLater(
        api.fetchInvoices(),
        throwsA(
          isA<SupabaseBillingException>().having(
            (SupabaseBillingException e) => e.kind,
            'kind',
            SupabaseBillingFailureKind.unknown,
          ),
        ),
      );
    });

    test('notifications: 500 stays unknown', () async {
      final SupabaseNotificationApiImpl api = SupabaseNotificationApiImpl(
        tableFor(const PostgrestException(message: 'bad gateway')),
      );
      await expectLater(
        api.fetchNotifications(),
        throwsA(
          isA<SupabaseNotificationException>().having(
            (SupabaseNotificationException e) => e.kind,
            'kind',
            SupabaseNotificationFailureKind.unknown,
          ),
        ),
      );
    });
  });

  group('transport failures → providerUnavailable (never raw)', () {
    test('matters: timeout/offline → providerUnavailable', () async {
      final SupabaseMatterApiImpl api = SupabaseMatterApiImpl(
        tableFor(Exception('network unreachable')),
      );
      await expectLater(
        api.fetchMatters(),
        throwsA(
          isA<SupabaseMatterException>().having(
            (SupabaseMatterException e) => e.kind,
            'kind',
            SupabaseMatterFailureKind.providerUnavailable,
          ),
        ),
      );
    });

    test('documents: closed client → providerUnavailable', () async {
      final SupabaseDocumentApiImpl api = SupabaseDocumentApiImpl(
        tableFor(Exception('client closed')),
      );
      await expectLater(
        api.fetchDocuments(),
        throwsA(
          isA<SupabaseDocumentException>().having(
            (SupabaseDocumentException e) => e.kind,
            'kind',
            SupabaseDocumentFailureKind.providerUnavailable,
          ),
        ),
      );
    });

    test('membership hydration: offline → providerUnavailable', () async {
      // R6 fix: the repository defensive-catches transport failures (the
      // matter/document/message api impls' precedent) so a network blip
      // surfaces as typed unavailable, never a raw exception — the session
      // is never invalidated by it.
      final SupabaseMembershipRepository repo = SupabaseMembershipRepository(
        _FailingOrgApi(Exception('network unreachable')),
      );
      final MembershipHydrationResult result = await repo.loadMemberships(
        userId: 'u-1',
      );
      expect(result, isA<HydrationFailed>());
      expect(
        (result as HydrationFailed).kind,
        MembershipHydrationFailureKind.providerUnavailable,
      );
    });
  });
}
