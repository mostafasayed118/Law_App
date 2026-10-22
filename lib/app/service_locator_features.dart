part of 'service_locator.dart';

/// Registers one env-gated gateway seam: the Supabase-backed implementation
/// when the build is configured, the dev fake otherwise (Batch 3.3 env
/// pattern — env-less runs and ALL tests keep the fake). One helper for all
/// flips so a flip-rule change lands in one place instead of N coordinated
/// copy-pasted `if (env.isConfigured)` blocks.
void _registerSeam<T extends Object>(
  SupabaseEnv env, {
  required T Function() supabase,
  required T Function() fake,
}) {
  if (!serviceLocator.isRegistered<T>()) {
    serviceLocator.registerLazySingleton<T>(env.isConfigured ? supabase : fake);
  }
}

void _registerBookingSeams(
  SupabaseEnv env, {
  SupabaseBookingApi Function()? supabaseBookingApiFactory,
}) {
  // Stateless service: lazy singleton. The booking Cubit is feature-scoped
  // and created per screen via BlocProvider, so it is NOT registered here.
  // Like TaskBoardGateway, the flip swaps the dev fake for the Supabase-backed
  // implementation when the build is configured (Batch 3.3 env pattern). The
  // real path reads the RLS-scoped available-slot catalogue and books through
  // the audited `book_consultation` RPC; env-less runs and ALL tests keep the
  // fake.
  _registerSeam<BookingGateway>(
    env,
    supabase: () => SupabaseBookingGateway(
      (supabaseBookingApiFactory ?? SupabaseBookingApiImpl.bind)(),
    ),
    fake: FakeBookingGateway.new,
  );
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
  if (!serviceLocator.isRegistered<ActiveOrgStore>()) {
    // Client-side active-org context (Phase 7 D-M7/D-08; P3.2 D-P32.2):
    // app-scoped, persisted on-device only via OrgSelectionStore (prefs
    // seam, LocaleStore pattern). The org hub seeds/reads it; the server
    // re-derives membership per D-08.
    serviceLocator.registerLazySingleton<ActiveOrgStore>(
      () => ActiveOrgStore(serviceLocator<OrgSelectionStore>()),
    );
  }
}

void _registerMatterSeams(
  SupabaseEnv env, {
  SupabaseMatterApi Function()? supabaseMatterApiFactory,
  SupabaseMatterWriteApi Function()? supabaseMatterWriteApiFactory,
}) {
  // Stateless service: lazy singleton. The matter Cubit is feature-scoped
  // and created per screen via BlocProvider, so it is NOT registered here.
  // Like OrganizationGateway, the flip swaps the dev fake for the
  // Supabase-backed implementation when the build is configured (Batch 3.3
  // env pattern). The real path reads the applied `matters` table through
  // the RLS-scoped SELECT (plan D-MR1/D-MR7) and resolves display names
  // via the roster seam (D-MR4); env-less runs and ALL tests keep the
  // fake.
  _registerSeam<MatterGateway>(
    env,
    supabase: () => SupabaseMatterGateway(
      (supabaseMatterApiFactory ?? SupabaseMatterApiImpl.bind)(),
      serviceLocator<OrganizationGateway>(),
    ),
    fake: FakeMatterGateway.new,
  );
  // Stateless service: lazy singleton. The create cubit is feature-scoped
  // and created per screen via BlocProvider, so it is NOT registered here.
  // F-01 step 2 client swap (C-D5): like MatterGateway, the flip swaps the
  // dev fake for the Supabase-backed implementation when the build is
  // configured (Batch 3.3 env pattern). The real path calls the applied
  // `create_matter` RPC (RPC-EXECUTE 20) — the server re-derives the
  // partner/owner/member gates in-function (F2-D1/D2/D4, F-11); env-less
  // runs and ALL tests keep the fake (C-D3).
  _registerSeam<MatterWriteGateway>(
    env,
    supabase: () => SupabaseMatterWriteGateway(
      (supabaseMatterWriteApiFactory ?? SupabaseMatterWriteApiImpl.bind)(),
    ),
    fake: FakeMatterWriteGateway.new,
  );
}

