import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/approvals/data/fake_approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';
import 'package:legalhub/features/approvals/presentation/approvals_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpApprovals(WidgetTester tester) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ApprovalsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('pending approvals screen (v1 queue 2026-08-09)', () {
    testWidgets('lists the synthetic redacted approvals from the fake', (
      tester,
    ) async {
      await pumpApprovals(tester);

      expect(find.text('Pending approvals'), findsWidgets);
      for (final PendingApproval approval
          in FakeApprovalsGateway.syntheticApprovals) {
        expect(
          find.text('${approval.entityType} · ${approval.reference}'),
          findsOneWidget,
        );
      }
    });

    testWidgets('renders status labels as text/icon (never color alone)', (
      tester,
    ) async {
      await pumpApprovals(tester);

      expect(find.text('invitation · Demo invite — review'), findsOneWidget);
      expect(find.textContaining('Pending ·'), findsNWidgets(3));
      expect(find.textContaining('Approved ·'), findsOneWidget);
      expect(find.textContaining('Denied ·'), findsOneWidget);
    });

    testWidgets('no approve/deny affordance — read-only (spec v1)', (
      tester,
    ) async {
      await pumpApprovals(tester);

      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('empty state renders the localized copy', (tester) async {
      await _registerStub(<Result<List<PendingApproval>>>[
        Result<List<PendingApproval>>.success(const <PendingApproval>[]),
      ]);
      await pumpApprovals(tester);

      expect(find.text('No pending approvals are available.'), findsOneWidget);
    });

    testWidgets('failure renders error + retry reissues', (tester) async {
      await _registerStub(<Result<List<PendingApproval>>>[
        Result<List<PendingApproval>>.failure(_loadFailure),
        Result<List<PendingApproval>>.success(
          FakeApprovalsGateway.syntheticApprovals,
        ),
      ]);
      await pumpApprovals(tester);

      expect(find.text('Unable to load approvals.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load approvals.'), findsNothing);
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'approvals_failed',
  userMessage: 'Could not load approvals',
);

Future<void> _registerStub(List<Result<List<PendingApproval>>> results) async {
  await resetServiceLocator();
  serviceLocator.registerLazySingleton<ApprovalsGateway>(
    () => _StubApprovalsGateway(results),
  );
}

class _StubApprovalsGateway implements ApprovalsGateway {
  _StubApprovalsGateway(this.results);

  final List<Result<List<PendingApproval>>> results;

  @override
  Future<Result<List<PendingApproval>>> fetchApprovals() async {
    return results.removeAt(0);
  }
}
