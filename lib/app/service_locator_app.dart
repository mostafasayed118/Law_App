part of 'service_locator.dart';

void _registerAppCubits() {
  if (!serviceLocator.isRegistered<AuthCubit>()) {
    // App-scoped because the router and all screens observe one session seam.
    serviceLocator.registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        serviceLocator<AuthGateway>(),
        serviceLocator<ErrorReporter>(),
        serviceLocator<MembershipRepository>(),
        serviceLocator<OrganizationGateway>(),
      ),
      dispose: (AuthCubit cubit) => cubit.close(),
    );
  }
}

void _registerDemoGateways() {
  // v1 queue (2026-08-09 scope drafts): read-only demo surfaces behind dev
  // fakes only — no server surface exists yet, so there is no env flip (the
  // Phase 5–12 fake-domain pattern, "the fake is the product posture"). The
  // task board LEFT this group in the task-writes slice (Gate 3 spec
  // 2026-09-27): TaskBoardGateway now flips in _registerContentSeams like
  // the other applied-table seams. The approvals queue LEFT it in the
  // approvals slice (design §3) and flips in _registerApprovalSeams; the
  // compliance alerts LEFT it in the compliance slice (design §4) and flips
  // in _registerComplianceSeams. The AI research seam LEFT it in the research
  // slice (design §5): SyntheticAiGateway is now the env-less arm of
  // _registerResearchSeams, and configured builds use SupabaseResearchGateway.
}
