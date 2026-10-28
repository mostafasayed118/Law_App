import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';
import 'package:legalhub/features/approvals/presentation/approval_create_sheet.dart';
import 'package:legalhub/features/approvals/presentation/approvals_cubit.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late _StubApprovalsGateway gateway;
  late _StubMatterGateway matterGateway;
  late ApprovalsCubit cubit;
  bool? sheetResult;

  setUp(() async {
    await resetServiceLocator();
    gateway = _StubApprovalsGateway();
    matterGateway = _StubMatterGateway();
    sheetResult = null;
    serviceLocator.registerLazySingleton<ApprovalsGateway>(() => gateway);
    configureDependencies();
    cubit = ApprovalsCubit(gateway, matterGateway);
  });

  tearDown(() async {
    await cubit.close();
    await resetServiceLocator();
  });

  Future<void> openSheet(WidgetTester tester, {bool withOrg = true}) async {
    if (withOrg) {
      serviceLocator<ActiveOrgStore>().select('org-1');
    }
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () async {
                  sheetResult = await showApprovalCreateSheet(
                    context,
                    cubit: cubit,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterTitle(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextFormField).first, title);
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Submit request'));
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
  }

  group('ApprovalCreateSheet', () {
    testWidgets('renders the required fields and blocks an empty submit', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('New approval request'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Kind'), findsOneWidget);
      expect(find.text('Matter (optional)'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
      expect(find.text('Submit request'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tapSubmit(tester);

      expect(find.text('Title must be at least 2 characters.'), findsOneWidget);
      expect(gateway.createAttempts, 0);
      expect(find.text('New approval request'), findsOneWidget);
    });

    testWidgets('refuses to submit without an active organization', (
      tester,
    ) async {
      await openSheet(tester, withOrg: false);

      expect(
        find.text('Select an organization before creating a request.'),
        findsOneWidget,
      );
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit request'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('submits the draft and closes with success', (tester) async {
      await openSheet(tester);

      await enterTitle(tester, '  New matter waiver  ');
      await tester.enterText(
        find.byType(TextFormField).last,
        ' Needs partner sign-off ',
      );
      await tester.tap(find.byType(DropdownButtonFormField<ApprovalKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expense').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo acquisition review').last);
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      expect(gateway.createdDrafts, hasLength(1));
      final ApprovalDraft draft = gateway.createdDrafts.single;
      expect(draft.organizationId, 'org-1');
      expect(draft.title, 'New matter waiver');
      expect(draft.kind, ApprovalKind.expense);
      expect(draft.matterId, 'matter-1');
      expect(draft.description, 'Needs partner sign-off');
      expect(find.text('New approval request'), findsNothing);
      expect(sheetResult, isTrue);
    });

    testWidgets('renders a typed failure inline and keeps submit available', (
      tester,
    ) async {
      gateway.createFailures.add(
        const AppError(
          code: 'approval_create_unavailable',
          userMessage: 'offline',
          kind: AppErrorKind.unavailable,
        ),
      );
      await openSheet(tester);

      await enterTitle(tester, 'New matter waiver');
      await tapSubmit(tester);

      expect(gateway.createAttempts, 1);
      expect(
        find.text('The service is temporarily unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('New approval request'), findsOneWidget);
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit request'),
      );
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('a thrown create re-enables submit and a retry lands (N1)', (
      tester,
    ) async {
      gateway.throwNextCreate = true;
      await openSheet(tester);

      await enterTitle(tester, 'New matter waiver');
      await tapSubmit(tester);

      expect(gateway.createAttempts, 1);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('New approval request'), findsOneWidget);
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit request'),
      );
      expect(submit.onPressed, isNotNull);

      await tapSubmit(tester);

      expect(gateway.createAttempts, 2);
      expect(gateway.createdDrafts, hasLength(1));
      expect(find.text('New approval request'), findsNothing);
      expect(sheetResult, isTrue);
    });

    testWidgets('a failed matter read shows the inline retry', (tester) async {
      matterGateway.nextResult = const Result<List<Matter>>.failure(
        AppError(code: 'matters_failed', userMessage: 'offline'),
      );
      await openSheet(tester);

      expect(
        find.text(
          'Unable to load matters. You can still submit without a matter.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(matterGateway.fetchCalls, 2);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a thrown matter read lands on the retry arm (N1)', (
      tester,
    ) async {
      matterGateway.throwNext = true;
      await openSheet(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text(
          'Unable to load matters. You can still submit without a matter.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

class _StubMatterGateway extends FakeMatterGateway {
  Result<List<Matter>>? nextResult;
  bool throwNext = false;
  int fetchCalls = 0;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    fetchCalls += 1;
    if (throwNext) {
      throwNext = false;
      throw StateError('matters gateway blew up');
    }
    final Result<List<Matter>>? result = nextResult;
    if (result != null) {
      nextResult = null;
      return result;
    }
    return super.fetchMatters();
  }
}

class _StubApprovalsGateway implements ApprovalsGateway {
  final List<ApprovalDraft> createdDrafts = <ApprovalDraft>[];
  final List<AppError> createFailures = <AppError>[];
  bool throwNextCreate = false;
  int createAttempts = 0;

  @override
  Future<Result<List<PendingApproval>>> fetchApprovals({
    ApprovalStatus? status,
  }) async {
    return Result<List<PendingApproval>>.success(const <PendingApproval>[]);
  }

  @override
  Future<Result<String>> create(ApprovalDraft draft) async {
    createAttempts += 1;
    if (throwNextCreate) {
      throwNextCreate = false;
      throw StateError('create blew up');
    }
    if (createFailures.isNotEmpty) {
      return Result<String>.failure(createFailures.removeAt(0));
    }
    createdDrafts.add(draft);
    return Result<String>.success('created-${createdDrafts.length}');
  }

  @override
  Future<Result<void>> decide(
    String id, {
    required bool approve,
    String? note,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> cancel(String id) async {
    throw UnimplementedError();
  }
}
