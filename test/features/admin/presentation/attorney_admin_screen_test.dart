import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/admin/presentation/attorney_admin_screen.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';

class _StubAttorneyAdminGateway implements AttorneyAdminGateway {
  _StubAttorneyAdminGateway({List<Attorney>? rows})
    : rows =
          rows ??
          <Attorney>[
            _attorney('11111111-1111-4111-8111-111111111111', 'Layla Mansour'),
          ];

  List<Attorney> rows;
  bool denied = false;
  int deactivateCalls = 0;
  AttorneyDraft? created;
  AttorneyDraft? updated;
  String createdId = '22222222-2222-4222-8222-222222222222';

  static const AppError _denied = AppError(
    code: 'attorney_read_denied',
    userMessage: 'denied',
    kind: AppErrorKind.denied,
  );

  @override
  Future<Result<List<Attorney>>> fetchAll() async {
    if (denied) {
      return const Result<List<Attorney>>.failure(_denied);
    }
    return Result<List<Attorney>>.success(rows);
  }

  @override
  Future<Result<String>> create(AttorneyDraft draft) async {
    created = draft;
    rows = <Attorney>[
      ...rows,
      _attorney(
        createdId,
        draft.displayName,
        specialties: draft.specialties,
        isActive: true,
      ),
    ];
    return Result<String>.success(createdId);
  }

  @override
  Future<Result<void>> update(String id, AttorneyDraft draft) async {
    updated = draft;
    rows = <Attorney>[
      for (final Attorney row in rows)
        row.id == id
            ? _attorney(
                id,
                draft.displayName,
                specialties: draft.specialties,
                isActive: row.isActive,
              )
            : row,
    ];
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deactivate(String id) async {
    deactivateCalls += 1;
    rows = <Attorney>[
      for (final Attorney row in rows)
        row.id == id
            ? _attorney(
                id,
                row.name,
                specialties: row.specialties,
                isActive: false,
              )
            : row,
    ];
    return const Result<void>.success(null);
  }
}

Attorney _attorney(
  String id,
  String name, {
  List<String> specialties = const <String>['corporate'],
  bool isActive = true,
}) => Attorney(
  id: id,
  name: name,
  practiceArea: PracticeArea.corporate,
  headline: 'Corporate counsel',
  city: 'Cairo',
  specialties: specialties,
  languages: const <String>['EN'],
  yearsExperience: 8,
  isActive: isActive,
);

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    _StubAttorneyAdminGateway gateway,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AttorneyAdminScreen(gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AttorneyAdminScreen', () {
    testWidgets('lists every profile with a status chip and the honest note', (
      tester,
    ) async {
      final _StubAttorneyAdminGateway gateway = _StubAttorneyAdminGateway(
        rows: <Attorney>[
          _attorney('11111111-1111-4111-8111-111111111111', 'Layla Mansour'),
          _attorney(
            '33333333-3333-4333-8333-333333333333',
            'Former Attorney',
            isActive: false,
          ),
        ],
      );

      await pumpScreen(tester, gateway);

      expect(find.text('Attorney directory'), findsOneWidget);
      expect(find.text('Layla Mansour'), findsOneWidget);
      expect(find.text('Former Attorney'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.textContaining('No credential verification'), findsOneWidget);
    });

    testWidgets('a non-owner read renders the unauthorized arm', (
      tester,
    ) async {
      final _StubAttorneyAdminGateway gateway = _StubAttorneyAdminGateway()
        ..denied = true;

      await pumpScreen(tester, gateway);

      expect(find.text('Access not available'), findsOneWidget);
      expect(find.text('Layla Mansour'), findsNothing);
    });

    testWidgets('create validates name and specialty, then saves', (
      tester,
    ) async {
      final _StubAttorneyAdminGateway gateway = _StubAttorneyAdminGateway();

      await pumpScreen(tester, gateway);
      await tester.tap(find.widgetWithText(FilledButton, 'Add attorney'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a display name.'), findsOneWidget);
      expect(find.text('Select at least one specialty.'), findsOneWidget);
      expect(gateway.created, isNull);

      await tester.enterText(find.byType(TextFormField).first, 'Nadia Fahmy');
      await tester.tap(find.widgetWithText(FilterChip, 'Corporate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(gateway.created?.displayName, 'Nadia Fahmy');
      expect(gateway.created?.specialties, <String>['corporate']);
      // The form popped and the list reloaded with the created row.
      expect(find.text('Nadia Fahmy'), findsOneWidget);
    });

    testWidgets('deactivate asks for confirmation and flips the status', (
      tester,
    ) async {
      final _StubAttorneyAdminGateway gateway = _StubAttorneyAdminGateway();

      await pumpScreen(tester, gateway);
      await tester.tap(find.byIcon(Icons.person_off_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate attorney?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();

      expect(gateway.deactivateCalls, 1);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('tapping a row opens the prefilled edit form', (tester) async {
      final _StubAttorneyAdminGateway gateway = _StubAttorneyAdminGateway();

      await pumpScreen(tester, gateway);
      await tester.tap(find.text('Layla Mansour'));
      await tester.pumpAndSettle();

      expect(find.text('Edit attorney'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        'Layla Mansour',
      );
      expect(find.text('Corporate'), findsWidgets);
    });
  });
}
