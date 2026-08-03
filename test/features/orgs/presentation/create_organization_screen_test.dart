import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/create_organization_screen.dart';
import 'package:legalhub/features/orgs/presentation/org_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// A gateway whose create call waits on a caller-controlled gate so tests can
/// pin the in-flight state; everything else delegates to the fake.
class _GatedOrgGateway implements OrganizationGateway {
  _GatedOrgGateway(this._inner);

  final OrganizationGateway _inner;
  Completer<void>? createGate;

  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) async {
    if (createGate != null) {
      await createGate!.future;
    }
    return _inner.createOrganization(name: name);
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  }) => _inner.listMembers(organizationId: organizationId);

  @override
  Future<OrgOutcome<InviteResult>> inviteMember({
    required String organizationId,
    required String email,
    required UserRole role,
  }) => _inner.inviteMember(
    organizationId: organizationId,
    email: email,
    role: role,
  );

  @override
  Future<OrgOutcome<void>> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  }) => _inner.changeMemberRole(
    organizationId: organizationId,
    userId: userId,
    role: role,
  );

  @override
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  }) => _inner.suspendMember(organizationId: organizationId, userId: userId);

  @override
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  }) => _inner.reactivateMember(organizationId: organizationId, userId: userId);

  @override
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  }) => _inner.removeMember(organizationId: organizationId, userId: userId);
}

/// A gateway that rejects every create call with a typed failure, to pin the
/// localized error surface without touching the fake's semantics.
class _FailingCreateGateway extends _GatedOrgGateway {
  _FailingCreateGateway(super.inner);

  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) async {
    return const OrgOutcome<OrganizationSummary>.failure(
      OrgFailure(kind: OrgFailureKind.invalidName),
    );
  }
}

void main() {
  late FakeOrganizationGateway gateway;
  late OrgCubit cubit;
  late OrganizationSummary? created;

  setUp(() {
    gateway = FakeOrganizationGateway();
    cubit = OrgCubit(gateway);
    created = null;
  });

  tearDown(() => cubit.close());

  Widget harness({
    Locale locale = const Locale('en'),
    OrganizationGateway? gatewayOverride,
  }) {
    final OrgCubit effectiveCubit = gatewayOverride == null
        ? cubit
        : OrgCubit(gatewayOverride);
    return BlocProvider<OrgCubit>.value(
      value: effectiveCubit,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreateOrganizationScreen(
          onCreated: (OrganizationSummary org) {
            created = org;
          },
        ),
      ),
    );
  }

  Future<void> submit(WidgetTester tester) async {
    final Finder button = find.widgetWithText(
      ElevatedButton,
      'Create Organization',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('renders the create-org form', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Create Organization'), findsWidgets);
    expect(
      find.text('Give your firm a name. You will become its first partner.'),
      findsOneWidget,
    );
    expect(find.text('Organization name'), findsOneWidget);
    expect(find.text('e.g. Sterling & Associates'), findsOneWidget);
  });

  testWidgets('rejects an empty name client-side', (tester) async {
    await tester.pumpWidget(harness());

    await submit(tester);

    expect(find.text('This field is required.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('rejects a whitespace-only name client-side', (tester) async {
    await tester.pumpWidget(harness());

    await tester.enterText(find.byType(TextFormField), '   ');
    await submit(tester);

    expect(find.text('This field is required.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('creates the organization with a trimmed name', (tester) async {
    await tester.pumpWidget(harness());

    await tester.enterText(find.byType(TextFormField), '  Nova Legal  ');
    await submit(tester);

    expect(created, isNotNull);
    expect(created!.name, 'Nova Legal');
    expect(cubit.state, isA<OrgCreateSuccess>());
  });

  testWidgets('surfaces the typed failure as a localized message', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        gatewayOverride: _FailingCreateGateway(FakeOrganizationGateway()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Nova Legal');
    await submit(tester);

    expect(find.text('The organization name cannot be empty.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('shows a spinner and disables the button while creating', (
    tester,
  ) async {
    final _GatedOrgGateway gated = _GatedOrgGateway(FakeOrganizationGateway());
    final Completer<void> gate = Completer<void>();
    gated.createGate = gate;
    await tester.pumpWidget(harness(gatewayOverride: gated));

    await tester.enterText(find.byType(TextFormField), 'Nova Legal');
    final Finder button = find.widgetWithText(
      ElevatedButton,
      'Create Organization',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final ElevatedButton createButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Create Organization'),
    );
    expect(createButton.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(created, isNotNull);
    expect(created!.name, 'Nova Legal');
  });

  testWidgets('renders the Arabic translation of the form', (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('ar')));

    expect(find.text('إنشاء مؤسسة'), findsWidgets);
    expect(find.text('اسم المؤسسة'), findsOneWidget);
  });

  testWidgets('renders the Turkish translation of the form', (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('tr')));

    expect(find.text('Kuruluş Oluştur'), findsWidgets);
    expect(find.text('Kuruluş adı'), findsOneWidget);
  });
}
