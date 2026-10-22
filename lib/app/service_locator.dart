import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/admin/platform_admin_gateway.dart';
import '../core/auth/auth_gateway.dart';
import '../core/backend_posture.dart';
import '../core/observability/error_reporter.dart';
import '../core/organizations/membership_repository.dart';
import '../core/organizations/organization_gateway.dart';
import '../core/sample_service.dart';
import '../data/admin/fake_platform_admin_gateway.dart';
import '../data/admin/supabase_platform_admin_api.dart';
import '../data/admin/supabase_platform_admin_api_impl.dart';
import '../data/admin/supabase_platform_admin_gateway.dart';
import '../data/approvals/supabase_approval_api.dart';
import '../data/approvals/supabase_approval_api_impl.dart';
import '../data/approvals/supabase_approval_gateway.dart';
import '../data/auth/fake_auth_gateway.dart';
import '../data/auth/supabase_auth_api.dart';
import '../data/auth/supabase_auth_api_impl.dart';
import '../data/auth/supabase_auth_gateway.dart';
import '../data/auth/supabase_env.dart';
import '../data/billing/fake_payment_gateway.dart';
import '../data/billing/supabase_billing_api.dart';
import '../data/billing/supabase_billing_api_impl.dart';
import '../data/billing/supabase_billing_gateway.dart';
import '../data/billing/supabase_payment_api.dart';
import '../data/billing/supabase_payment_api_impl.dart';
import '../data/billing/supabase_payment_gateway.dart';
import '../data/billing/url_launcher_checkout_launcher.dart';
import '../data/booking/supabase_booking_api.dart';
import '../data/booking/supabase_booking_api_impl.dart';
import '../data/booking/supabase_booking_gateway.dart';
import '../data/compliance/supabase_compliance_api.dart';
import '../data/compliance/supabase_compliance_api_impl.dart';
import '../data/compliance/supabase_compliance_gateway.dart';
import '../data/discovery/supabase_attorney_api.dart';
import '../data/discovery/supabase_attorney_api_impl.dart';
import '../data/discovery/supabase_attorney_gateway.dart';
import '../data/documents/supabase_document_api.dart';
import '../data/documents/supabase_document_api_impl.dart';
import '../data/documents/supabase_document_gateway.dart';
import '../data/files/file_selector_file_picker.dart';
import '../data/files/url_launcher_uri_opener.dart';
import '../data/local/in_memory_locale_store.dart';
import '../data/local/in_memory_onboarding_store.dart';
import '../data/local/in_memory_org_selection_store.dart';
import '../data/local/in_memory_theme_mode_store.dart';
import '../data/local/locale_store.dart';
import '../data/local/onboarding_store.dart';
import '../data/local/org_selection_store.dart';
import '../data/local/shared_preferences_locale_store.dart';
import '../data/local/shared_preferences_onboarding_store.dart';
import '../data/local/shared_preferences_org_selection_store.dart';
import '../data/local/shared_preferences_theme_mode_store.dart';
import '../data/local/theme_mode_store.dart';
import '../data/matters/supabase_matter_api.dart';
import '../data/matters/supabase_matter_api_impl.dart';
import '../data/matters/supabase_matter_gateway.dart';
import '../data/matters/supabase_matter_write_api.dart';
import '../data/matters/supabase_matter_write_api_impl.dart';
import '../data/matters/supabase_matter_write_gateway.dart';
import '../data/messaging/supabase_message_api.dart';
import '../data/messaging/supabase_message_api_impl.dart';
import '../data/messaging/supabase_message_gateway.dart';
import '../data/messaging/supabase_message_realtime_api.dart';
import '../data/messaging/supabase_message_realtime_api_impl.dart';
import '../data/notifications/supabase_notification_api.dart';
import '../data/notifications/supabase_notification_api_impl.dart';
import '../data/notifications/supabase_notification_gateway.dart';
import '../data/orgs/fake_membership_repository.dart';
import '../data/orgs/fake_organization_gateway.dart';
import '../data/orgs/supabase_membership_repository.dart';
import '../data/orgs/supabase_org_api.dart';
import '../data/orgs/supabase_org_api_impl.dart';
import '../data/orgs/supabase_organization_gateway.dart';
import '../data/research/supabase_research_api.dart';
import '../data/research/supabase_research_api_impl.dart';
import '../data/research/supabase_research_gateway.dart';
import '../data/storage/supabase_storage_api.dart';
import '../data/storage/supabase_storage_api_impl.dart';
import '../data/storage/supabase_storage_gateway.dart';
import '../data/tasks/supabase_task_api.dart';
import '../data/tasks/supabase_task_api_impl.dart';
import '../data/tasks/supabase_task_gateway.dart';
import '../data/video/supabase_video_api.dart';
import '../data/video/supabase_video_api_impl.dart';
import '../data/video/supabase_video_gateway.dart';
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
import '../features/billing/domain/checkout_launcher.dart';
import '../features/billing/domain/payment_gateway.dart';
import '../features/billing/domain/payment_mode.dart';
import '../features/booking/data/fake_booking_gateway.dart';
import '../features/booking/domain/booking_gateway.dart';
import '../features/booking/domain/booking_prefill.dart';
import '../features/compliance/data/fake_compliance_gateway.dart';
import '../features/compliance/domain/compliance_gateway.dart';
import '../features/discovery/data/fake_attorney_admin_gateway.dart';
import '../features/discovery/data/fake_attorney_gateway.dart';
import '../features/discovery/domain/attorney_admin_gateway.dart';
import '../features/discovery/domain/attorney_gateway.dart';
import '../features/documents/data/fake_document_gateway.dart';
import '../features/documents/domain/document_gateway.dart';
import '../features/matters/data/fake_matter_gateway.dart';
import '../features/matters/data/fake_matter_write_gateway.dart';
import '../features/matters/domain/matter_gateway.dart';
import '../features/matters/domain/matter_write_gateway.dart';
import '../features/messaging/data/fake_message_gateway.dart';
import '../features/messaging/domain/message_gateway.dart';
import '../features/notifications/data/fake_notification_gateway.dart';
import '../features/notifications/data/in_memory_notification_prefs_store.dart';
import '../features/notifications/data/shared_preferences_notification_prefs_store.dart';
import '../features/notifications/domain/notification_gateway.dart';
import '../features/notifications/domain/notification_prefs_store.dart';
import '../features/research/data/synthetic_ai_gateway.dart';
import '../features/research/domain/ai_gateway.dart';
import '../features/storage/data/fake_storage_gateway.dart';
import '../features/storage/domain/file_picker.dart';
import '../features/storage/domain/storage_gateway.dart';
import '../features/storage/domain/uri_opener.dart';
import '../features/tasks/data/fake_task_gateway.dart';
import '../features/tasks/domain/task_gateway.dart';
import '../features/video/data/fake_video_gateway.dart';
import '../features/video/domain/video_gateway.dart';
import 'active_org_store.dart';
import 'deep_link/pending_accept_invite_store.dart';
import 'localization/locale_cubit.dart';
import 'theme/theme_cubit.dart';
part 'service_locator_core.dart';
part 'service_locator_auth.dart';
part 'service_locator_orgs.dart';
part 'service_locator_features.dart';
part 'service_locator_app.dart';

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
  SupabaseMatterWriteApi Function()? supabaseMatterWriteApiFactory,
  SupabaseDocumentApi Function()? supabaseDocumentApiFactory,
  SupabaseMessageApi Function()? supabaseMessageApiFactory,
  SupabaseMessageRealtimeApi Function()? supabaseMessageRealtimeApiFactory,
  SupabaseStorageApi Function()? supabaseStorageApiFactory,
  SupabaseBillingApi Function()? supabaseBillingApiFactory,
  SupabasePaymentApi Function()? supabasePaymentApiFactory,
  SupabaseNotificationApi Function()? supabaseNotificationApiFactory,
  SupabaseTaskApi Function()? supabaseTaskApiFactory,
  SupabaseBookingApi Function()? supabaseBookingApiFactory,
  SupabaseAttorneyApi Function()? supabaseAttorneyApiFactory,
  SupabaseApprovalApi Function()? supabaseApprovalApiFactory,
  SupabaseComplianceApi Function()? supabaseComplianceApiFactory,
  SupabaseResearchApi Function()? supabaseResearchApiFactory,
  SupabaseVideoApi Function()? supabaseVideoApiFactory,
  PaymentMode? paymentMode,
}) {
  // Lazy singleton: stateless service, created on first resolution.
  // Per §4.5, stateless services/repositories register as lazy singletons.
  // App-scoped Cubits below are also lazy singletons because the router and
  // root MaterialApp must observe the same session and locale instances.
  final SupabaseEnv env = supabaseEnv ?? SupabaseEnv.fromEnvironment();
  final PaymentMode paymentsMode = paymentMode ?? PaymentMode.fromEnvironment();

  if (!serviceLocator.isRegistered<BackendPosture>()) {
    serviceLocator.registerSingleton<BackendPosture>(
      BackendPosture(isLocalOnly: !env.isConfigured),
    );
  }

  _registerCoreServices(preferences: preferences);
  _registerAuthSeams(env, supabaseAuthApiFactory: supabaseAuthApiFactory);
  _registerOrgSeams(
    env,
    supabaseOrgApiFactory: supabaseOrgApiFactory,
    supabasePlatformAdminApiFactory: supabasePlatformAdminApiFactory,
  );
  _registerBookingSeams(
    env,
    supabaseBookingApiFactory: supabaseBookingApiFactory,
  );
  _registerDiscoverySeams(
    env,
    supabaseAttorneyApiFactory: supabaseAttorneyApiFactory,
  );
  _registerApprovalSeams(
    env,
    supabaseApprovalApiFactory: supabaseApprovalApiFactory,
  );
  _registerComplianceSeams(
    env,
    supabaseComplianceApiFactory: supabaseComplianceApiFactory,
  );
  _registerResearchSeams(
    env,
    supabaseResearchApiFactory: supabaseResearchApiFactory,
  );
  _registerVideoSeams(env, supabaseVideoApiFactory: supabaseVideoApiFactory);
  _registerMatterSeams(
    env,
    supabaseMatterApiFactory: supabaseMatterApiFactory,
    supabaseMatterWriteApiFactory: supabaseMatterWriteApiFactory,
  );
  _registerContentSeams(
    env,
    supabaseDocumentApiFactory: supabaseDocumentApiFactory,
    supabaseMessageApiFactory: supabaseMessageApiFactory,
    supabaseMessageRealtimeApiFactory: supabaseMessageRealtimeApiFactory,
    supabaseStorageApiFactory: supabaseStorageApiFactory,
    supabaseBillingApiFactory: supabaseBillingApiFactory,
    supabaseNotificationApiFactory: supabaseNotificationApiFactory,
    supabaseTaskApiFactory: supabaseTaskApiFactory,
  );
  _registerPaymentSeams(
    env,
    mode: paymentsMode,
    supabasePaymentApiFactory: supabasePaymentApiFactory,
  );
  _registerAppCubits();
  _registerDemoGateways();
}

/// Clears all registrations. Intended for tests that need a clean locator.
Future<void> resetServiceLocator() async {
  await serviceLocator.reset();
}

/// Presentation-level posture: true when the app is on the credential-free
/// fakes. A screen pumped without [configureDependencies] keeps the historical
/// local-only copy rather than throwing on a missing registration.
bool get backendIsLocalOnly => serviceLocator.isRegistered<BackendPosture>()
    ? serviceLocator<BackendPosture>().isLocalOnly
    : true;
