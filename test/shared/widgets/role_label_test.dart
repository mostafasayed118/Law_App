import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/role_label.dart';

// RoleLabel is the canonical role→label mapping (ADR-0004 second use: it
// replaces the duplicated private _roleLabel switches on the settings and
// profile screens). These tests pin the mapping for every role, the
// null→client fallback, and the localized render path.
void main() {
  group('roleLabel', () {
    late AppLocalizations l10n;

    setUpAll(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('maps every role to its localized label', () {
      expect(roleLabel(l10n, UserRole.client), l10n.roleClient);
      expect(roleLabel(l10n, UserRole.attorney), l10n.roleAttorney);
      expect(roleLabel(l10n, UserRole.partner), l10n.rolePartner);
      expect(
        roleLabel(l10n, UserRole.complianceOfficer),
        l10n.roleComplianceOfficer,
      );
      expect(
        roleLabel(l10n, UserRole.researchAnalyst),
        l10n.roleResearchAnalyst,
      );
      expect(roleLabel(l10n, UserRole.admin), l10n.roleAdmin);
    });

    test('maps a null role to the client label (demo-session default)', () {
      expect(roleLabel(l10n, null), l10n.roleClient);
    });
  });

  group('RoleLabel widget', () {
    Widget pumpRoleLabel(UserRole? role, {Locale locale = const Locale('en')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RoleLabel(role: role)),
      );
    }

    testWidgets('renders the localized client label for a null role', (
      tester,
    ) async {
      await tester.pumpWidget(pumpRoleLabel(null));

      expect(find.text('Client'), findsOneWidget);
    });

    testWidgets('renders the role label from the session role', (tester) async {
      await tester.pumpWidget(pumpRoleLabel(UserRole.partner));

      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('Client'), findsNothing);
    });

    testWidgets('resolves the Arabic label under the ar locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpRoleLabel(UserRole.client, locale: const Locale('ar')),
      );

      expect(find.text('العميل'), findsOneWidget);
    });
  });
}