void _registerDiscoverySeams(
  SupabaseEnv env, {
  SupabaseAttorneyApi Function()? supabaseAttorneyApiFactory,
}) {
  // Stateless services: lazy singletons. The discovery Cubit is feature-scoped
  // and created per screen via BlocProvider. The flip swaps the synthetic fake
  // for the Supabase-backed directory when the build is configured (Batch 3.3
  // env pattern); env-less runs and ALL tests keep the fake. A configured
  // build never serves synthetic rows (design §2: no fake data in configured
  // builds).
  _registerSeam<AttorneyGateway>(
    env,
    supabase: () => SupabaseAttorneyGateway(
      (supabaseAttorneyApiFactory ?? SupabaseAttorneyApiImpl.bind)(),
    ),
    fake: FakeAttorneyGateway.new,
  );
  // The admin write seam: the same Supabase gateway class, with the
  // owner-only audited RPCs; the env-less fake keeps an in-memory list.
  _registerSeam<AttorneyAdminGateway>(
    env,
    supabase: () => SupabaseAttorneyGateway(
      (supabaseAttorneyApiFactory ?? SupabaseAttorneyApiImpl.bind)(),
    ),
    fake: FakeAttorneyAdminGateway.new,
  );
}

/// Registers the approvals slice seams.
void _registerApprovalSeams(
  SupabaseEnv env, {
  SupabaseApprovalApi Function()? supabaseApprovalApiFactory,
}) {
  // Stateless service: lazy singleton. The approvals Cubit is feature-scoped
  // and created per screen via BlocProvider. The flip swaps the in-memory demo
  // for the Supabase-backed workflow when the build is configured (Batch 3.3
  // env pattern); env-less runs and ALL tests keep the fake. The read needs
  // the active organization, resolved lazily through the app-scoped
  // [ActiveOrgStore] so the data layer never imports the app layer.
  _registerSeam<ApprovalsGateway>(
    env,
    supabase: () => SupabaseApprovalGateway(
      (supabaseApprovalApiFactory ?? SupabaseApprovalApiImpl.bind)(),
      organizationId: () =>
          serviceLocator<ActiveOrgStore>().activeOrganizationId,
    ),
    fake: FakeApprovalsGateway.new,
  );
}

/// Registers the compliance slice seams.
void _registerComplianceSeams(
  SupabaseEnv env, {
  SupabaseComplianceApi Function()? supabaseComplianceApiFactory,
}) {
  // Stateless service: lazy singleton. The compliance Cubit is feature-scoped
  // and created per screen via BlocProvider. The flip swaps the in-memory
  // demo for the Supabase-backed alert workflow when the build is configured
  // (Batch 3.3 env pattern); env-less runs and ALL tests keep the fake. The
  // read needs the active organization, resolved lazily through the
  // app-scoped [ActiveOrgStore] so the data layer never imports the app layer.
  _registerSeam<ComplianceAlertsGateway>(
    env,
    supabase: () => SupabaseComplianceGateway(
      (supabaseComplianceApiFactory ?? SupabaseComplianceApiImpl.bind)(),
      organizationId: () =>
          serviceLocator<ActiveOrgStore>().activeOrganizationId,
    ),
    fake: FakeComplianceGateway.new,
  );
}

/// Registers the research slice seams (design §5).
void _registerResearchSeams(
  SupabaseEnv env, {
  SupabaseResearchApi Function()? supabaseResearchApiFactory,
}) {
  // Stateless service: lazy singleton. The research Cubit is feature-scoped
  // and created per screen via BlocProvider. The flip swaps the synthetic demo
  // engine for the Supabase-backed River path when the build is configured
  // (Batch 3.3 env pattern); env-less runs and ALL tests keep the demo engine,
  // which the UI labels as demo mode. A configured build never serves
  // synthetic findings. Reads need the active organization, resolved lazily
  // through the app-scoped [ActiveOrgStore] so the data layer never imports
  // the app layer; the server re-derives membership per request.
  _registerSeam<AiGateway>(
    env,
    supabase: () => SupabaseResearchGateway(
      (supabaseResearchApiFactory ?? SupabaseResearchApiImpl.bind)(),
      organizationId: () =>
          serviceLocator<ActiveOrgStore>().activeOrganizationId,
    ),
    fake: () => SyntheticAiGateway(
      documentGateway: serviceLocator<DocumentGateway>(),
      matterGateway: serviceLocator<MatterGateway>(),
    ),
  );
}

