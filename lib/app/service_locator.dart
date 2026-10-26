import 'package:get_it/get_it.dart';
import 'package:legalhub/core/admin/platform_admin_gateway.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/backend_posture.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/data/admin/fake_platform_admin_gateway.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_api.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_api_impl.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_gateway.dart';
import 'package:legalhub/data/approvals/supabase_approval_api.dart';
import 'package:legalhub/data/approvals/supabase_approval_api_impl.dart';
import 'package:legalhub/data/approvals/supabase_approval_gateway.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_auth_api.dart';
import 'package:legalhub/data/auth/supabase_auth_api_impl.dart';
import 'package:legalhub/data/auth/supabase_auth_gateway.dart';
import 'package:legalhub/data/auth/supabase_env.dart';
import 'package:legalhub/data/billing/fake_payment_gateway.dart';
import 'package:legalhub/data/billing/supabase_billing_api.dart';
import 'package:legalhub/data/billing/supabase_billing_api_impl.dart';
import 'package:legalhub/data/billing/supabase_billing_gateway.dart';
import 'package:legalhub/data/billing/supabase_payment_api.dart';
import 'package:legalhub/data/billing/supabase_payment_api_impl.dart';
import 'package:legalhub/data/billing/supabase_payment_gateway.dart';
import 'package:legalhub/data/billing/url_launcher_checkout_launcher.dart';
import 'package:legalhub/data/booking/supabase_booking_api.dart';
import 'package:legalhub/data/booking/supabase_booking_api_impl.dart';
import 'package:legalhub/data/booking/supabase_booking_gateway.dart';
import 'package:legalhub/data/compliance/supabase_compliance_api.dart';
import 'package:legalhub/data/compliance/supabase_compliance_api_impl.dart';
import 'package:legalhub/data/compliance/supabase_compliance_gateway.dart';
import 'package:legalhub/data/discovery/supabase_attorney_api.dart';
import 'package:legalhub/data/discovery/supabase_attorney_api_impl.dart';
import 'package:legalhub/data/discovery/supabase_attorney_gateway.dart';
import 'package:legalhub/data/documents/supabase_document_api.dart';
import 'package:legalhub/data/documents/supabase_document_api_impl.dart';
import 'package:legalhub/data/documents/supabase_document_gateway.dart';
import 'package:legalhub/data/files/file_selector_file_picker.dart';
import 'package:legalhub/data/files/url_launcher_uri_opener.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/local/in_memory_onboarding_store.dart';
import 'package:legalhub/data/local/in_memory_org_selection_store.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/local/locale_store.dart';
import 'package:legalhub/data/local/onboarding_store.dart';
import 'package:legalhub/data/local/org_selection_store.dart';
import 'package:legalhub/data/local/shared_preferences_locale_store.dart';
import 'package:legalhub/data/local/shared_preferences_onboarding_store.dart';
import 'package:legalhub/data/local/shared_preferences_org_selection_store.dart';
import 'package:legalhub/data/local/shared_preferences_theme_mode_store.dart';
import 'package:legalhub/data/local/theme_mode_store.dart';
import 'package:legalhub/data/matters/supabase_matter_api.dart';
import 'package:legalhub/data/matters/supabase_matter_api_impl.dart';
import 'package:legalhub/data/matters/supabase_matter_gateway.dart';
import 'package:legalhub/data/matters/supabase_matter_write_api.dart';
import 'package:legalhub/data/matters/supabase_matter_write_api_impl.dart';
import 'package:legalhub/data/matters/supabase_matter_write_gateway.dart';
import 'package:legalhub/data/messaging/supabase_message_api.dart';
import 'package:legalhub/data/messaging/supabase_message_api_impl.dart';
import 'package:legalhub/data/messaging/supabase_message_gateway.dart';
import 'package:legalhub/data/messaging/supabase_message_realtime_api.dart';
import 'package:legalhub/data/messaging/supabase_message_realtime_api_impl.dart';
import 'package:legalhub/data/notifications/supabase_notification_api.dart';
import 'package:legalhub/data/notifications/supabase_notification_api_impl.dart';
import 'package:legalhub/data/notifications/supabase_notification_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/data/orgs/supabase_membership_repository.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:legalhub/data/orgs/supabase_org_api_impl.dart';
import 'package:legalhub/data/orgs/supabase_organization_gateway.dart';
import 'package:legalhub/data/research/supabase_research_api.dart';
import 'package:legalhub/data/research/supabase_research_api_impl.dart';
import 'package:legalhub/data/research/supabase_research_gateway.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_api_impl.dart';
import 'package:legalhub/data/storage/supabase_storage_gateway.dart';
import 'package:legalhub/data/tasks/supabase_task_api.dart';
import 'package:legalhub/data/tasks/supabase_task_api_impl.dart';
import 'package:legalhub/data/tasks/supabase_task_gateway.dart';
import 'package:legalhub/data/video/supabase_video_api.dart';
import 'package:legalhub/data/video/supabase_video_api_impl.dart';
import 'package:legalhub/data/video/supabase_video_gateway.dart';
import 'package:legalhub/features/approvals/data/fake_approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/auth/data/fake_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/data/fake_sign_up_gateway.dart';
import 'package:legalhub/features/auth/data/supabase_password_recovery_gateway.dart';
import 'package:legalhub/features/auth/data/supabase_sign_up_gateway.dart';
import 'package:legalhub/features/auth/domain/password_recovery_gateway.dart';
import 'package:legalhub/features/auth/domain/sign_up_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/billing/data/fake_billing_gateway.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';
import 'package:legalhub/features/booking/data/fake_booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_prefill.dart';
import 'package:legalhub/features/compliance/data/fake_compliance_gateway.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/discovery/data/fake_attorney_admin_gateway.dart';
import 'package:legalhub/features/discovery/data/fake_attorney_gateway.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_write_gateway.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter_write_gateway.dart';
import 'package:legalhub/features/messaging/data/fake_message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/notifications/data/fake_notification_gateway.dart';
import 'package:legalhub/features/notifications/data/in_memory_notification_prefs_store.dart';
import 'package:legalhub/features/notifications/data/shared_preferences_notification_prefs_store.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs_store.dart';
import 'package:legalhub/features/research/data/synthetic_ai_gateway.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/storage/data/fake_storage_gateway.dart';
import 'package:legalhub/features/storage/domain/file_picker.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'package:legalhub/features/storage/domain/uri_opener.dart';
import 'package:legalhub/features/tasks/data/fake_task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/video/data/fake_video_gateway.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_org_store.dart';
import 'deep_link/pending_accept_invite_store.dart';
import 'localization/locale_cubit.dart';
import 'theme/theme_cubit.dart';

part 'service_locator_app.dart';
part 'service_locator_auth.dart';
part 'service_locator_core.dart';
part 'service_locator_features.dart';
part 'service_locator_orgs.dart';

/// The application's single GetIt service-locator instance.
///
/// Bootstrap spec §4.5 authorizes GetIt as the dependency-injection mechanism.
/// Device-local seams and app-scoped state (locales, onboarding, notification
/// prefs, org selection, theme, error reporting) are always registered; the
/// network-backed gateways are env-gated and only replace their credential-free
/// fakes when the build injects a Supabase environment.
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
