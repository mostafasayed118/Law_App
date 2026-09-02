import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/pending_accept_invite_store.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/admin/platform_admin_gateway.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/auth/auth_state.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/sample_service.dart';
import 'package:legalhub/data/admin/fake_platform_admin_gateway.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_api.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_gateway.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/data/auth/supabase_auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_env.dart';
import 'package:legalhub/data/billing/supabase_billing_api.dart';
import 'package:legalhub/data/billing/supabase_billing_gateway.dart';
import 'package:legalhub/data/documents/supabase_document_api.dart';
import 'package:legalhub/data/documents/supabase_document_gateway.dart';
import 'package:legalhub/data/local/in_memory_org_selection_store.dart';
import 'package:legalhub/data/local/locale_store.dart';
import 'package:legalhub/data/local/org_selection_store.dart';
import 'package:legalhub/data/matters/supabase_matter_api.dart';
import 'package:legalhub/data/matters/supabase_matter_gateway.dart';
import 'package:legalhub/data/matters/supabase_matter_write_api.dart';
import 'package:legalhub/data/matters/supabase_matter_write_gateway.dart';
import 'package:legalhub/data/messaging/supabase_message_api.dart';
import 'package:legalhub/data/messaging/supabase_message_gateway.dart';
import 'package:legalhub/data/messaging/supabase_message_realtime_api.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/data/orgs/supabase_membership_repository.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:legalhub/data/orgs/supabase_organization_gateway.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_gateway.dart';
import 'package:legalhub/features/auth/data/fake_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/data/fake_sign_up_gateway.dart';
import 'package:legalhub/features/auth/data/supabase_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/billing/data/fake_billing_gateway.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/booking/data/fake_booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_prefill.dart';
import 'package:legalhub/features/discovery/data/fake_attorney_gateway.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_write_gateway.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter_write_gateway.dart';
import 'package:legalhub/features/messaging/data/fake_message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/orgs/presentation/active_org_store.dart';
import 'package:legalhub/features/research/data/synthetic_ai_gateway.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/storage/data/fake_storage_gateway.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';

/// Hand-rolled fake of the [SupabaseAuthApi] seam for the DI flip test.
/// The real `SupabaseAuthApiImpl.bind()` needs a running `Supabase.instance`,
/// which no test should spin up — the flip's test seam injects this instead.
class _FakeSupabaseAuthApi implements SupabaseAuthApi {
  final StreamController<SupabaseAuthSnapshot?> _changes =
      StreamController<SupabaseAuthSnapshot?>.broadcast();

  @override
  SupabaseAuthSnapshot? get currentSnapshot => null;

  @override
  Stream<SupabaseAuthSnapshot?> get snapshotChanges => _changes.stream;

  @override
  Future<SupabaseAuthSnapshot?> restore() async => null;

  @override
  Future<SupabaseAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async => const SupabaseAuthSuccess(null);

  @override
  Future<SupabaseSignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => const SupabaseSignUpPending();

  @override
  Future<SupabaseAuthResult> resetPasswordForEmail(String email) async =>
      const SupabaseAuthSuccess(null);

  @override
  Future<SupabaseAuthResult> verifyOtp({
    required String email,
    required String code,
  }) async => const SupabaseAuthSuccess(null);

  @override
  Future<SupabaseAuthResult> updateUserPassword(String newPassword) async =>
      const SupabaseAuthSuccess(null);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> dispose() async => _changes.close();
}

/// Hand-rolled fake of the [SupabaseOrgApi] seam for the DI flip test.
class _FakeSupabaseOrgApi implements SupabaseOrgApi {
  @override
  Future<String> createOrganization({required String name}) async => 'org-1';

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listMyMemberships() async =>
      <Map<String, dynamic>>[];

  @override
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  }) async => 'token';

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  }) async {}

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async {}

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {}

  @override
  Future<String> resendInvitation({required String invitationId}) async =>
      'token';

  @override
  Future<void> revokeInvitation({required String invitationId}) async {}

  @override
  Future<void> deleteMyAccount() async {}

  @override
  Future<String> acceptInvitation({required String token}) async =>
      'membership-1';

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit({
    required String organizationId,
  }) async => <Map<String, dynamic>>[];
}

/// Hand-rolled fake of the [SupabasePlatformAdminApi] seam for the DI flip
/// test (same discipline as [_FakeSupabaseOrgApi]).
class _FakeSupabasePlatformAdminApi implements SupabasePlatformAdminApi {
  @override
  Future<List<Map<String, dynamic>>> listOrganizations() async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listMembers() async =>
      <Map<String, dynamic>>[];

