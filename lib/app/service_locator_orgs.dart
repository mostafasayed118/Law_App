part of 'service_locator.dart';

void _registerOrgSeams(
  SupabaseEnv env, {
  SupabaseOrgApi Function()? supabaseOrgApiFactory,
  SupabasePlatformAdminApi Function()? supabasePlatformAdminApiFactory,
}) {
  // P3.3 Slice B: the unconfigured org fakes share ONE instance so org
  // mutations in env-less runs join the hydrated session (the membership
  // repository derives from the gateway's live roster). Null on the
  // configured path, where the Supabase-backed pair is registered instead.
  FakeOrganizationGateway? fakeOrgGateway;
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
}
