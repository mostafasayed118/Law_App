import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/state/view_state.dart';
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
import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hand-rolled stub of the membership SELECT surface (matches the convention
/// in `supabase_membership_repository_test.dart`): answers
/// [listMyMemberships] with a canned denial, everything else unimplemented.
class _DeniedOrgApi implements SupabaseOrgApi {
  @override
  Future<List<Map<String, dynamic>>> listMyMemberships() async {
    throw const SupabaseOrgException(
      kind: SupabaseOrgFailureKind.denied,
      message: 'permission denied',
    );
  }

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

/// B4 — cross-tenant / authorization-denial negative matrix (2026-09-24).
///
/// The live-E2E defects were untested regressions: no test proved that an
/// RLS denial for a cross-org, org-role-without-assignment, suspended, or
/// platform-owner query surfaces as a non-retryable unauthorized state.
///
/// The server-side guarantee lives in the SQL rehearsal battery
/// (`supabase/tests/04_matter_rls.sql`, `05_document_rls.sql`,
/// `06_message_rls.sql`, `07_storage_rls.sql`, `08_message_rls.sql`,
/// `11_invoice_rls.sql`, `14_notification_rls.sql` — each carries positive +
/// cross-org / org-role-alone / suspended / owner / anon deny rows).
/// This Dart matrix pins the client half of the contract: every read seam
/// maps the canonical PostgREST denial texts to its typed `denied` kind, the
/// membership seam maps `denied` to `HydrationFailed(denied)`, and the
/// presentation seam maps `AppErrorKind.denied` to `ViewUnauthorized`
/// (never a retryable error).
void main() {
  // The optional third positional keeps the tear-off assignable to every
  // table-caller typedef, including MessageTableCaller's `[String?
  // threadId]` (a 2-param function is NOT assignable where 3 args may be
  // passed). Messages are static: `const` cannot interpolate parameters.
  Future<List<Map<String, dynamic>>> deniedTable(
    String table,
    String columns, [
    String? threadId,
  ]) async {
    throw const PostgrestException(
      message: 'permission denied for table matters',
    );
  }

  Future<List<Map<String, dynamic>>> rlsDeniedTable(
    String table,
    String columns, [
    String? threadId,
  ]) async {
    throw const PostgrestException(
      message: 'new row violates row-level security policy for table matters',
    );
  }

  group('isPostgrestDenial pins the two canonical denial texts', () {
    test('permission denied (cross-org / suspended / owner reads)', () {
      expect(
        isPostgrestDenial(
          const PostgrestException(
            message: 'permission denied for table matters',
          ),
        ),
        isTrue,
      );
    });

    test('row-level security (assignment-gate denial)', () {
      expect(
        isPostgrestDenial(
          const PostgrestException(
            message: 'new row violates row-level security policy',
          ),
        ),
        isTrue,
      );
    });

    test('non-denial failures stay unknown (retryable)', () {
      expect(
        isPostgrestDenial(
          const PostgrestException(message: 'connection reset by peer'),
        ),
        isFalse,
      );
    });
  });

  group('every read seam maps an RLS denial to denied (not unknown)', () {
    test('matters: cross-org read → denied', () async {
      final SupabaseMatterApiImpl api = SupabaseMatterApiImpl(deniedTable);
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

    test('matters: RLS-text denial → denied', () async {
      final SupabaseMatterApiImpl api = SupabaseMatterApiImpl(rlsDeniedTable);
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

    test('documents: cross-org read → denied', () async {
      final SupabaseDocumentApiImpl api = SupabaseDocumentApiImpl(deniedTable);
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

    test('message threads: org-mismatch read → denied', () async {
      final SupabaseMessageApiImpl api = SupabaseMessageApiImpl(deniedTable);
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

    test('files: suspended-membership read → denied', () async {
      final SupabaseStorageApiImpl api = SupabaseStorageApiImpl(deniedTable);
      await expectLater(
        api.fetchFiles(),
        throwsA(
          isA<SupabaseStorageException>().having(
            (SupabaseStorageException e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.denied,
          ),
        ),
      );
    });

    test('invoices: owner read → denied', () async {
      final SupabaseBillingApiImpl api = SupabaseBillingApiImpl(deniedTable);
      await expectLater(
        api.fetchInvoices(),
        throwsA(
          isA<SupabaseBillingException>().having(
            (SupabaseBillingException e) => e.kind,
            'kind',
            SupabaseBillingFailureKind.denied,
          ),
        ),
      );
    });

    test('notifications: cross-org read → denied', () async {
      final SupabaseNotificationApiImpl api = SupabaseNotificationApiImpl(
        deniedTable,
      );
      await expectLater(
        api.fetchNotifications(),
        throwsA(
          isA<SupabaseNotificationException>().having(
            (SupabaseNotificationException e) => e.kind,
            'kind',
            SupabaseNotificationFailureKind.denied,
          ),
        ),
      );
    });
  });

  group('membership seam: denied read → HydrationFailed(denied)', () {
    test(
      'suspended caller sees denied, never fabricated memberships',
      () async {
        final SupabaseMembershipRepository repo = SupabaseMembershipRepository(
          _DeniedOrgApi(),
        );
        final MembershipHydrationResult result = await repo.loadMemberships(
          userId: 'suspended-user',
        );
        expect(result, isA<HydrationFailed>());
        expect(
          (result as HydrationFailed).kind,
          MembershipHydrationFailureKind.denied,
        );
      },
    );
  });

  group('presentation seam: denied renders unauthorized, never retry', () {
    test('AppErrorKind.denied → ViewUnauthorized', () {
      const AppError denied = AppError(
        code: 'stub_denied',
        userMessage: 'stub message',
        kind: AppErrorKind.denied,
      );
      expect(
        viewStateForFailure<List<String>>(denied),
        isA<ViewUnauthorized<List<String>>>(),
      );
    });
  });
}
