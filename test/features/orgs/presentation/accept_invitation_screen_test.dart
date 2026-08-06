import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/auth/auth_gateway.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/orgs/presentation/accept_invitation_screen.dart';
import 'package:legalhub/features/orgs/presentation/active_org_store.dart';
import 'package:legalhub/l10n/app_localizations.dart';

// AcceptInvitationScreen (Phase 2 slice 2.4; P3.4 handoff): paste-token
// acceptance against the gateway seam, then a background re-hydration +
// active-org switch (D-P33.3 consummated). The role is server-owned; the
// fake mirrors the non-enumerating 'invalid invitation' denial for unknown
// tokens. The harness provides AuthCubit (built from the locator's shared
// fakes — P3.3 Slice B binds the membership repository to the org gateway)
// so the success path can exercise the real re-hydration derivation.
void main() {
  late AuthCubit authCubit;

  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
    authCubit = AuthCubit(
      serviceLocator<AuthGateway>(),
      InMemoryErrorReporter(),
      serviceLocator<MembershipRepository>(),
    );
  });

  tearDown(() async {
    await authCubit.close();
    await resetServiceLocator();
  });

  Widget harness({Locale locale = const Locale('en')}) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthCubit>.value(value: authCubit),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AcceptInvitationScreen(),
      ),
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

  testWidgets(
    'a valid token re-hydrates the session and switches to the new org',    (tester) async {
      // An established session holding only the seeded demo org FIRST — the
      // DI-bound hydration derives from the shared fake gateway, so creating
      // the org before the session would already include it.
      await authCubit.startDemoSession();
      expect(authCubit.state.session?.memberships, hasLength(1));

      final OrganizationGateway gateway =
          serviceLocator<OrganizationGateway>();
      final OrgOutcome<OrganizationSummary> created = await gateway
          .createOrganization(name: 'Second Firm');
      final OrgOutcome<InviteResult> invite = await gateway.inviteMember(
        organizationId: created.valueOrNull!.id,
        email: FakeOrganizationGateway.demoUserEmail,
        role: UserRole.attorney,
      );
      expect(invite.isSuccess, isTrue);
      final String joinedId = created.valueOrNull!.id;

      await tester.pumpWidget(harness());
      await tester.enterText(find.byType(TextField), invite.valueOrNull!.token);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('Invitation accepted.'), findsOneWidget);
      // D-P33.3 handoff: the background refresh added the accepted
      // membership to the session, and the local active-org context switched
      // to it (D-08 — client-side, membership-backed), so the hub lands on
      // the new organization.
      expect(authCubit.state.session?.memberships, hasLength(2));
      expect(
        authCubit.state.session?.memberships.any(
          (m) => m.organizationId == joinedId,
        ),
        isTrue,
      );
      expect(serviceLocator<ActiveOrgStore>().activeOrganizationId, joinedId);
    },
  );

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

  testWidgets('a bad token surfaces the localized error under Arabic (RTL)', (
    tester,
  ) async {
    await tester.pumpWidget(harness(locale: const Locale('ar')));
    await tester.enterText(find.byType(TextField), 'wrong-token');
    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();

    // The single non-enumerating invalid-invitation message resolves in AR.
    expect(find.text('الدعوة غير صالحة أو منتهية.'), findsOneWidget);
    expect(find.text('تم قبول الدعوة.'), findsNothing);
  });

  testWidgets('an empty token makes no call', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation accepted.'), findsNothing);
    expect(find.text('The invitation is invalid or expired.'), findsNothing);
  });
}