/// Registers the video slice seams (design §6).
void _registerVideoSeams(
  SupabaseEnv env, {
  SupabaseVideoApi Function()? supabaseVideoApiFactory,
}) {
  // Stateless service: lazy singleton. The video Cubit is feature-scoped and
  // created per screen via BlocProvider, so it is NOT registered here. The
  // flip swaps the in-memory demo for the Supabase RPC + `video-token` path
  // when the build is configured (Batch 3.3 env pattern); env-less runs and
  // ALL tests keep the fake, which never fabricates a call. Reads need the
  // active organization, resolved lazily through the app-scoped
  // [ActiveOrgStore] so the data layer never imports the app layer.
  _registerSeam<VideoGateway>(
    env,
    supabase: () => SupabaseVideoGateway(
      (supabaseVideoApiFactory ?? SupabaseVideoApiImpl.bind)(),
      organizationId: () =>
          serviceLocator<ActiveOrgStore>().activeOrganizationId,
    ),
    fake: FakeVideoGateway.new,
  );
}

/// Registers the payments slice seams.
void _registerPaymentSeams(
  SupabaseEnv env, {
  required PaymentMode mode,
  SupabasePaymentApi Function()? supabasePaymentApiFactory,
}) {
  if (!serviceLocator.isRegistered<PaymentMode>()) {
    serviceLocator.registerSingleton<PaymentMode>(mode);
  }
  if (!serviceLocator.isRegistered<PaymentGateway>()) {
    final PaymentMode effectiveMode = serviceLocator<PaymentMode>();
    final bool useSupabase =
        effectiveMode == PaymentMode.live && env.isConfigured;
    serviceLocator.registerLazySingleton<PaymentGateway>(
      useSupabase
          ? () => SupabasePaymentGateway(
              (supabasePaymentApiFactory ?? SupabasePaymentApiImpl.bind)(),
            )
          : FakePaymentGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<CheckoutLauncher>()) {
    serviceLocator.registerLazySingleton<CheckoutLauncher>(
      UrlLauncherCheckoutLauncher.new,
    );
  }
}

void _registerContentSeams(
  SupabaseEnv env, {
  SupabaseDocumentApi Function()? supabaseDocumentApiFactory,
  SupabaseMessageApi Function()? supabaseMessageApiFactory,
  SupabaseMessageRealtimeApi Function()? supabaseMessageRealtimeApiFactory,
  SupabaseStorageApi Function()? supabaseStorageApiFactory,
  SupabaseBillingApi Function()? supabaseBillingApiFactory,
  SupabaseNotificationApi Function()? supabaseNotificationApiFactory,
  SupabaseTaskApi Function()? supabaseTaskApiFactory,
}) {
  // Platform seams are unconditional: the file picker and external URI
  // opener are OS integrations, not env-gated providers. Tests register
  // their own fakes before configureDependencies.
  if (!serviceLocator.isRegistered<FilePicker>()) {
    serviceLocator.registerLazySingleton<FilePicker>(
      FileSelectorFilePicker.new,
    );
  }
  if (!serviceLocator.isRegistered<UriOpener>()) {
    serviceLocator.registerLazySingleton<UriOpener>(UrlLauncherUriOpener.new);
  }
  // Stateless service: lazy singleton. The vault Cubit is feature-scoped
  // and created per screen via BlocProvider, so it is NOT registered here.
  // Like MatterGateway, the flip swaps the dev fake for the
  // Supabase-backed implementation when the build is configured (Batch 3.3
  // env pattern). The real path reads the applied `documents` table through
  // the RLS-scoped SELECT (plan D-DR1/D-DR7) and resolves matterRef via the
  // embedded matters(title) select (D-DR4); env-less runs and ALL tests
  // keep the fake.
  _registerSeam<DocumentGateway>(
    env,
    supabase: () => SupabaseDocumentGateway(
      (supabaseDocumentApiFactory ?? SupabaseDocumentApiImpl.bind)(),
    ),
    fake: FakeDocumentGateway.new,
  );
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
  _registerSeam<MessageGateway>(
    env,
    supabase: () => SupabaseMessageGateway(
      (supabaseMessageApiFactory ?? SupabaseMessageApiImpl.bind)(),
      (supabaseMessageRealtimeApiFactory ??
          SupabaseMessageRealtimeApiImpl.bind)(),
    ),
    fake: FakeMessageGateway.new,
  );
  // Stateless service: lazy singleton. The storage Cubit is feature-scoped
  // and created per section via BlocProvider, so it is NOT registered here.
  // Like MessageGateway, the flip swaps the dev fake for the
  // Supabase-backed implementation when the build is configured (Batch 3.3
  // env pattern). The real path reads the applied `files` table through
  // the RLS-scoped SELECT (plan D-STR1/D-STR7) and resolves matterRef via
  // the embedded matters(title) select (D-STR5); env-less runs and ALL
  // tests keep the fake.
  _registerSeam<StorageGateway>(
    env,
    supabase: () => SupabaseStorageGateway(
      (supabaseStorageApiFactory ?? SupabaseStorageApiImpl.bind)(),
    ),
    fake: FakeStorageGateway.new,
  );
  // Stateless service: lazy singleton. The billing Cubit is feature-scoped
  // and created per section via BlocProvider, so it is NOT registered here.
  // Like StorageGateway, the flip swaps the dev fake for the
  // Supabase-backed implementation when the build is configured (Batch 3.3
  // env pattern). The real path reads the applied `billing_invoices` table
  // through the RLS-scoped SELECT (plan D-BI2/D-BI5) and resolves matterRef
  // via the embedded matters(title) select (D-BI5); env-less runs and ALL
  // tests keep the fake (D-BI4 — the fake is the product posture, not a
  // stopgap).
  _registerSeam<BillingGateway>(
    env,
    supabase: () => SupabaseBillingGateway(
      (supabaseBillingApiFactory ?? SupabaseBillingApiImpl.bind)(),
    ),
    fake: FakeBillingGateway.new,
  );
  // Stateless service: lazy singleton. The notification-feed Cubit is
  // feature-scoped and created per screen via BlocProvider, so it is NOT
  // registered here. Like BillingGateway, the flip swaps the dev fake for
  // the Supabase-backed implementation when the build is configured (Batch
  // 3.3 env pattern). The real path reads the applied `notifications`
  // table through the RLS-scoped SELECT (notification-feed slice, T1 Q2/Q5
  // — `notifications_select_org`, the organizations gate, org-wide
  // metadata); env-less runs and ALL tests keep the fake (D-N7 — the fake
  // is the product posture, not a stopgap).
  _registerSeam<NotificationGateway>(
    env,
    supabase: () => SupabaseNotificationGateway(
      (supabaseNotificationApiFactory ?? SupabaseNotificationApiImpl.bind)(),
    ),
    fake: FakeNotificationGateway.new,
  );
  // Stateless service: lazy singleton. The task-board Cubit is
  // feature-scoped and created per screen via BlocProvider, so it is NOT
  // registered here. Like NotificationGateway, the flip swaps the dev fake
  // for the Supabase-backed implementation when the build is configured
  // (Batch 3.3 env pattern). The real path reads the applied `tasks`
  // table through the RLS-scoped SELECT (`tasks_select_assigned`) and
  // resolves matterRef via the embedded matters(title) select (D-MSR4),
  // and writes through the four audited RPCs (`create_task` /
  // `advance_task_status` / `assign_task` / `acknowledge_task` — Gate 3
  // spec 2026-09-27); env-less runs and ALL tests keep the fake.
  _registerSeam<TaskBoardGateway>(
    env,
    supabase: () => SupabaseTaskGateway(
      (supabaseTaskApiFactory ?? SupabaseTaskApiImpl.bind)(),
    ),
    fake: FakeTaskGateway.new,
  );
}
