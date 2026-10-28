import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/features/video/presentation/video_create_sheet.dart';
import 'package:legalhub/features/video/presentation/video_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late _StubVideoGateway gateway;
  late _StubMatterGateway matterGateway;
  late VideoCubit cubit;
  bool? sheetResult;

  setUp(() async {
    await resetServiceLocator();
    gateway = _StubVideoGateway();
    matterGateway = _StubMatterGateway();
    sheetResult = null;
    serviceLocator.registerLazySingleton<VideoGateway>(() => gateway);
    configureDependencies();
    cubit = VideoCubit(gateway, matterGateway);
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
                  sheetResult = await showVideoCreateSheet(
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

  /// Opens the date picker, confirms the preselected day, then confirms the
  /// preselected time.
  Future<void> pickSchedule(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Date and time'));
    await tester.tap(find.text('Date and time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Schedule session'));
    await tester.tap(find.text('Schedule session'));
    await tester.pumpAndSettle();
  }

  group('VideoCreateSheet', () {
    testWidgets(
      'renders the matter picker and blocks a submit without a date',
      (tester) async {
        await openSheet(tester);

        expect(find.text('Schedule a video consultation'), findsOneWidget);
        expect(find.text('Matter (optional)'), findsOneWidget);
        expect(find.text('Date and time'), findsOneWidget);
        expect(find.text('Schedule session'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tapSubmit(tester);

        expect(
          find.text('Choose a date and time for the session.'),
          findsOneWidget,
        );
        expect(gateway.createAttempts, 0);
        expect(find.text('Schedule a video consultation'), findsOneWidget);
      },
    );

    testWidgets('refuses to submit without an active organization', (
      tester,
    ) async {
      await openSheet(tester, withOrg: false);

      expect(
        find.text('Select an organization before scheduling a session.'),
        findsOneWidget,
      );
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Schedule session'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('schedules with the selected matter and closes with success', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo acquisition review').last);
      await tester.pumpAndSettle();
      await pickSchedule(tester);

      await tapSubmit(tester);

      expect(gateway.createCalls, hasLength(1));
      final _CreateCall call = gateway.createCalls.single;
      expect(call.matterId, 'matter-1');
      expect(call.scheduledAt, isNotNull);
      expect(call.scheduledAt!.second, 0);
      expect(find.text('Schedule a video consultation'), findsNothing);
      expect(sheetResult, isTrue);
    });

    testWidgets('renders a typed failure inline and keeps submit available', (
      tester,
    ) async {
      gateway.createFailures.add(
        const AppError(
          code: 'video_create_unavailable',
          userMessage: 'offline',
          kind: AppErrorKind.unavailable,
        ),
      );
      await openSheet(tester);
      await pickSchedule(tester);

      await tapSubmit(tester);

      expect(gateway.createAttempts, 1);
      expect(
        find.text('Video calls are temporarily unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Schedule a video consultation'), findsOneWidget);
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Schedule session'),
      );
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('a thrown create re-enables submit and a retry lands (N1)', (
      tester,
    ) async {
      gateway.throwNextCreate = true;
      await openSheet(tester);
      await pickSchedule(tester);

      await tapSubmit(tester);

      expect(gateway.createAttempts, 1);
      expect(
        find.text('Unable to complete that action. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Schedule a video consultation'), findsOneWidget);
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Schedule session'),
      );
      expect(submit.onPressed, isNotNull);

      await tapSubmit(tester);

      expect(gateway.createAttempts, 2);
      expect(gateway.createCalls, hasLength(1));
      expect(find.text('Schedule a video consultation'), findsNothing);
      expect(sheetResult, isTrue);
    });

    testWidgets('a failed matter read shows the inline retry', (tester) async {
      matterGateway.nextResult = const Result<List<Matter>>.failure(
        AppError(code: 'matters_failed', userMessage: 'offline'),
      );
      await openSheet(tester);

      expect(find.text('Unable to load matters.'), findsOneWidget);
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
      expect(find.text('Unable to load matters.'), findsOneWidget);
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

class _CreateCall {
  const _CreateCall({required this.matterId, required this.scheduledAt});

  final String? matterId;
  final DateTime? scheduledAt;
}

class _StubVideoGateway implements VideoGateway {
  final List<_CreateCall> createCalls = <_CreateCall>[];
  final List<AppError> createFailures = <AppError>[];
  bool throwNextCreate = false;
  int createAttempts = 0;

  @override
  Future<Result<List<VideoSession>>> fetchSessions() async {
    return Result<List<VideoSession>>.success(const <VideoSession>[]);
  }

  @override
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    createAttempts += 1;
    if (throwNextCreate) {
      throwNextCreate = false;
      throw StateError('create blew up');
    }
    if (createFailures.isNotEmpty) {
      return Result<String>.failure(createFailures.removeAt(0));
    }
    createCalls.add(_CreateCall(matterId: matterId, scheduledAt: scheduledAt));
    return Result<String>.success('video-local-${createCalls.length}');
  }

  @override
  Future<Result<VideoToken>> fetchToken(String sessionId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> markLive(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> end(String id) async {
    throw UnimplementedError();
  }
}
