import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/admin/platform_admin_gateway.dart';
import '../core/auth/auth_gateway.dart';
import '../core/observability/error_reporter.dart';
import '../core/organizations/membership_repository.dart';
import '../core/organizations/organization_gateway.dart';
import '../core/sample_service.dart';
import '../data/admin/fake_platform_admin_gateway.dart';
import '../data/admin/supabase_platform_admin_api.dart';
import '../data/admin/supabase_platform_admin_api_impl.dart';
import '../data/admin/supabase_platform_admin_gateway.dart';
import '../data/auth/fake_auth_gateway.dart';
import '../data/auth/supabase_auth_api.dart';
import '../data/auth/supabase_auth_api_impl.dart';
import '../data/auth/supabase_auth_gateway.dart';
import '../data/auth/supabase_env.dart';
import '../data/billing/supabase_billing_api.dart';
import '../data/billing/supabase_billing_api_impl.dart';
import '../data/billing/supabase_billing_gateway.dart';
import '../data/documents/supabase_document_api.dart';
import '../data/documents/supabase_document_api_impl.dart';
import '../data/documents/supabase_document_gateway.dart';
import '../data/local/in_memory_locale_store.dart';
import '../data/local/in_memory_org_selection_store.dart';
import '../data/local/locale_store.dart';
import '../data/local/org_selection_store.dart';
import '../data/local/shared_preferences_locale_store.dart';
import '../data/local/shared_preferences_org_selection_store.dart';
import '../data/matters/supabase_matter_api.dart';
import '../data/matters/supabase_matter_api_impl.dart';
import '../data/matters/supabase_matter_gateway.dart';
import '../data/messaging/supabase_message_api.dart';
import '../data/messaging/supabase_message_api_impl.dart';
import '../data/messaging/supabase_message_gateway.dart';
import '../data/messaging/supabase_message_realtime_api.dart';
import '../data/messaging/supabase_message_realtime_api_impl.dart';
import '../data/orgs/fake_membership_repository.dart';
import '../data/orgs/fake_organization_gateway.dart';
import '../data/orgs/supabase_membership_repository.dart';
import '../data/orgs/supabase_org_api.dart';
import '../data/orgs/supabase_org_api_impl.dart';
import '../data/orgs/supabase_organization_gateway.dart';
import '../data/storage/supabase_storage_api.dart';
import '../data/storage/supabase_storage_api_impl.dart';
import '../data/storage/supabase_storage_gateway.dart';
import '../features/approvals/data/fake_approvals_gateway.dart';
import '../features/approvals/domain/approvals_gateway.dart';
import '../features/auth/data/fake_password_recovery_gateway.dart';
import '../features/auth/data/fake_sign_up_gateway.dart';
import '../features/auth/data/supabase_password_recovery_gateway.dart';
import '../features/auth/data/supabase_sign_up_gateway.dart';
import '../features/auth/domain/password_recovery_gateway.dart';
import '../features/auth/domain/sign_up_gateway.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/billing/data/fake_billing_gateway.dart';
import '../features/billing/domain/billing_gateway.dart';
import '../features/booking/data/fake_booking_gateway.dart';
import '../features/booking/domain/booking_gateway.dart';
import '../features/booking/domain/booking_prefill.dart';
import '../features/compliance/data/fake_compliance_gateway.dart';
import '../features/compliance/domain/compliance_gateway.dart';
import '../features/discovery/data/fake_attorney_gateway.dart';
import '../features/discovery/domain/attorney_gateway.dart';
import '../features/documents/data/fake_document_gateway.dart';
import '../features/documents/domain/document_gateway.dart';
import '../features/matters/data/fake_matter_gateway.dart';
import '../features/matters/domain/matter_gateway.dart';
import '../features/messaging/data/fake_message_gateway.dart';
import '../features/messaging/domain/message_gateway.dart';
import '../features/notifications/data/in_memory_notification_prefs_store.dart';
import '../features/notifications/data/shared_preferences_notification_prefs_store.dart';
import '../features/notifications/domain/notification_prefs_store.dart';
import '../features/orgs/presentation/active_org_store.dart';
import '../features/storage/data/fake_storage_gateway.dart';
import '../features/storage/domain/storage_gateway.dart';
import '../features/tasks/data/fake_task_gateway.dart';
import '../features/tasks/domain/task_gateway.dart';
import 'deep_link/pending_accept_invite_store.dart';
import 'localization/locale_cubit.dart';

/// The application's single GetIt service-locator instance.
///
/// Bootstrap spec §4.5 authorizes GetIt as the dependency-injection mechanism.
/// The bootstrap registrations contain only local seams: fake auth, locale
/// persistence, and error reporting. No network, real credentials, or legal
/// data services are registered.
final GetIt serviceLocator = GetIt.instance;

