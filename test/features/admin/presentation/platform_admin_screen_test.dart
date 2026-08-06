import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/admin/platform_admin_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/admin/fake_platform_admin_gateway.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/admin/presentation/platform_admin_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// A mutable [PlatformAdminGateway] stub for the screen tests: canned lists
/// that mutate on actions (so reloads show the change), with a `denied` flag
/// for the AC-7 pin and a never-self rule on the demo identity (mirroring
/// the RPC's refusal). The org-domain last-partner guard lives in the real
/// fake, so the suspend/reactivate success paths use this stub.
class _MutablePlatformAdminGateway implements PlatformAdminGateway {
  List<OrganizationSummary> organizations = <OrganizationSummary>[];
  List<OrgMember> members = <OrgMember>[];
  bool denied = false;
  OrgFailureKind? loadFailureKind;
  OrgFailureKind? voidFailureKind;
  int loadCalls = 0;

  @override
  Future<OrgOutcome<List<OrganizationSummary>>> listOrganizations() async {
    loadCalls++;
    if (denied) {
      return const OrgOutcome<List<OrganizationSummary>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (loadFailureKind != null) {
      return OrgOutcome<List<OrganizationSummary>>.failure(
        OrgFailure(kind: loadFailureKind!),
      );
    }
    return OrgOutcome<List<OrganizationSummary>>.success(organizations);
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers() async {
    if (denied) {
      return const OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (loadFailureKind != null) {
      return OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: loadFailureKind!),
      );
    }
    return OrgOutcome<List<OrgMember>>.success(members);
  }

  @override
  Future<OrgOutcome<void>> suspendMembership({
    required String organizationId,
    required String userId,
  }) async {
    if (voidFailureKind != null) {
      return OrgOutcome<void>.failure(OrgFailure(kind: voidFailureKind!));
    }
    members = members
        .map(
          (OrgMember m) => m.userId == userId
              ? _withStatus(m, MembershipStatus.suspended)
              : m,
        )
        .toList(growable: false);
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<void>> reactivateMembership({
    required String organizationId,
    required String userId,
  }) async {
    if (voidFailureKind != null) {
      return OrgOutcome<void>.failure(OrgFailure(kind: voidFailureKind!));
    }
    members = members
        .map(
          (OrgMember m) =>
              m.userId == userId ? _withStatus(m, MembershipStatus.active) : m,
        )
        .toList(growable: false);
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<void>> deleteDemoAccount({required String userId}) async {
    if (voidFailureKind != null) {
      return OrgOutcome<void>.failure(OrgFailure(kind: voidFailureKind!));
    }
    if (userId == 'demo-user') {
      // Mirrors the RPC's never-self refusal.
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    members = members.where((OrgMember m) => m.userId != userId).toList();
    return const OrgOutcome<void>.success(null);
  }

  static OrgMember _withStatus(OrgMember m, MembershipStatus status) {
    return OrgMember(
      organizationId: m.organizationId,
      userId: m.userId,
      displayName: m.displayName,
      locale: m.locale,
      role: m.role,
      status: status,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      invitationId: m.invitationId,
    );
  }
}

final OrganizationSummary _org = OrganizationSummary(
  id: 'org-1',
  name: 'Demo Firm',
  createdAt: DateTime.utc(2026, 7, 25),
);

final OrgMember _demoMember = OrgMember(
  organizationId: 'org-1',
  userId: 'demo-user',
  displayName: 'Demo user',
  locale: 'en',
  role: UserRole.partner,
  status: MembershipStatus.active,
  createdAt: DateTime.utc(2026, 7, 25),
  updatedAt: DateTime.utc(2026, 7, 25),
);

Widget harness(
  PlatformAdminGateway gateway, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // The screen self-provides its cubit from this gateway (test seam).
    home: PlatformAdminScreen(gateway: gateway),
  );
}

void main() {
  group('PlatformAdminScreen owner (P3.5)', () {
    testWidgets('renders both metadata sections', (tester) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[_demoMember];

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      expect(find.text('Platform admin'), findsOneWidget);
      expect(find.text('Organizations'), findsOneWidget);
      expect(find.text('Demo Firm'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      // Member row: identity + org · status + the platform actions.
      expect(find.text('Demo user'), findsOneWidget);
      expect(find.text('Demo Firm · ACTIVE'), findsOneWidget);
      expect(find.byTooltip('Suspend'), findsOneWidget);
      expect(find.byTooltip('Delete demo account'), findsOneWidget);
    });

    testWidgets('a successful suspend flips the row to SUSPENDED', (
      tester,
    ) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[_demoMember];

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Suspend'));
      await tester.pumpAndSettle();

      expect(find.text('Demo Firm · SUSPENDED'), findsOneWidget);
      expect(find.byTooltip('Reactivate'), findsOneWidget);
      expect(find.byTooltip('Suspend'), findsNothing);
    });

    testWidgets('a successful reactivate flips the row back to ACTIVE', (
      tester,
    ) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[
              OrgMember(
                organizationId: 'org-1',
                userId: 'demo-user',
                displayName: 'Demo user',
                locale: 'en',
                role: UserRole.partner,
                status: MembershipStatus.suspended,
                createdAt: DateTime.utc(2026, 7, 25),
                updatedAt: DateTime.utc(2026, 7, 25),
              ),
            ];

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reactivate'));
      await tester.pumpAndSettle();

      expect(find.text('Demo Firm · ACTIVE'), findsOneWidget);
    });

    testWidgets('delete requires confirmation and removes the row', (
      tester,
    ) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[
              _demoMember,
              OrgMember(
                organizationId: 'org-1',
                userId: 'u-9',
                displayName: 'Synthetic Demo',
                locale: 'en',
                role: UserRole.client,
                status: MembershipStatus.active,
                createdAt: DateTime.utc(2026, 7, 25),
                updatedAt: DateTime.utc(2026, 7, 25),
              ),
            ];

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete demo account').last);
      await tester.pumpAndSettle();
      // The destructive confirm dialog appears; cancel leaves the row.
      expect(find.text('Delete demo account?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Demo'), findsOneWidget);

      // Confirming deletes the account; the row leaves on reload.
      await tester.tap(find.byTooltip('Delete demo account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Demo'), findsNothing);
      expect(find.text('Demo user'), findsOneWidget);
    });

    testWidgets('never-self delete surfaces the denied message', (
      tester,
    ) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[_demoMember];

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete demo account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text("You don't have permission to perform this action."),
        findsOneWidget,
      );
      // The demo row survives the refused deletion.
      expect(find.text('Demo user'), findsOneWidget);
    });
  });

  group('PlatformAdminScreen non-owner (AC-7)', () {
    testWidgets('renders the distinct denied state, never empty success', (
      tester,
    ) async {
      final FakeOrganizationGateway orgGateway = FakeOrganizationGateway();
      final FakePlatformAdminGateway gateway = FakePlatformAdminGateway(
        organizationGateway: orgGateway,
        demoIsPlatformOwner: false,
      );

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      expect(find.text('Access not available'), findsOneWidget);
      expect(
        find.text("You don't have permission to perform this action."),
        findsOneWidget,
      );
      // Never an empty-success list: no org/member names, no empty label.
      expect(find.text('Demo Firm'), findsNothing);
      expect(find.text('Demo user'), findsNothing);
      expect(find.text('Nothing to show'), findsNothing);
      // The metadata sections are not shown at all.
      expect(find.text('Organizations'), findsNothing);
      expect(find.text('Members'), findsNothing);
    });
  });

  group('PlatformAdminScreen failures', () {
    testWidgets('a failure shows the typed message and retry recovers', (
      tester,
    ) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[_demoMember]
            ..loadFailureKind = OrgFailureKind.unknown;

      await tester.pumpWidget(harness(gateway));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      gateway.loadFailureKind = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Demo Firm'), findsOneWidget);
    });
  });

  group('PlatformAdminScreen localization', () {
    testWidgets('renders section headers in Arabic (RTL)', (tester) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[_demoMember];

      await tester.pumpWidget(harness(gateway, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('إدارة المنصة'), findsOneWidget);
      expect(find.text('المؤسسات'), findsOneWidget);
      expect(find.text('الأعضاء'), findsOneWidget);
      // The member status chip is localized too.
      expect(find.text('Demo Firm · نشط'), findsOneWidget);
    });

    testWidgets('renders section headers in Turkish', (tester) async {
      final _MutablePlatformAdminGateway gateway =
          _MutablePlatformAdminGateway()
            ..organizations = <OrganizationSummary>[_org]
            ..members = <OrgMember>[_demoMember];

      await tester.pumpWidget(harness(gateway, locale: const Locale('tr')));
      await tester.pumpAndSettle();

      expect(find.text('Kuruluşlar'), findsOneWidget);
      expect(find.text('Üyeler'), findsOneWidget);
      expect(find.text('Demo Firm · AKTİF'), findsOneWidget);
    });
  });
}
