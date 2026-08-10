import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/view_state_list.dart';

// ViewStateList is the pattern-B follow-up extraction (design
// docs/view_state_list_followup_design_2026-08-11.md): the approvals,
// compliance, and task-board screens previously duplicated this
// note-wrapped ListView switch. These tests pin the rendering contract —
// including the preserved offline/unauthorized quirk (plain empty copy, no
// note) and the note placement on the empty and success arms.
void main() {
  Widget pumpViewState<T>(ViewState<T> state, {VoidCallback? onRetry}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ViewStateList<T>(
          state: state,
          onRetry: onRetry ?? () {},
          itemBuilder: (BuildContext context, T data) => <Widget>[
            Text('item:$data'),
            const SizedBox(height: 8),
          ],
          empty: const Text('empty copy'),
          errorCopy: 'Error copy',
          localOnlyNote: 'Local-only note',
        ),
      ),
    );
  }

  testWidgets('loading branch renders the centered spinner', (tester) async {
    await tester.pumpWidget(pumpViewState<String>(const ViewLoading<String>()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('empty copy'), findsNothing);
    expect(find.text('Local-only note'), findsNothing);
  });

  testWidgets('empty branch renders the note-wrapped empty copy', (
    tester,
  ) async {
    await tester.pumpWidget(pumpViewState<String>(const ViewEmpty<String>()));

    expect(find.text('empty copy'), findsOneWidget);
    expect(find.text('Local-only note'), findsOneWidget);
  });

  testWidgets('offline and unauthorized render the plain empty copy, no note '
      '(quirk preserved)', (tester) async {
    await tester.pumpWidget(pumpViewState<String>(const ViewOffline<String>()));
    expect(find.text('empty copy'), findsOneWidget);
    expect(find.text('Local-only note'), findsNothing);

    await tester.pumpWidget(
      pumpViewState<String>(const ViewUnauthorized<String>()),
    );
    expect(find.text('empty copy'), findsOneWidget);
    expect(find.text('Local-only note'), findsNothing);
  });

  testWidgets('error branch renders the error copy and fires retry', (
    tester,
  ) async {
    int retries = 0;
    await tester.pumpWidget(
      pumpViewState<String>(
        const ViewError<String>(AppError(code: 'stub', userMessage: 'stub')),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Error copy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('success branch appends the note after the items', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpViewState<String>(const ViewSuccess<String>('payload')),
    );

    expect(find.text('item:payload'), findsOneWidget);
    expect(find.text('Local-only note'), findsOneWidget);
  });

  testWidgets('renders under RTL without overflow', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: pumpViewState<String>(
          const ViewError<String>(AppError(code: 'stub', userMessage: 'stub')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Error copy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