  @override
  Future<void> suspendMembership({
    required String organizationId,
    required String userId,
  }) async {}

  @override
  Future<void> reactivateMembership({
    required String organizationId,
    required String userId,
  }) async {}

  @override
  Future<void> deleteDemoAccount({required String userId}) async {}

  @override
  Future<List<Map<String, dynamic>>> readPlatformAudit() async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit(
    String organizationId,
  ) async => <Map<String, dynamic>>[];
}

/// Hand-rolled fake of the [SupabaseMatterApi] seam for the DI flip test
/// (same discipline as [_FakeSupabaseOrgApi]).
class _FakeSupabaseMatterApi implements SupabaseMatterApi {
  @override
  Future<List<Map<String, dynamic>>> fetchMatters() async =>
      <Map<String, dynamic>>[];
}

/// Hand-rolled fake of the [SupabaseMatterWriteApi] seam for the DI flip
/// test (same discipline as [_FakeSupabaseMatterApi]).
class _FakeSupabaseMatterWriteApi implements SupabaseMatterWriteApi {
  @override
  Future<String> createMatter({
    required String organizationId,
    required String title,
    required String practiceArea,
    String? assignedClientId,
    String? assignedAttorneyId,
  }) async => 'created-matter-1';
}

/// Hand-rolled fake of the [SupabaseDocumentApi] seam for the DI flip test
/// (same discipline as [_FakeSupabaseMatterApi]).
class _FakeSupabaseDocumentApi implements SupabaseDocumentApi {
  @override
  Future<List<Map<String, dynamic>>> fetchDocuments() async =>
      <Map<String, dynamic>>[];
}

/// Hand-rolled fake of the [SupabaseMessageApi] seam for the DI flip test
/// (same discipline as [_FakeSupabaseDocumentApi]).
class _FakeSupabaseMessageApi implements SupabaseMessageApi {
  @override
  Future<List<Map<String, dynamic>>> fetchMessageThreads() async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchMessages(String threadId) async =>
      <Map<String, dynamic>>[];

  @override
  Future<String> sendMessage(String threadId, String body) async => 'msg-1';
}

/// Hand-rolled fake of the [SupabaseMessageRealtimeApi] seam for the DI flip
/// test (same discipline as [_FakeSupabaseMessageApi]; a never-emitting
/// stream keeps the configured flip hermetic without a provider).
class _FakeSupabaseMessageRealtimeApi implements SupabaseMessageRealtimeApi {
  @override
  Stream<SupabaseMessageRealtimeEvent> watchMessages(String threadId) =>
      const Stream<SupabaseMessageRealtimeEvent>.empty();

  @override
  Future<void> close() async {}
}

/// Hand-rolled fake of the [SupabaseStorageApi] seam for the DI flip test
/// (same discipline as [_FakeSupabaseMessageApi]).
class _FakeSupabaseStorageApi implements SupabaseStorageApi {
  @override
  Future<List<Map<String, dynamic>>> fetchFiles() async =>
      <Map<String, dynamic>>[];
}

/// Hand-rolled fake of the [SupabaseBillingApi] seam for the DI flip test
/// (same discipline as [_FakeSupabaseStorageApi]).
class _FakeSupabaseBillingApi implements SupabaseBillingApi {
  @override
  Future<List<Map<String, dynamic>>> fetchInvoices() async =>
      <Map<String, dynamic>>[];
}

