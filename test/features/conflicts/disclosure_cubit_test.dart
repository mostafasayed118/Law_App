import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/conflicts/data/matter_gateway_conflict_search_source.dart';
import 'package:legalhub/features/conflicts/domain/conflict_disclosure.dart';
import 'package:legalhub/features/conflicts/presentation/disclosure_cubit.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';

class _FailingAlertsGateway implements ComplianceAlertsGateway {
  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts({
    AlertStatus? status,
    AlertSeverity? severity,
  }) async => const Success<List<ComplianceAlert>>(<ComplianceAlert>[]);

  @override
  Future<Result<String>> create(ComplianceAlertDraft draft) async =>
      const Failure<String>(
        AppError(code: 'test_create_failed', userMessage: 'Create failed'),
      );

  @override
  Future<Result<void>> acknowledge(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> resolve(String id, {String? note}) async =>
      const Success<void>(null);
}

class _FailingMatters implements MatterGateway {
  @override
  Future<Result<List<Matter>>> fetchMatters() async =>
      const Failure<List<Matter>>(
        AppError(code: 'matters_failed', userMessage: 'Matters failed'),
      );

  @override
  Future<Result<List<Matter>>> searchMatters(
    String query, {
    int limit = 30,
  }) async => const Failure<List<Matter>>(
    AppError(code: 'matters_failed', userMessage: 'Matters failed'),
  );
}

void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;

  setUp(() async {
    configureDependencies();
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    await authCubit.startDemoSession();
    serviceLocator<ActiveOrgStore>().select('org-demo-1');
  });

  tearDown(() async {
    await authCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  DisclosureCubit buildCubit({ComplianceAlertsGateway? alerts}) {
    final MatterGateway matters = serviceLocator<MatterGateway>();
    return DisclosureCubit(
      matters: matters,
      search: MatterGatewayConflictSearchSource(matters),
      alerts: alerts ?? serviceLocator<ComplianceAlertsGateway>(),
      org: serviceLocator<ActiveOrgStore>(),
    );
  }

  List<Matter> loadedMatters(DisclosureCubit cubit) =>
      (cubit.state.matters as ViewSuccess<List<Matter>>).data;

  test(
    'failed matter reads surface as ViewError and model props are stable',
    () async {
      final DisclosureCubit cubit = DisclosureCubit(
        matters: _FailingMatters(),
        search: MatterGatewayConflictSearchSource(_FailingMatters()),
        alerts: serviceLocator<ComplianceAlertsGateway>(),
        org: serviceLocator<ActiveOrgStore>(),
      );
      addTearDown(cubit.close);
      await cubit.loadMatters();
      expect(cubit.state.matters, isA<ViewError<List<Matter>>>());
      await cubit.searchMatters('anything');
      expect(cubit.state.matters, isA<ViewError<List<Matter>>>());
      cubit.back(); // no-op on the first step
      expect(cubit.state.step, DisclosureStep.matter);

      const ConflictParty party = ConflictParty(
        name: 'Demo party',
        role: ConflictPartyRole.coCounsel,
        jurisdiction: 'EG',
      );
      expect(party.props, <Object?>[
        party.name,
        party.role,
        party.jurisdiction,
      ]);
      const ConflictFinding finding = ConflictFinding(
        partyName: 'Demo party',
        kind: ConflictMatchKind.indirect,
        matterId: 'matter-1',
        matterTitle: 'Demo matter',
      );
      expect(finding.props, <Object?>[
        finding.partyName,
        finding.kind,
        finding.matterId,
        finding.matterTitle,
      ]);
    },
  );

  test(
    'full wizard flow checks real matters and submits via alerts gateway',
    () async {
      final DisclosureCubit cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadMatters();
      final Matter first = loadedMatters(cubit).first;
      cubit.selectMatter(first);
      cubit.nextFromMatter();
      expect(cubit.state.step, DisclosureStep.parties);

      // A real attorney name from the gateway produces a real local match.
      cubit.addParty(
        name: first.assignedAttorneyName,
        role: ConflictPartyRole.adverseParty,
        jurisdiction: 'EG',
      );
      expect(cubit.state.draft.parties, hasLength(1));
      await cubit.nextFromParties();
      expect(cubit.state.step, DisclosureStep.analysis);
      expect(cubit.state.analysis, isNotNull);
      expect(
        cubit.state.analysis!.checkedMatterCount,
        loadedMatters(cubit).length,
      );
      expect(cubit.state.analysis!.findings, isNotEmpty);

      cubit.nextFromAnalysis();
      expect(cubit.state.step, DisclosureStep.review);
      cubit.setCertified(true);
      await cubit.submit();
      expect(
        cubit.state.step,
        DisclosureStep.success,
        reason:
            'org=${serviceLocator<ActiveOrgStore>().activeOrganizationId} '
            'status=${cubit.state.submitStatus} error=${cubit.state.submitError}',
      );
      expect(cubit.state.submitStatus, DisclosureSubmitStatus.success);
    },
  );

  test(
    'edits, back, removals, debounced query and failed submit stay honest',
    () async {
      final DisclosureCubit cubit = buildCubit(alerts: _FailingAlertsGateway());
      addTearDown(cubit.close);
      await cubit.loadMatters();
      final Matter first = loadedMatters(cubit).first;
      cubit.selectMatter(first);
      cubit.nextFromMatter();
      cubit.addParty(
        name: 'Unmatched demo party',
        role: ConflictPartyRole.relatedEntity,
        jurisdiction: '',
      );
      cubit.addParty(
        name: 'Second demo party',
        role: ConflictPartyRole.keyWitness,
        jurisdiction: 'EG',
      );
      cubit.removeParty(1);
      expect(cubit.state.draft.parties, hasLength(1));
      await cubit.searchMatters('Demo');
      cubit.queryChanged('');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      await cubit.nextFromParties();
      expect(cubit.state.analysis!.findings, isEmpty);
      cubit.nextFromAnalysis();
      cubit.edit(DisclosureStep.parties);
      expect(cubit.state.step, DisclosureStep.parties);
      await cubit.nextFromParties();
      cubit.nextFromAnalysis();
      cubit.nextFromAnalysis();
      cubit.back();
      expect(cubit.state.step, DisclosureStep.analysis);
      cubit.nextFromAnalysis();
      expect(cubit.state.step, DisclosureStep.review);
      cubit.setCertified(true);
      await cubit.submit();
      expect(cubit.state.step, DisclosureStep.review);
      expect(cubit.state.submitStatus, DisclosureSubmitStatus.error);
      expect(cubit.state.submitError, isA<AppError>());
    },
  );
}
