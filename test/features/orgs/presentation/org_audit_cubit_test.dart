import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/org_audit_cubit.dart';

/// Fake org gateway with a switchable failure for the audit read — keeps the
/// deterministic demo rows for the success path and lets tests force
/// denied/unknown outcomes for the failure paths.
class _SwitchableAuditGateway extends FakeOrganizationGateway {
  OrgFailure? auditFailure;

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    final OrgFailure? failure = auditFailure;
    if (failure != null) {
      return OrgOutcome<List<AuditEntry>>.failure(failure);
    }
    return super.readOrgAudit(organizationId: organizationId);
  }
}

void main() {
  group('OrgAuditCubit', () {
    blocTest<OrgAuditCubit, OrgAuditState>(
      'emits loading then the demo org trail',
      build: () => OrgAuditCubit(FakeOrganizationGateway()),
      act: (OrgAuditCubit cubit) => cubit.load(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      ),
      expect: () => <Object?>[
        const OrgAuditLoading(),
        isA<OrgAuditLoaded>().having(
          (OrgAuditLoaded state) => state.entries.length,
          'entries length',
          3,
        ),
      ],
    );

    void freshOrgEmptyTest() {
      late FakeOrganizationGateway gateway;

      blocTest<OrgAuditCubit, OrgAuditState>(
        'keeps the honest empty trail distinct from denial',
        build: () {
          gateway = FakeOrganizationGateway();
          return OrgAuditCubit(gateway);
        },
        act: (OrgAuditCubit cubit) async {
          final OrgOutcome<OrganizationSummary> created = await gateway
              .createOrganization(name: 'Fresh Firm');
          await cubit.load(organizationId: created.valueOrNull!.id);
        },
        expect: () => <Object?>[
          const OrgAuditLoading(),
          const OrgAuditLoaded(<AuditEntry>[]),
        ],
      );
    }

    freshOrgEmptyTest();

    blocTest<OrgAuditCubit, OrgAuditState>(
      'maps the server permission denied to the distinct denied state',
      build: () => OrgAuditCubit(FakeOrganizationGateway()),
      act: (OrgAuditCubit cubit) =>
          cubit.load(organizationId: 'org-not-in-any-registry'),
      expect: () => <Object?>[const OrgAuditLoading(), const OrgAuditDenied()],
    );

    void nonDeniedFailureTest() {
      late _SwitchableAuditGateway gateway;

      blocTest<OrgAuditCubit, OrgAuditState>(
        'surfaces a non-denied failure as failed with the org id for retry',
        build: () {
          gateway = _SwitchableAuditGateway();
          gateway.auditFailure = const OrgFailure(kind: OrgFailureKind.unknown);
          return OrgAuditCubit(gateway);
        },
        act: (OrgAuditCubit cubit) => cubit.load(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
        ),
        expect: () => <dynamic>[
          const OrgAuditLoading(),
          isA<OrgAuditFailed>().having(
            (OrgAuditFailed state) => state.kind,
            'kind',
            OrgFailureKind.unknown,
          ),
        ],
      );
    }

    nonDeniedFailureTest();

    void retryTest() {
      late _SwitchableAuditGateway gateway;

      blocTest<OrgAuditCubit, OrgAuditState>(
        'retry re-issues the failed load after the failure clears',
        build: () {
          gateway = _SwitchableAuditGateway();
          gateway.auditFailure = const OrgFailure(kind: OrgFailureKind.unknown);
          return OrgAuditCubit(gateway);
        },
        act: (OrgAuditCubit cubit) async {
          await cubit.load(
            organizationId: FakeOrganizationGateway.demoOrganizationId,
          );
          gateway.auditFailure = null;
          await cubit.retry();
        },
        expect: () => <dynamic>[
          const OrgAuditLoading(),
          isA<OrgAuditFailed>(),
          const OrgAuditLoading(),
          isA<OrgAuditLoaded>().having(
            (OrgAuditLoaded state) => state.entries.length,
            'entries length',
            3,
          ),
        ],
      );
    }

    retryTest();
  });
}
