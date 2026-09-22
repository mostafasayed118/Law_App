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
  // Phase 5–12 fake-domain pattern, "the fake is the product posture").
  if (!serviceLocator.isRegistered<ComplianceAlertsGateway>()) {
    serviceLocator.registerLazySingleton<ComplianceAlertsGateway>(
      FakeComplianceGateway.new,
    );
  }
  if (!serviceLocator.isRegistered<TaskBoardGateway>()) {
    serviceLocator.registerLazySingleton<TaskBoardGateway>(FakeTaskGateway.new);
  }
  if (!serviceLocator.isRegistered<ApprovalsGateway>()) {
    serviceLocator.registerLazySingleton<ApprovalsGateway>(
      FakeApprovalsGateway.new,
    );
  }
  // AI research slice (plan 2026-09-02): the synthetic engine composes the
  // two SHIPPED read seams (ratified scope decision D-2 — shipped gateways
  // only, no AI-only corpus), so it automatically follows the env flip of
  // DocumentGateway/MatterGateway. D-1: no model provider — the synthetic
  // gateway IS the product posture; a real provider would arrive behind the
  // same AiGateway seam. C-1: no persistence — no store class is registered.
  if (!serviceLocator.isRegistered<AiGateway>()) {
    serviceLocator.registerLazySingleton<AiGateway>(
      () => SyntheticAiGateway(
        documentGateway: serviceLocator<DocumentGateway>(),
        matterGateway: serviceLocator<MatterGateway>(),
      ),
    );
  }
}
