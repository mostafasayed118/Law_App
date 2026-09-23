part of 'service_locator.dart';

void _registerBookingSeams() {
  if (!serviceLocator.isRegistered<BookingGateway>()) {
    // Stateless service: lazy singleton. The booking Cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    serviceLocator.registerLazySingleton<BookingGateway>(
      FakeBookingGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<VideoGateway>()) {
    // Spec D-15 demo-posture (`docs/video_scope_decision_2026-08-11.md`):
    // the synthetic VideoGateway seam, registered unconditionally — there is
    // no env flip because there is no server-side video table to flip to;
    // the fake IS the product posture for the demo (C-1), with zero media
    // and zero writes anywhere downstream (C-2/C-3). Stateless service:
    // lazy singleton; the video Cubit is feature-scoped and created per
    // screen via BlocProvider, so it is NOT registered here. Sits beside
    // the booking seam (A-2: "book" → "join call").
    serviceLocator.registerLazySingleton<VideoGateway>(FakeVideoGateway.new);
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
}

void _registerMatterSeams(
  SupabaseEnv env, {
  SupabaseMatterApi Function()? supabaseMatterApiFactory,
  SupabaseMatterWriteApi Function()? supabaseMatterWriteApiFactory,
}) {
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
  if (!serviceLocator.isRegistered<MatterWriteGateway>()) {
    // Stateless service: lazy singleton. The create cubit is feature-scoped
    // and created per screen via BlocProvider, so it is NOT registered here.
    // F-01 step 2 client swap (C-D5): like MatterGateway, the flip swaps the
    // dev fake for the Supabase-backed implementation when the build is
    // configured (Batch 3.3 env pattern). The real path calls the applied
    // `create_matter` RPC (RPC-EXECUTE 20) — the server re-derives the
    // partner/owner/member gates in-function (F2-D1/D2/D4, F-11); env-less
    // runs and ALL tests keep the fake (C-D3).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<MatterWriteGateway>(
        () => SupabaseMatterWriteGateway(
          (supabaseMatterWriteApiFactory ?? SupabaseMatterWriteApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<MatterWriteGateway>(
        FakeMatterWriteGateway.new,
      );
    }
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
}) {
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
  if (!serviceLocator.isRegistered<NotificationGateway>()) {
    // Stateless service: lazy singleton. The notification-feed Cubit is
    // feature-scoped and created per screen via BlocProvider, so it is NOT
    // registered here. Like BillingGateway, the flip swaps the dev fake for
    // the Supabase-backed implementation when the build is configured (Batch
    // 3.3 env pattern). The real path reads the applied `notifications`
    // table through the RLS-scoped SELECT (notification-feed slice, T1 Q2/Q5
    // — `notifications_select_org`, the organizations gate, org-wide
    // metadata); env-less runs and ALL tests keep the fake (D-N7 — the fake
    // is the product posture, not a stopgap).
    if (env.isConfigured) {
      serviceLocator.registerLazySingleton<NotificationGateway>(
        () => SupabaseNotificationGateway(
          (supabaseNotificationApiFactory ??
              SupabaseNotificationApiImpl.bind)(),
        ),
      );
    } else {
      serviceLocator.registerLazySingleton<NotificationGateway>(
        FakeNotificationGateway.new,
      );
    }
  }
}