/// Builds a JWT-shaped string whose payload carries the given role claim.
/// Matches the base64url convention used by the supabase adapter tests.
String _jwtWithRole(String role) {
  final String header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final String payload = base64Url
      .encode(utf8.encode('{"iss":"supabase","role":"$role"}'))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

/// Builds a JWT-shaped string whose payload carries `role: anon` — a valid
/// anon-public-key shape for the guard, without any real credential.
String _anonJwt() => _jwtWithRole('anon');

void main() {
  // Ensure a clean locator between tests; GetIt is a process-global singleton.
  tearDown(resetServiceLocator);

  group('configureDependencies (B3 DI foundation)', () {
    test('registers SampleService', () {
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
    });

    test('resolves SampleService as a lazy singleton', () {
      configureDependencies();

      final SampleService first = serviceLocator<SampleService>();
      final SampleService second = serviceLocator<SampleService>();

      // Lazy singleton: same instance across resolutions.
      expect(identical(first, second), isTrue);
      expect(first.name, 'SampleService');
    });

    test('is idempotent when called more than once', () {
      configureDependencies();
      // Calling again must not throw (guard prevents double registration).
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
    });

    test('throws when resolving an unregistered dependency', () {
      // Before configureDependencies() runs, nothing is registered.
      expect(() => serviceLocator<SampleService>(), throwsStateError);
    });
  });

  // The full DI graph: configureDependencies() registers every application
  // dependency. The earlier group only proved SampleService. These tests pin
  // each registration so a future refactor that drops a wiring line fails
  // loudly instead of breaking at runtime in a screen test.
  group('configureDependencies full registration graph', () {
    test('registers every application dependency', () {
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
      expect(serviceLocator.isRegistered<AuthGateway>(), isTrue);
      expect(serviceLocator.isRegistered<ErrorReporter>(), isTrue);
      expect(serviceLocator.isRegistered<LocaleStore>(), isTrue);
      expect(serviceLocator.isRegistered<LocaleCubit>(), isTrue);
      expect(serviceLocator.isRegistered<PasswordRecoveryGateway>(), isTrue);
      expect(serviceLocator.isRegistered<SignUpGateway>(), isTrue);
      expect(serviceLocator.isRegistered<OrganizationGateway>(), isTrue);
      expect(serviceLocator.isRegistered<MembershipRepository>(), isTrue);
      expect(serviceLocator.isRegistered<PlatformAdminGateway>(), isTrue);
      expect(serviceLocator.isRegistered<OrgSelectionStore>(), isTrue);
      expect(serviceLocator.isRegistered<BookingGateway>(), isTrue);
      expect(serviceLocator.isRegistered<BookingPrefill>(), isTrue);
      expect(serviceLocator.isRegistered<PendingAcceptInviteStore>(), isTrue);
      expect(serviceLocator.isRegistered<AttorneyGateway>(), isTrue);
      expect(serviceLocator.isRegistered<ActiveOrgStore>(), isTrue);
      expect(serviceLocator.isRegistered<MatterGateway>(), isTrue);
      expect(serviceLocator.isRegistered<MatterWriteGateway>(), isTrue);
      expect(serviceLocator.isRegistered<DocumentGateway>(), isTrue);
      expect(serviceLocator.isRegistered<MessageGateway>(), isTrue);
      expect(serviceLocator.isRegistered<StorageGateway>(), isTrue);
      expect(serviceLocator.isRegistered<AiGateway>(), isTrue);
      expect(serviceLocator.isRegistered<AuthCubit>(), isTrue);
    });

    test('resolves each dependency as a lazy singleton (stable instance)', () {
      configureDependencies();

      // Stateful app-scoped cubits must resolve to the same instance across
      // calls; the router and MaterialApp depend on that identity.
      expect(
        identical(serviceLocator<LocaleCubit>(), serviceLocator<LocaleCubit>()),
        isTrue,
      );
      expect(
        identical(serviceLocator<AuthCubit>(), serviceLocator<AuthCubit>()),
        isTrue,
      );
      // Stateless services are also lazy singletons.
      expect(
        identical(
          serviceLocator<PasswordRecoveryGateway>(),
          serviceLocator<PasswordRecoveryGateway>(),
        ),
        isTrue,
      );
      expect(
        identical(
          serviceLocator<BookingGateway>(),
          serviceLocator<BookingGateway>(),
        ),
        isTrue,
      );
      expect(
        identical(
          serviceLocator<AttorneyGateway>(),
          serviceLocator<AttorneyGateway>(),
        ),
        isTrue,
      );
      expect(
        identical(
          serviceLocator<BookingPrefill>(),
          serviceLocator<BookingPrefill>(),
        ),
        isTrue,
      );
      expect(
        identical(
          serviceLocator<PendingAcceptInviteStore>(),
          serviceLocator<PendingAcceptInviteStore>(),
        ),
        isTrue,
      );
      expect(
        identical(
          serviceLocator<ActiveOrgStore>(),
          serviceLocator<ActiveOrgStore>(),
        ),
        isTrue,
      );
    });

    test('wires the recovery gateway to the fake dev implementation', () {
      configureDependencies();

      // In unconfigured builds the dev-only fake is the registered seam.
      // Pinning the concrete type catches a future swap that forgets to
      // update this test.
      expect(
        serviceLocator<PasswordRecoveryGateway>(),
        isA<FakePasswordRecoveryGateway>(),
      );
    });

    test('flips PasswordRecoveryGateway when env carries an anon key', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
      );

      expect(
        serviceLocator<PasswordRecoveryGateway>(),
        isA<SupabasePasswordRecoveryGateway>(),
      );
    });

    test('wires the sign-up gateway to the fake dev implementation', () {
      configureDependencies();

      // Same boundary discipline as the recovery gateway: the dev fake is the
      // registered seam and real sign-up remains a later approved slice.
      expect(serviceLocator<SignUpGateway>(), isA<FakeSignUpGateway>());
    });

    test('wires the attorney gateway to the fake dev implementation', () {
      configureDependencies();

      // D-A2: same boundary discipline as the booking/recovery gateways —
      // the dev fake is the registered seam; a real attorney backend is a
      // later approved data-layer slice.
      expect(serviceLocator<AttorneyGateway>(), isA<FakeAttorneyGateway>());
    });

    test('wires the matter gateway to the fake dev implementation', () {
      configureDependencies();

      // D-M2: same boundary discipline as the discovery/booking gateways —
      // the dev fake is the registered seam; the env-gated real swap (plan
      // T7) only takes over in configured builds.
      expect(serviceLocator<MatterGateway>(), isA<FakeMatterGateway>());
    });

    test('flips MatterGateway when env carries an anon key (plan T7)', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseMatterApiFactory: _FakeSupabaseMatterApi.new,
      );

      expect(serviceLocator<MatterGateway>(), isA<SupabaseMatterGateway>());
    });

    test('wires the matter-write gateway to the fake dev implementation', () {
      configureDependencies();

      // C-D3/C-D5: same boundary discipline as the matter read gateway — the
      // dev fake is the registered seam in env-less runs; the env-gated real
      // swap only takes over in configured builds.
      expect(
        serviceLocator<MatterWriteGateway>(),
        isA<FakeMatterWriteGateway>(),
      );
    });

    test('flips MatterWriteGateway when env carries an anon key (F-01)', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseMatterWriteApiFactory: _FakeSupabaseMatterWriteApi.new,
      );

      expect(
        serviceLocator<MatterWriteGateway>(),
        isA<SupabaseMatterWriteGateway>(),
      );
    });

    test('wires the document gateway to the fake dev implementation', () {
      configureDependencies();

      // D-V2: same boundary discipline as the matter/discovery gateways —
      // the dev fake is the registered seam; the env-gated real swap (plan
      // T7) only takes over in configured builds.
      expect(serviceLocator<DocumentGateway>(), isA<FakeDocumentGateway>());
    });

    test('flips DocumentGateway when env carries an anon key (plan T7)', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseDocumentApiFactory: _FakeSupabaseDocumentApi.new,
      );

      expect(serviceLocator<DocumentGateway>(), isA<SupabaseDocumentGateway>());
    });

    test('wires the message gateway to the fake dev implementation', () {
      configureDependencies();

      // D-MSG2: same boundary discipline as the document/matter gateways —
      // the dev fake is the registered seam; the env-gated real swap (plan
      // T7) only takes over in configured builds.
      expect(serviceLocator<MessageGateway>(), isA<FakeMessageGateway>());
    });

    test('flips MessageGateway when env carries an anon key (plan T7)', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seams instead (the flip's test seam, not production code).
        supabaseMessageApiFactory: _FakeSupabaseMessageApi.new,
        supabaseMessageRealtimeApiFactory: _FakeSupabaseMessageRealtimeApi.new,
      );

      expect(serviceLocator<MessageGateway>(), isA<SupabaseMessageGateway>());
    });

    test('wires the storage gateway to the fake dev implementation', () {
      configureDependencies();

      // D-STR7: same boundary discipline as the message/document gateways —
      // the dev fake is the registered seam; the env-gated real swap (plan
      // T7) only takes over in configured builds.
      expect(serviceLocator<StorageGateway>(), isA<FakeStorageGateway>());
    });

    test('flips StorageGateway when env carries an anon key (plan T7)', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseStorageApiFactory: _FakeSupabaseStorageApi.new,
      );

      expect(serviceLocator<StorageGateway>(), isA<SupabaseStorageGateway>());
    });

    test('wires the billing gateway to the fake dev implementation', () {
      configureDependencies();

      // D-BI5: same boundary discipline as the message/document/storage
      // gateways — the dev fake is the registered seam; the env-gated real
      // swap (plan T7) only takes over in configured builds. D-BI4 — the
      // fake is the product posture, not a stopgap.
      expect(serviceLocator<BillingGateway>(), isA<FakeBillingGateway>());
    });

    test('flips BillingGateway when env carries an anon key (plan T7)', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseBillingApiFactory: _FakeSupabaseBillingApi.new,
      );

      expect(serviceLocator<BillingGateway>(), isA<SupabaseBillingGateway>());
    });

    test('wires the booking gateway to the fake dev implementation', () {
      configureDependencies();

      // F2: same boundary discipline as the recovery/sign-up gateways — the
      // dev fake is the registered seam; a real booking backend is a later
      // approved data-layer slice (data contract deferred).
      expect(serviceLocator<BookingGateway>(), isA<FakeBookingGateway>());
    });

    test('wires the AI research gateway to the synthetic engine over the '
        'shipped seams (D-1/D-2)', () {
      configureDependencies();

      // AI research slice (plan 2026-09-02): D-1 — no model provider, the
      // synthetic gateway IS the product posture; D-2 — the engine composes
      // the two shipped read seams, so it follows their env flip. C-1 — no
      // persistence: no store class is registered for the feature.
      final SyntheticAiGateway ai =
          serviceLocator<AiGateway>() as SyntheticAiGateway;
      expect(ai.documentGateway, same(serviceLocator<DocumentGateway>()));
      expect(ai.matterGateway, same(serviceLocator<MatterGateway>()));
    });

    test('stays on the credential-free fake when no env is injected', () {
      configureDependencies();

      // With no build-time env (tests, env-less runs) the flip keeps the
      // fake. Asserting the concrete type pins the unconfigured default so a
      // future change that flips the default breaks loudly.
      expect(serviceLocator<AuthGateway>(), isA<FakeAuthGateway>());
    });

    test('wires the organization gateway to the fake dev implementation', () {
      configureDependencies();

      // Same boundary discipline as the auth/sign-up fakes: the dev fake is
      // the registered seam until the configured-env flip takes over.
      expect(
        serviceLocator<OrganizationGateway>(),
        isA<FakeOrganizationGateway>(),
      );
    });

    test('flips OrganizationGateway when env carries an anon key', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseOrgApiFactory: _FakeSupabaseOrgApi.new,
      );

      expect(
        serviceLocator<OrganizationGateway>(),
        isA<SupabaseOrganizationGateway>(),
      );
    });

    test('wires the membership repository to the fake dev implementation', () {
      configureDependencies();

      // Same boundary discipline as the organization gateway: the dev fake is
      // the registered seam until the configured-env flip takes over.
      expect(
        serviceLocator<MembershipRepository>(),
        isA<FakeMembershipRepository>(),
      );
    });

    test('binds the fake membership repository to the fake org gateway '
        '(one org state per env-less run, P3.3 Slice B)', () async {
      configureDependencies();

      final FakeOrganizationGateway orgGateway =
          serviceLocator<OrganizationGateway>() as FakeOrganizationGateway;
      await orgGateway.createOrganization(name: 'Second Firm');

      final MembershipRepository repository =
          serviceLocator<MembershipRepository>();
      final MembershipHydrationResult result = await repository.loadMemberships(
        userId: 'demo-user',
      );

      // The org created through the resolved OrganizationGateway appears in
      // the resolved MembershipRepository's hydration — they share one fake
      // instance, so env-less org mutations join the hydrated session.
      expect(result, isA<HydrationSucceeded>());
      final List<OrganizationMembership> memberships =
          (result as HydrationSucceeded).memberships;
      expect(memberships, hasLength(2));
      expect(
        memberships.map((OrganizationMembership m) => m.organizationId),
        <String>['org-demo', 'org-2'],
      );
    });

    test('wires the platform-admin gateway to the fake dev implementation', () {
      configureDependencies();

      // Same boundary discipline as the organization gateway: the dev fake is
      // the registered seam until the configured-env flip takes over.
      expect(
        serviceLocator<PlatformAdminGateway>(),
        isA<FakePlatformAdminGateway>(),
      );
    });

    test('flips PlatformAdminGateway when env carries an anon key', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabasePlatformAdminApiFactory: _FakeSupabasePlatformAdminApi.new,
      );

      expect(
        serviceLocator<PlatformAdminGateway>(),
        isA<SupabasePlatformAdminGateway>(),
      );
    });

    test('resolved platform-admin gateway exposes the audit methods', () async {
      configureDependencies();

      final PlatformAdminGateway admin = serviceLocator<PlatformAdminGateway>();

      // The env-less fake ships the D-AUD5 audit surface (D-AUD3): the
      // platform audit is non-empty for the demo owner and the org audit
      // is scoped to the demo org.
      final OrgOutcome<List<AuditEntry>> platform = await admin
          .readPlatformAudit();
      expect(platform.isSuccess, isTrue);
      expect(platform.valueOrNull, hasLength(5));

      final OrgOutcome<List<AuditEntry>> org = await admin.readOrgAudit(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );
      expect(org.isSuccess, isTrue);
      expect(org.valueOrNull, hasLength(3));
    });

    test('binds the fake platform-admin gateway to the fake org gateway '
        '(one org state per env-less run, P3.5 Slice B)', () async {
      configureDependencies();

      final FakeOrganizationGateway orgGateway =
          serviceLocator<OrganizationGateway>() as FakeOrganizationGateway;
      await orgGateway.createOrganization(name: 'Second Firm');

      final PlatformAdminGateway admin = serviceLocator<PlatformAdminGateway>();
      final OrgOutcome<List<OrganizationSummary>> outcome = await admin
          .listOrganizations();

      // The org created through the resolved OrganizationGateway appears in
      // the resolved platform-admin gateway's listing — they share one fake
      // org instance, so env-less org mutations reach the admin surface.
      expect(outcome.isSuccess, isTrue);
      expect(outcome.valueOrNull, hasLength(2));
      expect(outcome.valueOrNull!.last.name, 'Second Firm');
    });

    test('flips MembershipRepository when env carries an anon key', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseOrgApiFactory: _FakeSupabaseOrgApi.new,
      );

      expect(
        serviceLocator<MembershipRepository>(),
        isA<SupabaseMembershipRepository>(),
      );
    });

    test('resolves OrgSelectionStore and wires ActiveOrgStore to it', () {
      configureDependencies();

      // In unconfigured builds the in-memory fallback is the registered seam
      // (LocaleStore pattern); ActiveOrgStore must resolve through it.
      expect(
        serviceLocator<OrgSelectionStore>(),
        isA<InMemoryOrgSelectionStore>(),
      );
      expect(serviceLocator<ActiveOrgStore>().activeOrganizationId, isNull);
    });

    test('flips to SupabaseAuthGateway when env carries an anon key', () {
      configureDependencies(
        supabaseEnv: SupabaseEnv(
          url: 'https://example.supabase.co',
          anonKey: _anonJwt(),
        ),
        // The real bind() needs a running Supabase.instance; tests inject
        // the seam instead (the flip's test seam, not production code).
        supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
      );

      expect(serviceLocator<AuthGateway>(), isA<SupabaseAuthGateway>());
    });

    test('refuses a non-anon key at configure time (Batch 3.3 guard)', () {
      expect(
        () => configureDependencies(
          supabaseEnv: SupabaseEnv(
            url: 'https://example.supabase.co',
            anonKey: _jwtWithRole('service_role'),
          ),
          supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
        ),
        throwsStateError,
      );

      // Nothing must be wired when the guard refused the key.
      expect(serviceLocator.isRegistered<AuthGateway>(), isFalse);
    });

    test('refuses an undecodable anon-key value at configure time', () {
      expect(
        () => configureDependencies(
          supabaseEnv: SupabaseEnv(
            url: 'https://example.supabase.co',
            anonKey: 'not-a-jwt',
          ),
          supabaseAuthApiFactory: _FakeSupabaseAuthApi.new,
        ),
        throwsStateError,
      );
    });

    test('constructs AuthCubit from the registered gateway and reporter', () {
      configureDependencies();

      final AuthCubit cubit = serviceLocator<AuthCubit>();

      // AuthCubit is app-scoped and observes one session seam. The fake
      // gateway has no session at construction, so the cubit starts
      // unauthenticated (not "initial" — _initialState maps a null session
      // straight to unauthenticated).
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.status, AuthStatus.unauthenticated);
    });

    test('clears every registration on resetServiceLocator', () async {
      configureDependencies();
      expect(serviceLocator.isRegistered<SampleService>(), isTrue);

      await resetServiceLocator();

      expect(serviceLocator.isRegistered<SampleService>(), isFalse);
      expect(serviceLocator.isRegistered<AuthCubit>(), isFalse);
      expect(serviceLocator.isRegistered<LocaleCubit>(), isFalse);
    });
  });
}