/// Registers all application dependencies.
///
/// Must be called once during application bootstrap (see `main.dart`) before
/// any dependency is resolved. Safe to call again only in tests after
/// [resetServiceLocator] has cleared prior registrations.
///
/// [supabaseEnv] and [supabaseAuthApiFactory] are test seams: when the build
/// injects a configured URL + anon key (Batch 3.3, `--dart-define-from-file`),
/// the real [SupabaseAuthGateway] is registered; otherwise the credential-free
/// [FakeAuthGateway] stays, so tests and env-less local runs keep working.
void configureDependencies({
  SharedPreferences? preferences,
  SupabaseEnv? supabaseEnv,
  SupabaseAuthApi Function()? supabaseAuthApiFactory,
  SupabaseOrgApi Function()? supabaseOrgApiFactory,
  SupabasePlatformAdminApi Function()? supabasePlatformAdminApiFactory,
  SupabaseMatterApi Function()? supabaseMatterApiFactory,
  SupabaseDocumentApi Function()? supabaseDocumentApiFactory,
  SupabaseMessageApi Function()? supabaseMessageApiFactory,
  SupabaseMessageRealtimeApi Function()? supabaseMessageRealtimeApiFactory,
  SupabaseStorageApi Function()? supabaseStorageApiFactory,
  SupabaseBillingApi Function()? supabaseBillingApiFactory,
}) {
  // Lazy singleton: stateless service, created on first resolution.
  // Per §4.5, stateless services/repositories register as lazy singletons.
  // App-scoped Cubits below are also lazy singletons because the router and
  // root MaterialApp must observe the same session and locale instances.
  final SupabaseEnv env = supabaseEnv ?? SupabaseEnv.fromEnvironment();

  // P3.3 Slice B: the unconfigured org fakes share ONE instance so org
  // mutations in env-less runs join the hydrated session (the membership
  // repository derives from the gateway's live roster). Null on the
  // configured path, where the Supabase-backed pair is registered instead.
  FakeOrganizationGateway? fakeOrgGateway;
  if (!serviceLocator.isRegistered<SampleService>()) {
    serviceLocator.registerLazySingleton<SampleService>(SampleServiceImpl.new);
  }
  if (!serviceLocator.isRegistered<AuthGateway>()) {
    if (env.isConfigured) {
      // Batch 3.3 anon-key guard: refuse a non-anon key before wiring any
      // provider, so a service-role key can never reach the client build.
      SupabaseEnv.ensureAnonKey(env.anonKey);
      serviceLocator.registerLazySingleton<AuthGateway>(
        () => SupabaseAuthGateway(
          (supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)(),
        ),
        dispose: (AuthGateway gateway) =>
            (gateway as SupabaseAuthGateway).dispose(),
      );
    } else {
      serviceLocator.registerLazySingleton<AuthGateway>(
        FakeAuthGateway.new,
        dispose: (AuthGateway gateway) =>
            (gateway as FakeAuthGateway).dispose(),
      );
    }
  }
  if (!serviceLocator.isRegistered<ErrorReporter>()) {
    serviceLocator.registerLazySingleton<ErrorReporter>(
      ConsoleErrorReporter.new,
    );
  }
  if (!serviceLocator.isRegistered<LocaleStore>()) {
    serviceLocator.registerLazySingleton<LocaleStore>(
      () => preferences == null
          ? InMemoryLocaleStore()
          : SharedPreferencesLocaleStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<NotificationPrefsStore>()) {
    serviceLocator.registerLazySingleton<NotificationPrefsStore>(
      () => preferences == null
          ? InMemoryNotificationPrefsStore()
          : SharedPreferencesNotificationPrefsStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<OrgSelectionStore>()) {
    // Device-local active-org selection (P3.2 D-P32.2): the LocaleStore
    // pattern — SharedPreferences when available, in-memory otherwise.
    serviceLocator.registerLazySingleton<OrgSelectionStore>(
      () => preferences == null
          ? InMemoryOrgSelectionStore()
          : SharedPreferencesOrgSelectionStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<LocaleCubit>()) {
    // App-scoped because MaterialApp and routing share the selected locale.
    serviceLocator.registerLazySingleton<LocaleCubit>(
      () => LocaleCubit(serviceLocator<LocaleStore>()),
      dispose: (LocaleCubit cubit) => cubit.close(),
    );
  }
  if (!serviceLocator.isRegistered<PasswordRecoveryGateway>()) {
    // Stateless service: lazy singleton. The recovery Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Like AuthGateway/SignUpGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). Code-based recovery needs no deep links (2026-08-03).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<PasswordRecoveryGateway>(
        () => SupabasePasswordRecoveryGateway(
          (supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<PasswordRecoveryGateway>(
        FakePasswordRecoveryGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<SignUpGateway>()) {
    // Stateless service: lazy singleton. The sign-up Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Like AuthGateway, the flip swaps the dev fake for the Supabase-backed
    // implementation when the build is configured (Batch 3.3 env pattern).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<SignUpGateway>(
        () => SupabaseSignUpGateway(
          (supabaseAuthApiFactory ?? SupabaseAuthApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<SignUpGateway>(
        FakeSignUpGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<OrganizationGateway>()) {
    // Like AuthGateway, the flip swaps the dev fake for the Supabase-backed
    // implementation when the build is configured (Batch 3.3 env pattern).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<OrganizationGateway>(
        () => SupabaseOrganizationGateway(
          (supabaseOrgApiFactory ?? SupabaseOrgApiImpl.bind)(),
        ),
      );
    } else {
      // P3.3 Slice B: keep a handle on the fake so the unconfigured
      // membership repository below can bind to the same instance.
      fakeOrgGateway = FakeOrganizationGateway();
      serviceLocator.registerLazySingleton<OrganizationGateway>(
        () => fakeOrgGateway!,
      );
    }
  }
  if (!serviceLocator.isRegistered<MembershipRepository>()) {
    // Like OrganizationGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). P3.2 membership hydration reads the RLS-scoped SELECT
    // surface; the fake mirrors the demo session's membership.
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<MembershipRepository>(
        () => SupabaseMembershipRepository(
          (supabaseOrgApiFactory ?? SupabaseOrgApiImpl.bind)(),
        ),
      );
    } else {
      // P3.3 Slice B: derive from the SAME fake org gateway instance the
      // unconfigured OrganizationGateway resolves to, so orgs created in an
      // env-less run join the hydrated session (D-P33.2). `fakeOrgGateway`
      // is non-null exactly on this unconfigured path.
      serviceLocator.registerLazySingleton<MembershipRepository>(
        () => FakeMembershipRepository(organizationGateway: fakeOrgGateway),
      );
    }
  }
  if (!serviceLocator.isRegistered<PlatformAdminGateway>()) {
    // Like OrganizationGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). P3.5 platform-admin consumes the owner-only metadata
    // RPCs; the fake mirrors the owner gate server-side (denied, never
    // empty-success) and derives state from the SAME fake org gateway
    // instance below (D-P33.2), so env-less org mutations appear in the
    // admin lists.
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<PlatformAdminGateway>(
        () => SupabasePlatformAdminGateway(
          (supabasePlatformAdminApiFactory ??
              SupabasePlatformAdminApiImpl.bind)(),
        ),
      );
    } else {
      // `fakeOrgGateway` is non-null exactly on this unconfigured path (set
      // by the OrganizationGateway registration above), so the admin fake
      // shares the same org state instance.
      serviceLocator.registerLazySingleton<PlatformAdminGateway>(
        () => FakePlatformAdminGateway(organizationGateway: fakeOrgGateway),
      );
    }
  }
  if (!serviceLocator.isRegistered<BookingGateway>()) {
    // Stateless service: lazy singleton. The booking Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    serviceLocator.registerLazySingleton<BookingGateway>(
      FakeBookingGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<PendingAcceptInviteStore>()) {
    // Transient app-scoped holder (Phase 4.1 D-P34.2): buffers a
    // deep-linked one-time accept token until the accept screen consumes it
    // (cold-start / signed-out arrivals). BookingPrefill precedent — never
    // serialized, consumed-and-cleared.
    serviceLocator.registerLazySingleton<PendingAcceptInviteStore>(
      PendingAcceptInviteStore.new,
    );
  }
  if (!serviceLocator.isRegistered<BookingPrefill>()) {
    // Transient prefill holder (Phase 6 D-A3): app-scoped, in-memory only;
    // consumed and cleared by BookingScreen at cubit creation. Never
    // serialized; nothing booking-related travels in route params or
    // GoRouter extra (D-B4).
    serviceLocator.registerLazySingleton<BookingPrefill>(BookingPrefill.new);
  }
  if (!serviceLocator.isRegistered<AttorneyGateway>()) {
    // Stateless service: lazy singleton. The discovery Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Fake-domain (D-A2): a real attorney backend is a later approved
    // data-layer slice.
    serviceLocator.registerLazySingleton<AttorneyGateway>(
      FakeAttorneyGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<ActiveOrgStore>()) {
    // Client-side active-org context (Phase 7 D-M7/D-08; P3.2 D-P32.2):
    // app-scoped, persisted on-device only via OrgSelectionStore (prefs
    // seam, LocaleStore pattern). The org hub seeds/reads it; the server
    // re-derives membership per D-08.
    serviceLocator.registerLazySingleton<ActiveOrgStore>(
      () => ActiveOrgStore(serviceLocator<OrgSelectionStore>()),
    );
  }
  if (!serviceLocator.isRegistered<MatterGateway>()) {
    // Stateless service: lazy singleton. The matter Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Like OrganizationGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). The real path reads the applied `matters` table through
    // the RLS-scoped SELECT (plan D-MR1/D-MR7) and resolves display names
    // via the roster seam (D-MR4); env-less runs and ALL tests keep the
    // fake.
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<MatterGateway>(
        () => SupabaseMatterGateway(
          (supabaseMatterApiFactory ?? SupabaseMatterApiImpl.bind)(),
          serviceLocator<OrganizationGateway>(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<MatterGateway>(
        FakeMatterGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<DocumentGateway>()) {
    // Stateless service: lazy singleton. The vault Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Like MatterGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). The real path reads the applied `documents` table through
    // the RLS-scoped SELECT (plan D-DR1/D-DR7) and resolves matterRef via the
    // embedded matters(title) select (D-DR4); env-less runs and ALL tests
    // keep the fake.
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<DocumentGateway>(
        () => SupabaseDocumentGateway(
          (supabaseDocumentApiFactory ?? SupabaseDocumentApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<DocumentGateway>(
        FakeDocumentGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<MessageGateway>()) {
    // Stateless service: lazy singleton. The messaging Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // Like DocumentGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). The real path reads the applied `message_threads` +
    // `messages` tables through the RLS-scoped SELECTs (plan D-MSR1/D-MSR7/
    // D-RT5) and resolves matterRef via the embedded matters(title) select
    // (D-MSR4); the send path (D-LV1) resolves the thread's org under the
    // same gate and inserts, and the live path (D-LV4) binds the
    // postgres_changes subscription; env-less runs and ALL tests keep the
    // fake.
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<MessageGateway>(
        () => SupabaseMessageGateway(
          (supabaseMessageApiFactory ?? SupabaseMessageApiImpl.bind)(),
          (supabaseMessageRealtimeApiFactory ??
              SupabaseMessageRealtimeApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<MessageGateway>(
        FakeMessageGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<StorageGateway>()) {
    // Stateless service: lazy singleton. The storage Cubit is feature-scoped
    // and created per section via BlocProvider, so it is NOT registered here.
    // Like MessageGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). The real path reads the applied `files` table through
    // the RLS-scoped SELECT (plan D-STR1/D-STR7) and resolves matterRef via
    // the embedded matters(title) select (D-STR5); env-less runs and ALL
    // tests keep the fake.
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<StorageGateway>(
        () => SupabaseStorageGateway(
          (supabaseStorageApiFactory ?? SupabaseStorageApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<StorageGateway>(
        FakeStorageGateway.new,
      );
    }
  }
  if (!serviceLocator.isRegistered<BillingGateway>()) {
    // Stateless service: lazy singleton. The billing Cubit is feature-scoped
    // and created per section via BlocProvider, so it is NOT registered here.
    // Like StorageGateway, the flip swaps the dev fake for the
    // Supabase-backed implementation when the build is configured (Batch 3.3
    // env pattern). The real path reads the applied `billing_invoices` table
    // through the RLS-scoped SELECT (plan D-BI2/D-BI5) and resolves matterRef
    // via the embedded matters(title) select (D-BI5); env-less runs and ALL
    // tests keep the fake (D-BI4 — the fake is the product posture, not a
    // stopgap).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<BillingGateway>(
        () => SupabaseBillingGateway(
          (supabaseBillingApiFactory ?? SupabaseBillingApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<BillingGateway>(
        FakeBillingGateway.new,
      );
    }
  }
if (!serviceLocator.isRegistered<AuthCubit>()) {
    // App-scoped because the router and all screens observe one session seam.
    serviceLocator.registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        serviceLocator<AuthGateway>(),
        serviceLocator<ErrorReporter>(),
        serviceLocator<MembershipRepository>(),
      ),
      dispose: (AuthCubit cubit) => cubit.close(),
    );
  }
  // v1 queue (2026-08-09 scope drafts): read-only demo surfaces behind dev
  // fakes only — no server surface exists yet, so there is no env flip (the
  // Phase 5–12 fake-domain pattern, "the fake is the product posture").
  if (!serviceLocator.isRegistered<ComplianceAlertsGateway>()) {
    serviceLocator.registerLazySingleton<ComplianceAlertsGateway>(
      FakeComplianceGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<TaskBoardGateway>()) {
    serviceLocator.registerLazySingleton<TaskBoardGateway>(
      FakeTaskGateway.new,
    );
  }
if (!serviceLocator.isRegistered<ApprovalsGateway>()) {
    serviceLocator.registerLazySingleton<ApprovalsGateway>(
      FakeApprovalsGateway.new,
    );
  }
}

/// Clears all registrations. Intended for tests that need a clean locator.
Future<void> resetServiceLocator() async {
  await serviceLocator.reset();
}
