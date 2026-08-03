import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/accept_invitation_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// AcceptInvitationScreen (Phase 2 slice 2.4): paste-token acceptance against
// the gateway seam. The role is server-owned; the fake mirrors the
// non-enumerating 'invalid invitation' denial for unknown tokens.
void main() {
  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
  });

  tearDown(() => resetServiceLocator());

  Widget harness() {
    return const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AcceptInvitationScreen(),
    );
  }

  testWidgets('a valid token joins the organization', (tester) async {
    // The demo identity accepts an invite minted for its own email: create a
    // fresh org (demo user is already a member of the seeded demo org) and
    // invite the demo email.
    final OrganizationGateway gateway = serviceLocator<OrganizationGateway>();
    final OrgOutcome<OrganizationSummary> created = await gateway
        .createOrganization(name: 'Second Firm');
    final OrgOutcome<InviteResult> invite = await gateway.inviteMember(
      organizationId: created.valueOrNull!.id,
      email: FakeOrganizationGateway.demoUserEmail,
      role: UserRole.attorney,
    );
    expect(invite.isSuccess, isTrue);

    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextField), invite.valueOrNull!.token);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation accepted.'), findsOneWidget);
    expect(find.text('You joined the organization.'), findsOneWidget);

    // The acceptance created the membership with the server-owned role.
    final OrgOutcome<List<OrgMember>> roster = await gateway.listMembers(
      organizationId: created.valueOrNull!.id,
    );
    final OrgMember demo = roster.valueOrNull!.single;
    expect(demo.userId, FakeOrganizationGateway.demoUserId);
    expect(demo.role, UserRole.attorney);
    expect(demo.status, MembershipStatus.active);
  });

  testWidgets('a bad token surfaces the localized invalid-invitation error', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextField), 'wrong-token');
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('The invitation is invalid or expired.'), findsOneWidget);
    expect(find.text('Invitation accepted.'), findsNothing);
  });

  testWidgets('an empty token makes no call', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation accepted.'), findsNothing);
    expect(find.text('The invitation is invalid or expired.'), findsNothing);
  });
}
