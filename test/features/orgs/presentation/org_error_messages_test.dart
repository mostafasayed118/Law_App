import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/orgs/domain/organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/org_error_messages.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  group('orgErrorMessage', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

    test('maps the client-side busy refusal to the in-progress copy', () {
      expect(
        orgErrorMessage(en, OrgFailureKind.busy),
        'An action is already in progress.',
      );
    });
  });
}
